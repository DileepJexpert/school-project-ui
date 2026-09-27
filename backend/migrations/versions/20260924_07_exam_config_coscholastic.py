"""Add exam configuration and co-scholastic assessments."""

from alembic import op
import sqlalchemy as sa

revision = "20260924_07"
down_revision = "20260924_06"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "exam_configs",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column("tenant_id", sa.String(64), sa.ForeignKey("tenants.id"), nullable=False),
        sa.Column("academic_year", sa.String(9), nullable=False),
        sa.Column("exam_type", sa.String(80), nullable=False),
        sa.Column("display_name", sa.String(120), nullable=False),
        sa.Column("weightage_percent", sa.Integer(), nullable=False),
        sa.Column("max_marks_default", sa.Numeric(7, 2), nullable=False),
        sa.Column("is_active", sa.Boolean(), nullable=False),
        sa.UniqueConstraint("tenant_id", "academic_year", "exam_type"),
        sa.CheckConstraint("weightage_percent >= 0 AND weightage_percent <= 100", name="exam_weightage_range"),
        sa.CheckConstraint("max_marks_default > 0", name="exam_max_marks_positive"),
    )
    op.create_index("ix_exam_configs_tenant_id", "exam_configs", ["tenant_id"])
    op.create_table(
        "coscholastic_assessments",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column("tenant_id", sa.String(64), sa.ForeignKey("tenants.id"), nullable=False),
        sa.Column("enrollment_id", sa.String(36), sa.ForeignKey("enrollments.id"), nullable=False),
        sa.Column("term", sa.String(80), nullable=False),
        sa.Column("areas", sa.JSON(), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
        sa.UniqueConstraint("tenant_id", "enrollment_id", "term"),
    )
    op.create_index("ix_coscholastic_assessments_tenant_id", "coscholastic_assessments", ["tenant_id"])
    op.create_index("ix_coscholastic_assessments_enrollment_id", "coscholastic_assessments", ["enrollment_id"])


def downgrade() -> None:
    op.drop_table("coscholastic_assessments")
    op.drop_table("exam_configs")
