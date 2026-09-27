"""Define the subject roster required before class results can be published."""

from alembic import op
import sqlalchemy as sa

revision = "20260924_21"
down_revision = "20260924_20"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "class_subjects",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column("tenant_id", sa.String(64), sa.ForeignKey("tenants.id"), nullable=False),
        sa.Column("class_name", sa.String(80), nullable=False),
        sa.Column("academic_year", sa.String(9), nullable=False),
        sa.Column("subject_name", sa.String(120), nullable=False),
        sa.UniqueConstraint("tenant_id", "class_name", "academic_year", "subject_name"),
    )
    op.create_index("ix_class_subjects_tenant_id", "class_subjects", ["tenant_id"])


def downgrade() -> None:
    op.drop_table("class_subjects")
