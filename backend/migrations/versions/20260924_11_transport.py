"""Tenant-scoped buses, routes, and historical assignments."""

from alembic import op
import sqlalchemy as sa

revision = "20260924_11"
down_revision = "20260924_10"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "transport_routes",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column("tenant_id", sa.String(64), sa.ForeignKey("tenants.id"), nullable=False),
        sa.Column("zone_name", sa.String(120), nullable=False),
        sa.Column("display_name", sa.String(200), nullable=False),
        sa.Column("areas_covered", sa.String(1000), nullable=False),
        sa.Column("stops", sa.JSON(), nullable=False),
        sa.Column("first_pickup_time", sa.String(40), nullable=False),
        sa.Column("monthly_fee", sa.Numeric(12, 2), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("deleted_at", sa.DateTime(timezone=True), nullable=True),
        sa.UniqueConstraint("tenant_id", "zone_name"),
    )
    op.create_index("ix_transport_routes_tenant_id", "transport_routes", ["tenant_id"])
    op.create_table(
        "buses",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column("tenant_id", sa.String(64), sa.ForeignKey("tenants.id"), nullable=False),
        sa.Column("bus_number", sa.String(80), nullable=False),
        sa.Column("driver_name", sa.String(200), nullable=False),
        sa.Column("driver_mobile", sa.String(40), nullable=False),
        sa.Column("route_id", sa.String(36), sa.ForeignKey("transport_routes.id"), nullable=True),
        sa.Column("capacity", sa.Integer(), nullable=False),
        sa.Column("status", sa.String(16), nullable=False),
        sa.Column("insurance_expiry", sa.String(40), nullable=True),
        sa.Column("notes", sa.String(1000), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("deleted_at", sa.DateTime(timezone=True), nullable=True),
        sa.UniqueConstraint("tenant_id", "bus_number"),
        sa.CheckConstraint("capacity > 0", name="bus_capacity_positive"),
    )
    op.create_index("ix_buses_tenant_id", "buses", ["tenant_id"])
    op.create_table(
        "transport_assignments",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column("tenant_id", sa.String(64), sa.ForeignKey("tenants.id"), nullable=False),
        sa.Column("student_id", sa.String(36), sa.ForeignKey("students.id"), nullable=False),
        sa.Column("student_name", sa.String(200), nullable=False),
        sa.Column("class_name", sa.String(80), nullable=False),
        sa.Column("roll_number", sa.String(32), nullable=True),
        sa.Column("bus_id", sa.String(36), sa.ForeignKey("buses.id"), nullable=False),
        sa.Column("route_id", sa.String(36), sa.ForeignKey("transport_routes.id"), nullable=False),
        sa.Column("pickup_stop", sa.String(200), nullable=True),
        sa.Column("status", sa.String(16), nullable=False),
        sa.Column("assigned_date", sa.Date(), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
    )
    for field in ("tenant_id", "student_id", "bus_id", "route_id"):
        op.create_index(f"ix_transport_assignments_{field}", "transport_assignments", [field])
    op.create_index(
        "uq_transport_active_student", "transport_assignments", ["tenant_id", "student_id"],
        unique=True, postgresql_where=sa.text("status = 'ACTIVE'"), sqlite_where=sa.text("status = 'ACTIVE'"),
    )


def downgrade() -> None:
    op.drop_table("transport_assignments")
    op.drop_table("buses")
    op.drop_table("transport_routes")
