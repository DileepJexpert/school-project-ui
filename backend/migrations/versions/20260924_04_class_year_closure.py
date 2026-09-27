"""Close rolled class-years to late admissions."""

from alembic import op
import sqlalchemy as sa

revision = "20260924_04"
down_revision = "20260924_03"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "class_year_closures",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column("tenant_id", sa.String(64), sa.ForeignKey("tenants.id"), nullable=False),
        sa.Column("class_name", sa.String(80), nullable=False),
        sa.Column("academic_year", sa.String(9), nullable=False),
        sa.Column("rollover_run_id", sa.String(36), sa.ForeignKey("rollover_runs.id"), nullable=False),
        sa.Column("closed_at", sa.DateTime(timezone=True), nullable=False),
        sa.UniqueConstraint("tenant_id", "class_name", "academic_year"),
    )
    op.create_index("ix_class_year_closures_tenant_id", "class_year_closures", ["tenant_id"])


def downgrade() -> None:
    op.drop_table("class_year_closures")
