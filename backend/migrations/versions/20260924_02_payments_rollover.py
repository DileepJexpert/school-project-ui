"""Add immutable payment allocations and batch rollover audit."""

from alembic import op
import sqlalchemy as sa

revision = "20260924_02"
down_revision = "20260924_01"
branch_labels = None
depends_on = None


def upgrade() -> None:
    with op.batch_alter_table("fee_installments") as batch:
        batch.add_column(sa.Column("paid_amount", sa.Numeric(12, 2), nullable=False, server_default="0.00"))
        batch.add_column(sa.Column("discount_amount", sa.Numeric(12, 2), nullable=False, server_default="0.00"))
        batch.create_check_constraint("fee_installment_paid_nonnegative", "paid_amount >= 0")
        batch.create_check_constraint("fee_installment_discount_nonnegative", "discount_amount >= 0")
        batch.create_check_constraint("fee_installment_not_overpaid", "paid_amount + discount_amount <= amount_due")
    op.create_table(
        "payments",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column("tenant_id", sa.String(64), sa.ForeignKey("tenants.id"), nullable=False),
        sa.Column("profile_id", sa.String(36), sa.ForeignKey("fee_profiles.id"), nullable=False),
        sa.Column("receipt_number", sa.String(64), nullable=False),
        sa.Column("payment_date", sa.DateTime(timezone=True), nullable=False),
        sa.Column("amount_paid", sa.Numeric(12, 2), nullable=False),
        sa.Column("discount", sa.Numeric(12, 2), nullable=False),
        sa.Column("payment_mode", sa.String(32), nullable=False),
        sa.Column("transaction_reference", sa.String(120), nullable=True),
        sa.Column("cheque_details", sa.String(200), nullable=True),
        sa.Column("remarks", sa.String(1000), nullable=True),
        sa.Column("idempotency_key", sa.String(128), nullable=True),
        sa.Column("request_fingerprint", sa.String(64), nullable=True),
        sa.UniqueConstraint("tenant_id", "receipt_number"),
        sa.UniqueConstraint("tenant_id", "idempotency_key"),
        sa.UniqueConstraint("tenant_id", "payment_mode", "transaction_reference"),
        sa.CheckConstraint("amount_paid >= 0", name="payment_amount_nonnegative"),
        sa.CheckConstraint("discount >= 0", name="payment_discount_nonnegative"),
    )
    op.create_index("ix_payments_tenant_id", "payments", ["tenant_id"])
    op.create_index("ix_payments_profile_id", "payments", ["profile_id"])
    op.create_table(
        "payment_allocations",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column("payment_id", sa.String(36), sa.ForeignKey("payments.id"), nullable=False),
        sa.Column("installment_id", sa.String(36), sa.ForeignKey("fee_installments.id"), nullable=False),
        sa.Column("position", sa.Integer(), nullable=False),
        sa.Column("amount_paid", sa.Numeric(12, 2), nullable=False),
        sa.Column("discount", sa.Numeric(12, 2), nullable=False),
        sa.UniqueConstraint("payment_id", "installment_id"),
        sa.CheckConstraint("amount_paid >= 0", name="allocation_amount_nonnegative"),
        sa.CheckConstraint("discount >= 0", name="allocation_discount_nonnegative"),
    )
    op.create_index("ix_payment_allocations_payment_id", "payment_allocations", ["payment_id"])
    op.create_table(
        "rollover_runs",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column("tenant_id", sa.String(64), sa.ForeignKey("tenants.id"), nullable=False),
        sa.Column("idempotency_key", sa.String(128), nullable=False),
        sa.Column("request_fingerprint", sa.String(64), nullable=False),
        sa.Column("source_class", sa.String(80), nullable=False),
        sa.Column("source_year", sa.String(9), nullable=False),
        sa.Column("target_class", sa.String(80), nullable=True),
        sa.Column("target_year", sa.String(9), nullable=True),
        sa.Column("student_count", sa.Integer(), nullable=False),
        sa.Column("student_ids", sa.JSON(), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.UniqueConstraint("tenant_id", "idempotency_key"),
    )
    op.create_index("ix_rollover_runs_tenant_id", "rollover_runs", ["tenant_id"])


def downgrade() -> None:
    op.drop_table("rollover_runs")
    op.drop_table("payment_allocations")
    op.drop_table("payments")
    with op.batch_alter_table("fee_installments") as batch:
        batch.drop_constraint("fee_installment_not_overpaid", type_="check")
        batch.drop_constraint("fee_installment_discount_nonnegative", type_="check")
        batch.drop_constraint("fee_installment_paid_nonnegative", type_="check")
        batch.drop_column("discount_amount")
        batch.drop_column("paid_amount")
