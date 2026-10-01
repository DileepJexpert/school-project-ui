"""Tenant-scoped school expense ledger for the admin finance screens."""

from __future__ import annotations

from datetime import date, datetime, timezone
from decimal import Decimal
from uuid import uuid4

from fastapi import APIRouter, Depends, Header, HTTPException, Query, Response
from pydantic import BaseModel, Field

from school_auth import _db, get_current_user
from school_overview import _many, _one, _tenant


router = APIRouter(prefix="/api/expenses", tags=["expenses"])


class ExpenseInput(BaseModel):
    title: str = Field(min_length=1, max_length=200)
    category: str = Field(min_length=1, max_length=120)
    amount: Decimal = Field(gt=0)
    date: date
    paidTo: str = Field(min_length=1, max_length=200)
    remarks: str | None = None


def _permission(user: dict, action: str):
    permissions = user.get("permissions") or []
    if "*" not in permissions and f"expenses:{action}" not in permissions:
        raise HTTPException(status_code=403, detail=f"Expense {action} access required")


def _wire(row: dict) -> dict:
    return {"id": row["id"], "title": row["title"], "category": row["category"],
            "amount": row["amount"] / 100.0, "date": row["date"],
            "paidTo": row["paid_to"], "remarks": row["remarks"]}


_COLUMNS = "id, title, category, amount, date, paid_to, remarks"


@router.get("")
async def list_expenses(
    from_date: date | None = Query(default=None, alias="from"),
    to_date: date | None = Query(default=None, alias="to"),
    db=Depends(_db),
    user: dict = Depends(get_current_user),
    x_tenant_id: str | None = Header(default=None, alias="X-Tenant-ID"),
):
    _permission(user, "read")
    tenant = await _tenant(db, user, x_tenant_id)
    if from_date and to_date and from_date > to_date:
        raise HTTPException(status_code=422, detail="from must be before to")
    sql = f"SELECT {_COLUMNS} FROM expenses WHERE tenant_id = ? AND voided_at IS NULL"
    bindings = [tenant]
    if from_date:
        sql += " AND date >= ?"
        bindings.append(from_date.isoformat())
    if to_date:
        sql += " AND date <= ?"
        bindings.append(to_date.isoformat())
    rows = await _many(db, sql + " ORDER BY date DESC, id", *bindings)
    return [_wire(row) for row in rows]


@router.post("", status_code=201)
async def add_expense(
    item: ExpenseInput,
    db=Depends(_db),
    user: dict = Depends(get_current_user),
    x_tenant_id: str | None = Header(default=None, alias="X-Tenant-ID"),
):
    _permission(user, "write")
    tenant = await _tenant(db, user, x_tenant_id)
    amount = item.amount * 100
    if amount != amount.to_integral_value() or amount > 999999999999:
        raise HTTPException(status_code=422, detail="Amount must have at most two decimal places")
    title, category, paid_to = item.title.strip(), item.category.strip(), item.paidTo.strip()
    if not all((title, category, paid_to)):
        raise HTTPException(status_code=422, detail="Title, category, and payee are required")
    expense_id = uuid4().hex
    await db.prepare("INSERT INTO expenses (id, tenant_id, title, category, amount, date, paid_to, remarks, created_at, voided_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, NULL)").bind(expense_id, tenant, title, category, int(amount), item.date.isoformat(), paid_to, item.remarks, datetime.now(timezone.utc).isoformat()).run()
    return _wire(await _one(db, f"SELECT {_COLUMNS} FROM expenses WHERE tenant_id = ? AND id = ?", tenant, expense_id))


@router.get("/{expense_id}")
async def get_expense(
    expense_id: str,
    db=Depends(_db),
    user: dict = Depends(get_current_user),
    x_tenant_id: str | None = Header(default=None, alias="X-Tenant-ID"),
):
    _permission(user, "read")
    tenant = await _tenant(db, user, x_tenant_id)
    expense = await _one(db, f"SELECT {_COLUMNS} FROM expenses WHERE tenant_id = ? AND id = ? AND voided_at IS NULL", tenant, expense_id)
    if not expense:
        raise HTTPException(status_code=404, detail="Expense not found")
    return _wire(expense)


@router.put("/{expense_id}")
async def update_expense(
    expense_id: str,
    item: ExpenseInput,
    db=Depends(_db),
    user: dict = Depends(get_current_user),
    x_tenant_id: str | None = Header(default=None, alias="X-Tenant-ID"),
):
    _permission(user, "write")
    tenant = await _tenant(db, user, x_tenant_id)
    expense = await _one(db, "SELECT id FROM expenses WHERE tenant_id = ? AND id = ? AND voided_at IS NULL", tenant, expense_id)
    if not expense:
        raise HTTPException(status_code=404, detail="Expense not found")
    amount = item.amount * 100
    if amount != amount.to_integral_value() or amount > 999999999999:
        raise HTTPException(status_code=422, detail="Amount must have at most two decimal places")
    title, category, paid_to = item.title.strip(), item.category.strip(), item.paidTo.strip()
    if not all((title, category, paid_to)):
        raise HTTPException(status_code=422, detail="Title, category, and payee are required")
    await db.prepare("UPDATE expenses SET title = ?, category = ?, amount = ?, date = ?, paid_to = ?, remarks = ? WHERE tenant_id = ? AND id = ? AND voided_at IS NULL").bind(title, category, int(amount), item.date.isoformat(), paid_to, item.remarks, tenant, expense_id).run()
    return _wire(await _one(db, f"SELECT {_COLUMNS} FROM expenses WHERE tenant_id = ? AND id = ?", tenant, expense_id))


@router.delete("/{expense_id}", status_code=204)
async def void_expense(
    expense_id: str,
    db=Depends(_db),
    user: dict = Depends(get_current_user),
    x_tenant_id: str | None = Header(default=None, alias="X-Tenant-ID"),
):
    _permission(user, "write")
    tenant = await _tenant(db, user, x_tenant_id)
    expense = await _one(db, "SELECT id FROM expenses WHERE tenant_id = ? AND id = ? AND voided_at IS NULL", tenant, expense_id)
    if not expense:
        raise HTTPException(status_code=404, detail="Expense not found")
    await db.prepare("UPDATE expenses SET voided_at = ? WHERE tenant_id = ? AND id = ? AND voided_at IS NULL").bind(datetime.now(timezone.utc).isoformat(), tenant, expense_id).run()
    return Response(status_code=204)

