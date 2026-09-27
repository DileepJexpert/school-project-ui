"""Snapshot the collector and student name on each receipt."""

from alembic import op
import sqlalchemy as sa

revision = "20260924_20"
down_revision = "20260924_19"
branch_labels = None
depends_on = None


def upgrade() -> None:
    with op.batch_alter_table("payments") as batch:
        batch.add_column(sa.Column(
            "collected_by_user_id", sa.String(36),
            sa.ForeignKey("users.id", name="fk_payments_collected_by_user_id_users"), nullable=True,
        ))
        batch.add_column(sa.Column("student_name_snapshot", sa.String(200), nullable=True))


def downgrade() -> None:
    with op.batch_alter_table("payments") as batch:
        batch.drop_column("student_name_snapshot")
        batch.drop_column("collected_by_user_id")
