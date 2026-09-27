"""Add dated attendance tied to historical enrollment."""

from alembic import op
import sqlalchemy as sa

revision = "20260924_05"
down_revision = "20260924_04"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "attendance",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column("tenant_id", sa.String(64), sa.ForeignKey("tenants.id"), nullable=False),
        sa.Column("enrollment_id", sa.String(36), sa.ForeignKey("enrollments.id"), nullable=False),
        sa.Column("date", sa.Date(), nullable=False),
        sa.Column("status", sa.String(16), nullable=False),
        sa.Column("marked_by", sa.String(200), nullable=False),
        sa.Column("remarks", sa.String(1000), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("voided_at", sa.DateTime(timezone=True), nullable=True),
        sa.UniqueConstraint("tenant_id", "enrollment_id", "date"),
    )
    op.create_index("ix_attendance_tenant_id", "attendance", ["tenant_id"])
    op.create_index("ix_attendance_enrollment_id", "attendance", ["enrollment_id"])


def downgrade() -> None:
    op.drop_table("attendance")
