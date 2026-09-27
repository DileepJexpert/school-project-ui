"""Keep payment reversals and their reason in the ledger."""

from alembic import op
import sqlalchemy as sa

revision = "20260924_18"
down_revision = "20260924_17"
branch_labels = None
depends_on = None


def upgrade() -> None:
    with op.batch_alter_table("payments") as batch:
        batch.add_column(sa.Column("voided_at", sa.DateTime(timezone=True), nullable=True))
        batch.add_column(sa.Column("void_reason", sa.String(500), nullable=True))
        batch.add_column(sa.Column(
            "voided_by_user_id", sa.String(36),
            sa.ForeignKey("users.id", name="fk_payments_voided_by_user_id_users"), nullable=True,
        ))


def downgrade() -> None:
    with op.batch_alter_table("payments") as batch:
        batch.drop_column("voided_by_user_id")
        batch.drop_column("void_reason")
        batch.drop_column("voided_at")
