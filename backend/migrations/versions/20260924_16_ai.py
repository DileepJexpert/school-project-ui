"""Optional school AI settings, student conversations and usage."""

from alembic import op
import sqlalchemy as sa

revision = "20260924_16"
down_revision = "20260924_15"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "ai_configs",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column("tenant_id", sa.String(64), sa.ForeignKey("tenants.id"), nullable=False, unique=True),
        sa.Column("enabled", sa.Boolean(), nullable=False),
        sa.Column("enabled_modes", sa.JSON(), nullable=False),
        sa.Column("primary_provider", sa.String(32), nullable=False),
        sa.Column("ollama_base_url", sa.String(500), nullable=False),
        sa.Column("ollama_model", sa.String(120), nullable=False),
        sa.Column("daily_limit_per_student", sa.Integer(), nullable=False),
        sa.Column("max_conversation_turns", sa.Integer(), nullable=False),
        sa.Column("updated_by", sa.String(36), sa.ForeignKey("users.id"), nullable=True),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=True),
    )
    op.create_table(
        "ai_conversations",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column("tenant_id", sa.String(64), sa.ForeignKey("tenants.id"), nullable=False),
        sa.Column("user_id", sa.String(36), sa.ForeignKey("users.id"), nullable=False),
        sa.Column("homework_id", sa.String(36), sa.ForeignKey("homework.id"), nullable=True),
        sa.Column("mode", sa.String(16), nullable=False),
        sa.Column("subject", sa.String(120), nullable=False),
        sa.Column("class_name", sa.String(80), nullable=False),
        sa.Column("messages", sa.JSON(), nullable=False),
        sa.Column("session_active", sa.Boolean(), nullable=False),
        sa.Column("total_input_tokens", sa.Integer(), nullable=False),
        sa.Column("total_output_tokens", sa.Integer(), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("last_message_at", sa.DateTime(timezone=True), nullable=True),
    )
    op.create_index("ix_ai_conversations_tenant_id", "ai_conversations", ["tenant_id"])
    op.create_index("ix_ai_conversations_user_id", "ai_conversations", ["user_id"])
    op.create_table(
        "ai_usage",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column("tenant_id", sa.String(64), sa.ForeignKey("tenants.id"), nullable=False),
        sa.Column("user_id", sa.String(36), sa.ForeignKey("users.id"), nullable=False),
        sa.Column("conversation_id", sa.String(36), sa.ForeignKey("ai_conversations.id"), nullable=True),
        sa.Column("provider", sa.String(32), nullable=False),
        sa.Column("input_tokens", sa.Integer(), nullable=False),
        sa.Column("output_tokens", sa.Integer(), nullable=False),
        sa.Column("status", sa.String(16), nullable=False),
        sa.Column("request_timestamp", sa.DateTime(timezone=True), nullable=False),
    )
    op.create_index("ix_ai_usage_tenant_id", "ai_usage", ["tenant_id"])
    op.create_index("ix_ai_usage_user_id", "ai_usage", ["user_id"])


def downgrade() -> None:
    op.drop_table("ai_usage")
    op.drop_table("ai_conversations")
    op.drop_table("ai_configs")
