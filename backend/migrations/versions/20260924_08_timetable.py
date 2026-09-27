"""Add year-scoped weekly class timetable."""

from alembic import op
import sqlalchemy as sa

revision = "20260924_08"
down_revision = "20260924_07"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "timetable_days",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column("tenant_id", sa.String(64), sa.ForeignKey("tenants.id"), nullable=False),
        sa.Column("class_name", sa.String(80), nullable=False),
        sa.Column("academic_year", sa.String(9), nullable=False),
        sa.Column("day_of_week", sa.String(16), nullable=False),
        sa.UniqueConstraint("tenant_id", "class_name", "academic_year", "day_of_week"),
    )
    op.create_index("ix_timetable_days_tenant_id", "timetable_days", ["tenant_id"])
    op.create_table(
        "timetable_periods",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column("day_id", sa.String(36), sa.ForeignKey("timetable_days.id", ondelete="CASCADE"), nullable=False),
        sa.Column("period_number", sa.Integer(), nullable=False),
        sa.Column("subject", sa.String(120), nullable=False),
        sa.Column("teacher_name", sa.String(200), nullable=False),
        sa.Column("start_time", sa.Time(), nullable=False),
        sa.Column("end_time", sa.Time(), nullable=False),
        sa.UniqueConstraint("day_id", "period_number"),
        sa.CheckConstraint("period_number > 0", name="timetable_period_number_positive"),
        sa.CheckConstraint("start_time < end_time", name="timetable_time_order"),
    )
    op.create_index("ix_timetable_periods_day_id", "timetable_periods", ["day_id"])


def downgrade() -> None:
    op.drop_table("timetable_periods")
    op.drop_table("timetable_days")
