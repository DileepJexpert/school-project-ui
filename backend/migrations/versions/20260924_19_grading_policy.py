"""Require an explicit school grading policy for each academic year."""

from alembic import op
import sqlalchemy as sa

revision = "20260924_19"
down_revision = "20260924_18"
branch_labels = None
depends_on = None


def upgrade() -> None:
    with op.batch_alter_table("academic_years") as batch:
        batch.add_column(sa.Column("grade_bands", sa.JSON(), nullable=True))
        batch.add_column(sa.Column("pass_percentage", sa.Numeric(5, 2), nullable=True))
        batch.add_column(sa.Column("exam_order", sa.JSON(), nullable=True))


def downgrade() -> None:
    with op.batch_alter_table("academic_years") as batch:
        batch.drop_column("exam_order")
        batch.drop_column("pass_percentage")
        batch.drop_column("grade_bands")
