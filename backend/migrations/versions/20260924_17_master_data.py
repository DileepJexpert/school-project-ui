"""School academic-year, class and subject catalogues for first run."""

from alembic import op
import sqlalchemy as sa

revision = "20260924_17"
down_revision = "20260924_16"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "academic_years",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column("tenant_id", sa.String(64), sa.ForeignKey("tenants.id"), nullable=False),
        sa.Column("year", sa.String(9), nullable=False),
        sa.Column("start_date", sa.Date(), nullable=False),
        sa.Column("end_date", sa.Date(), nullable=False),
        sa.Column("status", sa.String(16), nullable=False),
        sa.UniqueConstraint("tenant_id", "year"),
    )
    op.create_index("ix_academic_years_tenant_id", "academic_years", ["tenant_id"])
    op.create_table(
        "school_classes",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column("tenant_id", sa.String(64), sa.ForeignKey("tenants.id"), nullable=False),
        sa.Column("class_name", sa.String(80), nullable=False),
        sa.Column("base_class", sa.String(80), nullable=False),
        sa.Column("section", sa.String(16), nullable=False),
        sa.Column("sort_order", sa.Integer(), nullable=False),
        sa.Column("active", sa.Boolean(), nullable=False),
        sa.UniqueConstraint("tenant_id", "class_name"),
    )
    op.create_index("ix_school_classes_tenant_id", "school_classes", ["tenant_id"])
    op.create_table(
        "school_subjects",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column("tenant_id", sa.String(64), sa.ForeignKey("tenants.id"), nullable=False),
        sa.Column("name", sa.String(120), nullable=False),
        sa.Column("sort_order", sa.Integer(), nullable=False),
        sa.Column("active", sa.Boolean(), nullable=False),
        sa.UniqueConstraint("tenant_id", "name"),
    )
    op.create_index("ix_school_subjects_tenant_id", "school_subjects", ["tenant_id"])


def downgrade() -> None:
    op.drop_table("school_subjects")
    op.drop_table("school_classes")
    op.drop_table("academic_years")
