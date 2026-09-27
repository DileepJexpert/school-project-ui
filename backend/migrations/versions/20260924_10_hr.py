"""Tenant-scoped staff, leave, payroll and staff attendance."""

from alembic import op
import sqlalchemy as sa

revision = "20260924_10"
down_revision = "20260924_09"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "staff",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column("tenant_id", sa.String(64), sa.ForeignKey("tenants.id"), nullable=False),
        sa.Column("employee_id", sa.String(64), nullable=False),
        sa.Column("full_name", sa.String(200), nullable=False),
        sa.Column("email", sa.String(320), nullable=False),
        sa.Column("phone", sa.String(40), nullable=False),
        sa.Column("department", sa.String(80), nullable=False),
        sa.Column("designation", sa.String(120), nullable=False),
        sa.Column("date_of_joining", sa.Date(), nullable=False),
        sa.Column("date_of_leaving", sa.Date(), nullable=True),
        sa.Column("basic_salary", sa.Numeric(12, 2), nullable=False),
        sa.Column("status", sa.String(24), nullable=False),
        sa.Column("details", sa.JSON(), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("deleted_at", sa.DateTime(timezone=True), nullable=True),
        sa.UniqueConstraint("tenant_id", "employee_id"),
        sa.CheckConstraint("basic_salary >= 0", name="staff_salary_nonnegative"),
    )
    op.create_index("ix_staff_tenant_id", "staff", ["tenant_id"])
    op.create_table(
        "leave_requests",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column("tenant_id", sa.String(64), sa.ForeignKey("tenants.id"), nullable=False),
        sa.Column("staff_id", sa.String(36), sa.ForeignKey("staff.id"), nullable=False),
        sa.Column("staff_name", sa.String(200), nullable=False),
        sa.Column("department", sa.String(80), nullable=False),
        sa.Column("leave_type", sa.String(32), nullable=False),
        sa.Column("from_date", sa.Date(), nullable=False),
        sa.Column("to_date", sa.Date(), nullable=False),
        sa.Column("total_days", sa.Integer(), nullable=False),
        sa.Column("reason", sa.String(1000), nullable=False),
        sa.Column("status", sa.String(16), nullable=False),
        sa.Column("approved_by", sa.String(200), nullable=True),
        sa.Column("approver_remarks", sa.String(1000), nullable=True),
        sa.Column("approved_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("applied_at", sa.DateTime(timezone=True), nullable=False),
    )
    op.create_index("ix_leave_requests_tenant_id", "leave_requests", ["tenant_id"])
    op.create_index("ix_leave_requests_staff_id", "leave_requests", ["staff_id"])
    op.create_table(
        "salary_records",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column("tenant_id", sa.String(64), sa.ForeignKey("tenants.id"), nullable=False),
        sa.Column("staff_id", sa.String(36), sa.ForeignKey("staff.id"), nullable=False),
        sa.Column("staff_name", sa.String(200), nullable=False),
        sa.Column("department", sa.String(80), nullable=False),
        sa.Column("designation", sa.String(120), nullable=False),
        sa.Column("month", sa.Integer(), nullable=False),
        sa.Column("year", sa.Integer(), nullable=False),
        sa.Column("basic_pay", sa.Numeric(12, 2), nullable=False),
        sa.Column("hra", sa.Numeric(12, 2), nullable=False),
        sa.Column("da", sa.Numeric(12, 2), nullable=False),
        sa.Column("ta", sa.Numeric(12, 2), nullable=False),
        sa.Column("other_allowances", sa.Numeric(12, 2), nullable=False),
        sa.Column("pf", sa.Numeric(12, 2), nullable=False),
        sa.Column("tax", sa.Numeric(12, 2), nullable=False),
        sa.Column("other_deductions", sa.Numeric(12, 2), nullable=False),
        sa.Column("gross_salary", sa.Numeric(12, 2), nullable=False),
        sa.Column("total_deductions", sa.Numeric(12, 2), nullable=False),
        sa.Column("net_salary", sa.Numeric(12, 2), nullable=False),
        sa.Column("status", sa.String(16), nullable=False),
        sa.Column("payment_mode", sa.String(32), nullable=True),
        sa.Column("transaction_ref", sa.String(120), nullable=True),
        sa.Column("generated_by", sa.String(200), nullable=False),
        sa.Column("generated_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("paid_at", sa.DateTime(timezone=True), nullable=True),
        sa.UniqueConstraint("tenant_id", "staff_id", "month", "year"),
        sa.CheckConstraint("month >= 1 AND month <= 12", name="salary_month_range"),
    )
    op.create_index("ix_salary_records_tenant_id", "salary_records", ["tenant_id"])
    op.create_index("ix_salary_records_staff_id", "salary_records", ["staff_id"])
    op.create_table(
        "staff_attendance",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column("tenant_id", sa.String(64), sa.ForeignKey("tenants.id"), nullable=False),
        sa.Column("staff_id", sa.String(36), sa.ForeignKey("staff.id"), nullable=False),
        sa.Column("staff_name", sa.String(200), nullable=False),
        sa.Column("department", sa.String(80), nullable=False),
        sa.Column("date", sa.Date(), nullable=False),
        sa.Column("status", sa.String(16), nullable=False),
        sa.Column("check_in_time", sa.String(5), nullable=True),
        sa.Column("check_out_time", sa.String(5), nullable=True),
        sa.Column("remarks", sa.String(1000), nullable=False),
        sa.Column("marked_by", sa.String(200), nullable=False),
        sa.Column("marked_at", sa.DateTime(timezone=True), nullable=False),
        sa.UniqueConstraint("tenant_id", "staff_id", "date"),
    )
    op.create_index("ix_staff_attendance_tenant_id", "staff_attendance", ["tenant_id"])
    op.create_index("ix_staff_attendance_staff_id", "staff_attendance", ["staff_id"])


def downgrade() -> None:
    op.drop_table("staff_attendance")
    op.drop_table("salary_records")
    op.drop_table("leave_requests")
    op.drop_table("staff")
