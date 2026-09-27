"""Store public contact enquiries for the school office."""

from alembic import op
import sqlalchemy as sa

revision = "20260924_22"
down_revision = "20260924_21"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "contact_enquiries",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column("tenant_id", sa.String(64), sa.ForeignKey("tenants.id"), nullable=False),
        sa.Column("name", sa.String(200), nullable=False),
        sa.Column("email", sa.String(320), nullable=False),
        sa.Column("phone", sa.String(40), nullable=False),
        sa.Column("grade_interested", sa.String(80), nullable=False),
        sa.Column("message", sa.String(4000), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
    )
    op.create_index("ix_contact_enquiries_tenant_id", "contact_enquiries", ["tenant_id"])


def downgrade() -> None:
    op.drop_table("contact_enquiries")
