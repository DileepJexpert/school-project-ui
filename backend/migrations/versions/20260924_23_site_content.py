"""Persist public website content per school instead of using sample text."""

from alembic import op
import sqlalchemy as sa

revision = "20260924_23"
down_revision = "20260924_22"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "school_site_content",
        sa.Column("tenant_id", sa.String(64), sa.ForeignKey("tenants.id"), primary_key=True),
        sa.Column("content", sa.JSON(), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
    )


def downgrade() -> None:
    op.drop_table("school_site_content")
