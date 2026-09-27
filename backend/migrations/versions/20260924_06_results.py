"""Add enrollment-scoped marks and publication state."""

from alembic import op
import sqlalchemy as sa

revision = "20260924_06"
down_revision = "20260924_05"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "result_records",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column("tenant_id", sa.String(64), sa.ForeignKey("tenants.id"), nullable=False),
        sa.Column("enrollment_id", sa.String(36), sa.ForeignKey("enrollments.id"), nullable=False),
        sa.Column("exam_type", sa.String(80), nullable=False),
        sa.Column("subject", sa.String(120), nullable=False),
        sa.Column("marks_obtained", sa.Numeric(7, 2), nullable=False),
        sa.Column("max_marks", sa.Numeric(7, 2), nullable=False),
        sa.Column("teacher_remarks", sa.String(1000), nullable=True),
        sa.Column("entered_by", sa.String(200), nullable=False),
        sa.Column("is_published", sa.Boolean(), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("voided_at", sa.DateTime(timezone=True), nullable=True),
        sa.UniqueConstraint("tenant_id", "enrollment_id", "exam_type", "subject"),
        sa.CheckConstraint("max_marks > 0", name="result_max_marks_positive"),
        sa.CheckConstraint("marks_obtained >= 0", name="result_marks_nonnegative"),
        sa.CheckConstraint("marks_obtained <= max_marks", name="result_marks_within_max"),
    )
    op.create_index("ix_result_records_tenant_id", "result_records", ["tenant_id"])
    op.create_index("ix_result_records_enrollment_id", "result_records", ["enrollment_id"])


def downgrade() -> None:
    op.drop_table("result_records")
