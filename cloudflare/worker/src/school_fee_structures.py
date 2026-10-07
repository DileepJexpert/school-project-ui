"""D1 fee-structure setup with the Flutter fee editor contract."""

from __future__ import annotations

from decimal import Decimal
from typing import Literal
from uuid import uuid4

from fastapi import APIRouter, Depends, Header, HTTPException, Response
from pydantic import BaseModel, Field

from school_auth import _db, get_current_user
from school_overview import _many, _one, _tenant
from school_setup import _year


router = APIRouter(prefix="/api/feestructures", tags=["fee setup"])


class ComponentInput(BaseModel):
    feeName: str = Field(min_length=1, max_length=120)
    amount: Decimal = Field(gt=0)
    frequency: Literal["YEARLY", "MONTHLY", "ONE_TIME"] = "YEARLY"
    description: str = ""


class StructureInput(BaseModel):
    className: str = Field(min_length=1, max_length=80)
    academicYear: str
    feeComponents: list[ComponentInput] = Field(min_items=1)


def _permission(user: dict, action: str) -> None:
    permissions = user.get("permissions") or []
    if "*" not in permissions and f"fees:{action}" not in permissions:
        raise HTTPException(status_code=403, detail=f"Fee {action} access required")


def _minor(amount: Decimal) -> int:
    scaled = amount * 100
    if scaled != scaled.to_integral_value() or scaled > 999999999999:
        raise HTTPException(status_code=422, detail="Fee amounts must have at most two decimal places")
    return int(scaled)


async def _wire(db, structure: dict) -> dict:
    components = await _many(db, "SELECT name, amount, frequency, description FROM fee_components WHERE structure_id = ? ORDER BY position", structure["id"])
    return {
        "id": structure["id"],
        "className": structure["class_name"],
        "academicYear": structure["academic_year"],
        "feeComponents": [
            {"feeName": row["name"], "amount": row["amount"] / 100.0,
             "frequency": row["frequency"], "description": row["description"]}
            for row in components
        ],
    }


@router.get("")
async def list_structures(
    year: str,
    db=Depends(_db),
    user: dict = Depends(get_current_user),
    x_tenant_id: str | None = Header(default=None, alias="X-Tenant-ID"),
):
    _permission(user, "read")
    tenant = await _tenant(db, user, x_tenant_id)
    rows = await _many(db, "SELECT id, class_name, academic_year FROM fee_structures WHERE tenant_id = ? AND academic_year = ? ORDER BY class_name", tenant, _year(year))
    if not rows:
        return []
    struct_ids = [r["id"] for r in rows]
    placeholders = ",".join("?" for _ in struct_ids)
    all_components = await _many(db, f"SELECT structure_id, name, amount, frequency, description FROM fee_components WHERE structure_id IN ({placeholders}) ORDER BY position", *struct_ids)
    comp_by_struct = {}
    for c in all_components:
        comp_by_struct.setdefault(c["structure_id"], []).append(c)

    return [
        {
            "id": r["id"],
            "className": r["class_name"],
            "academicYear": r["academic_year"],
            "feeComponents": [
                {
                    "feeName": c["name"],
                    "amount": c["amount"] / 100.0,
                    "frequency": c["frequency"],
                    "description": c["description"],
                }
                for c in comp_by_struct.get(r["id"], [])
            ],
        }
        for r in rows
    ]


@router.post("")
async def save_structures(
    data: list[StructureInput],
    db=Depends(_db),
    user: dict = Depends(get_current_user),
    x_tenant_id: str | None = Header(default=None, alias="X-Tenant-ID"),
):
    _permission(user, "write")
    tenant = await _tenant(db, user, x_tenant_id)
    if not data:
        raise HTTPException(status_code=422, detail="At least one structure is required")
    seen: set[tuple[str, str]] = set()
    statements = []
    saved_ids = []
    for item in data:
        class_name = item.className.strip()
        year = _year(item.academicYear)
        if not class_name:
            raise HTTPException(status_code=422, detail="Class name cannot be blank")
        key = (class_name, year)
        if key in seen:
            raise HTTPException(status_code=422, detail="Duplicate class/year in request")
        seen.add(key)
        names = [component.feeName.strip().casefold() for component in item.feeComponents]
        if any(not name for name in names) or len(names) != len(set(names)):
            raise HTTPException(status_code=422, detail="Fee component names must be unique and nonblank")
        amounts = [_minor(component.amount) for component in item.feeComponents]
        existing = await _one(db, "SELECT id FROM fee_structures WHERE tenant_id = ? AND class_name = ? AND academic_year = ?", tenant, class_name, year)
        structure_id = existing.get("id") if existing else uuid4().hex
        if existing:
            in_use = await _one(db, "SELECT id FROM fee_profiles WHERE tenant_id = ? AND fee_structure_id = ? LIMIT 1", tenant, structure_id)
            if in_use:
                raise HTTPException(status_code=409, detail="Fee structure is already in use")
            statements.append(db.prepare("DELETE FROM fee_components WHERE structure_id = ?").bind(structure_id))
        else:
            statements.append(db.prepare("INSERT INTO fee_structures (id, tenant_id, class_name, academic_year) VALUES (?, ?, ?, ?)").bind(structure_id, tenant, class_name, year))
        for position, (component, amount) in enumerate(zip(item.feeComponents, amounts)):
            statements.append(db.prepare("INSERT INTO fee_components (id, structure_id, position, name, amount, frequency, description) VALUES (?, ?, ?, ?, ?, ?, ?)").bind(uuid4().hex, structure_id, position, component.feeName.strip(), amount, component.frequency, component.description))
        saved_ids.append(structure_id)
    await db.batch(statements)
    rows = [await _one(db, "SELECT id, class_name, academic_year FROM fee_structures WHERE tenant_id = ? AND id = ?", tenant, structure_id) for structure_id in saved_ids]
    return [await _wire(db, row) for row in rows]


@router.delete("/{structure_id}", status_code=204)
async def delete_structure(
    structure_id: str,
    db=Depends(_db),
    user: dict = Depends(get_current_user),
    x_tenant_id: str | None = Header(default=None, alias="X-Tenant-ID"),
):
    _permission(user, "write")
    tenant = await _tenant(db, user, x_tenant_id)
    existing = await _one(db, "SELECT id FROM fee_structures WHERE tenant_id = ? AND id = ?", tenant, structure_id)
    if not existing:
        raise HTTPException(status_code=404, detail="Fee structure not found")
    in_use = await _one(db, "SELECT id FROM fee_profiles WHERE tenant_id = ? AND fee_structure_id = ? LIMIT 1", tenant, structure_id)
    if in_use:
        raise HTTPException(status_code=409, detail="Fee structure is already in use")
    await db.batch([
        db.prepare("DELETE FROM fee_components WHERE structure_id = ?").bind(structure_id),
        db.prepare("DELETE FROM fee_structures WHERE tenant_id = ? AND id = ?").bind(tenant, structure_id),
    ])
    return Response(status_code=204)


root_router = APIRouter(prefix="/feestructures", tags=["fee setup root"])
for _route in list(router.routes):
    _subpath = _route.path[len("/api/feestructures"):]
    root_router.add_api_route(
        _subpath,
        _route.endpoint,
        methods=_route.methods,
        response_model=_route.response_model,
        status_code=_route.status_code,
    )

