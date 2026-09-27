"""Tenant-bound private chat rooms and messages."""

from alembic import op
import sqlalchemy as sa

revision = "20260924_14"
down_revision = "20260924_13"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "chat_rooms",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column("tenant_id", sa.String(64), sa.ForeignKey("tenants.id"), nullable=False),
        sa.Column("participant_1_id", sa.String(36), sa.ForeignKey("users.id"), nullable=False),
        sa.Column("participant_2_id", sa.String(36), sa.ForeignKey("users.id"), nullable=False),
        sa.Column("student_key", sa.String(36), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.UniqueConstraint("tenant_id", "participant_1_id", "participant_2_id", "student_key"),
    )
    for field in ("tenant_id", "participant_1_id", "participant_2_id"):
        op.create_index(f"ix_chat_rooms_{field}", "chat_rooms", [field])
    op.create_table(
        "chat_messages",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column("tenant_id", sa.String(64), sa.ForeignKey("tenants.id"), nullable=False),
        sa.Column("room_id", sa.String(36), sa.ForeignKey("chat_rooms.id"), nullable=False),
        sa.Column("sender_id", sa.String(36), sa.ForeignKey("users.id"), nullable=False),
        sa.Column("message", sa.String(4000), nullable=False),
        sa.Column("message_type", sa.String(16), nullable=False),
        sa.Column("timestamp", sa.DateTime(timezone=True), nullable=False),
        sa.Column("read_at", sa.DateTime(timezone=True), nullable=True),
    )
    for field in ("tenant_id", "room_id", "sender_id"):
        op.create_index(f"ix_chat_messages_{field}", "chat_messages", [field])


def downgrade() -> None:
    op.drop_table("chat_messages")
    op.drop_table("chat_rooms")
