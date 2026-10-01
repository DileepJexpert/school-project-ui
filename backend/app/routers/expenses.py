from datetime import date, datetime, timezone
from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, Query, Response
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.db import get_session
from app.dependencies import require_tenant, tenant_id
from app.models import Expense
from app.schemas import ExpenseInput
from app.serializers import money

router = APIRouter(prefix="/expenses", tags=["expenses"])
Db = Annotated[Session, Depends(get_session)]
TenantId = Annotated[str, Depends(tenant_id)]


def _wire(expense: Expense) -> dict:
    return {
        "id": expense.id,
        "title": expense.title,
        "category": expense.category,
        "amount": money(expense.amount),
        "date": expense.date.isoformat(),
        "paidTo": expense.paid_to,
        "remarks": expense.remarks,
    }


@router.get("")
def list_expenses(
    session: Db,
    tenant: TenantId,
    from_date: date | None = Query(None, alias="from"),
    to_date: date | None = Query(None, alias="to"),
) -> list[dict]:
    require_tenant(session, tenant)
    if from_date and to_date and from_date > to_date:
        raise HTTPException(status_code=422, detail="from must be before to")
    statement = select(Expense).where(Expense.tenant_id == tenant, Expense.voided_at.is_(None))
    if from_date:
        statement = statement.where(Expense.date >= from_date)
    if to_date:
        statement = statement.where(Expense.date <= to_date)
    return [_wire(item) for item in session.scalars(statement.order_by(Expense.date.desc(), Expense.id))]


@router.post("", status_code=201)
def add_expense(data: ExpenseInput, session: Db, tenant: TenantId) -> dict:
    with session.begin():
        require_tenant(session, tenant)
        expense = Expense(
            tenant_id=tenant,
            title=data.title.strip(),
            category=data.category.strip(),
            amount=data.amount,
            date=data.date,
            paid_to=data.paid_to.strip(),
            remarks=data.remarks,
            created_at=datetime.now(timezone.utc),
        )
        session.add(expense)
        session.flush()
        result = _wire(expense)
    return result


@router.get("/{expense_id}")
def get_expense(expense_id: str, session: Db, tenant: TenantId) -> dict:
    require_tenant(session, tenant)
    expense = session.get(Expense, expense_id)
    if expense is None or expense.tenant_id != tenant or expense.voided_at is not None:
        raise HTTPException(status_code=404, detail="Expense not found")
    return _wire(expense)


@router.put("/{expense_id}")
def update_expense(expense_id: str, data: ExpenseInput, session: Db, tenant: TenantId) -> dict:
    with session.begin():
        require_tenant(session, tenant)
        expense = session.get(Expense, expense_id)
        if expense is None or expense.tenant_id != tenant or expense.voided_at is not None:
            raise HTTPException(status_code=404, detail="Expense not found")
        expense.title = data.title.strip()
        expense.category = data.category.strip()
        expense.amount = data.amount
        expense.date = data.date
        expense.paid_to = data.paid_to.strip()
        expense.remarks = data.remarks
        session.flush()
        result = _wire(expense)
    return result


@router.delete("/{expense_id}", status_code=204)
def void_expense(expense_id: str, session: Db, tenant: TenantId) -> Response:
    with session.begin():
        require_tenant(session, tenant)
        expense = session.get(Expense, expense_id)
        if expense is None or expense.tenant_id != tenant or expense.voided_at is not None:
            raise HTTPException(status_code=404, detail="Expense not found")
        expense.voided_at = datetime.now(timezone.utc)
    return Response(status_code=204)
