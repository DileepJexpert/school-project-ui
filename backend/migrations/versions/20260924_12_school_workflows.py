"""Homework, discipline incidents, and certificate records."""

from alembic import op
import sqlalchemy as sa

revision = "20260924_12"
down_revision = "20260924_11"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "homework",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column("tenant_id", sa.String(64), sa.ForeignKey("tenants.id"), nullable=False),
        sa.Column("title", sa.String(200), nullable=False),
        sa.Column("description", sa.String(4000), nullable=False),
        sa.Column("class_name", sa.String(80), nullable=False),
        sa.Column("subject", sa.String(120), nullable=False),
        sa.Column("teacher_id", sa.String(36), sa.ForeignKey("users.id"), nullable=False),
        sa.Column("teacher_name", sa.String(200), nullable=False),
        sa.Column("due_date", sa.Date(), nullable=False),
        sa.Column("assigned_date", sa.Date(), nullable=False),
        sa.Column("academic_year", sa.String(9), nullable=False),
        sa.Column("status", sa.String(16), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("deleted_at", sa.DateTime(timezone=True), nullable=True),
    )
    op.create_index("ix_homework_tenant_id", "homework", ["tenant_id"])
    op.create_table(
        "incidents",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column("tenant_id", sa.String(64), sa.ForeignKey("tenants.id"), nullable=False),
        sa.Column("student_id", sa.String(36), sa.ForeignKey("students.id"), nullable=False),
        sa.Column("student_name", sa.String(200), nullable=False),
        sa.Column("class_name", sa.String(80), nullable=False),
        sa.Column("academic_year", sa.String(9), nullable=False),
        sa.Column("severity", sa.String(16), nullable=False),
        sa.Column("category", sa.String(32), nullable=False),
        sa.Column("description", sa.String(4000), nullable=False),
        sa.Column("action_taken", sa.String(2000), nullable=False),
        sa.Column("reported_by", sa.String(200), nullable=False),
        sa.Column("incident_date", sa.Date(), nullable=False),
        sa.Column("parent_notified", sa.Boolean(), nullable=False),
        sa.Column("parent_notified_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("follow_up_notes", sa.String(2000), nullable=False),
        sa.Column("resolved", sa.Boolean(), nullable=False),
        sa.Column("resolved_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
    )
    op.create_index("ix_incidents_tenant_id", "incidents", ["tenant_id"])
    op.create_index("ix_incidents_student_id", "incidents", ["student_id"])
    op.create_table(
        "certificate_records",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column("tenant_id", sa.String(64), sa.ForeignKey("tenants.id"), nullable=False),
        sa.Column("student_id", sa.String(36), sa.ForeignKey("students.id"), nullable=False),
        sa.Column("student_name", sa.String(200), nullable=False),
        sa.Column("class_name", sa.String(80), nullable=False),
        sa.Column("academic_year", sa.String(9), nullable=False),
        sa.Column("certificate_type", sa.String(24), nullable=False),
        sa.Column("serial_number", sa.String(80), nullable=False),
        sa.Column("reason", sa.String(1000), nullable=False),
        sa.Column("additional_fields", sa.JSON(), nullable=False),
        sa.Column("generated_by", sa.String(200), nullable=False),
        sa.Column("generated_at", sa.DateTime(timezone=True), nullable=False),
        sa.UniqueConstraint("tenant_id", "serial_number"),
    )
    op.create_index("ix_certificate_records_tenant_id", "certificate_records", ["tenant_id"])
    op.create_index("ix_certificate_records_student_id", "certificate_records", ["student_id"])


def downgrade() -> None:
    op.drop_table("certificate_records")
    op.drop_table("incidents")
    op.drop_table("homework")
