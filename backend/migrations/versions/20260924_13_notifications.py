"""Targeted notifications and per-user read state."""

from alembic import op
import sqlalchemy as sa

revision = "20260924_13"
down_revision = "20260924_12"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "notifications",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column("tenant_id", sa.String(64), sa.ForeignKey("tenants.id"), nullable=False),
        sa.Column("title", sa.String(200), nullable=False),
        sa.Column("message", sa.String(4000), nullable=False),
        sa.Column("type", sa.String(32), nullable=False),
        sa.Column("target_audience", sa.String(24), nullable=False),
        sa.Column("target_class", sa.String(80), nullable=True),
        sa.Column("target_student_id", sa.String(36), sa.ForeignKey("students.id"), nullable=True),
        sa.Column("priority", sa.String(16), nullable=False),
        sa.Column("created_by", sa.String(200), nullable=False),
        sa.Column("creator_id", sa.String(36), sa.ForeignKey("users.id"), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("expires_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("deleted_at", sa.DateTime(timezone=True), nullable=True),
    )
    op.create_index("ix_notifications_tenant_id", "notifications", ["tenant_id"])
    op.create_table(
        "notification_reads",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column("tenant_id", sa.String(64), sa.ForeignKey("tenants.id"), nullable=False),
        sa.Column("notification_id", sa.String(36), sa.ForeignKey("notifications.id"), nullable=False),
        sa.Column("user_id", sa.String(36), sa.ForeignKey("users.id"), nullable=False),
        sa.Column("read_at", sa.DateTime(timezone=True), nullable=False),
        sa.UniqueConstraint("notification_id", "user_id"),
    )
    for field in ("tenant_id", "notification_id", "user_id"):
        op.create_index(f"ix_notification_reads_{field}", "notification_reads", [field])


def downgrade() -> None:
    op.drop_table("notification_reads")
    op.drop_table("notifications")
