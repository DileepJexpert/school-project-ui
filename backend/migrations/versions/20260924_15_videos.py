"""Tenant-scoped video metadata; bytes live in a backed-up storage volume."""

from alembic import op
import sqlalchemy as sa

revision = "20260924_15"
down_revision = "20260924_14"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "tutorial_videos",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column("tenant_id", sa.String(64), sa.ForeignKey("tenants.id"), nullable=False),
        sa.Column("title", sa.String(200), nullable=False),
        sa.Column("description", sa.String(4000), nullable=False),
        sa.Column("subject", sa.String(120), nullable=False),
        sa.Column("class_name", sa.String(80), nullable=False),
        sa.Column("academic_year", sa.String(9), nullable=False),
        sa.Column("chapter", sa.String(200), nullable=False),
        sa.Column("teacher_id", sa.String(36), sa.ForeignKey("users.id"), nullable=False),
        sa.Column("teacher_name", sa.String(200), nullable=False),
        sa.Column("storage_key", sa.String(80), nullable=False),
        sa.Column("file_name", sa.String(255), nullable=False),
        sa.Column("content_type", sa.String(80), nullable=False),
        sa.Column("file_size", sa.BigInteger(), nullable=False),
        sa.Column("status", sa.String(16), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("deleted_at", sa.DateTime(timezone=True), nullable=True),
        sa.UniqueConstraint("tenant_id", "storage_key"),
    )
    op.create_index("ix_tutorial_videos_tenant_id", "tutorial_videos", ["tenant_id"])


def downgrade() -> None:
    op.drop_table("tutorial_videos")
