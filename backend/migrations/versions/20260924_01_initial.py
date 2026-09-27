"""Initial tenant, student, enrollment and fee tables."""

from alembic import op
import sqlalchemy as sa

revision = "20260924_01"
down_revision = None
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "tenants",
        sa.Column("id", sa.String(64), primary_key=True),
        sa.Column("name", sa.String(200), nullable=False),
    )
    op.create_table(
        "students",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column("tenant_id", sa.String(64), sa.ForeignKey("tenants.id"), nullable=False),
        sa.Column("full_name", sa.String(200), nullable=False),
        sa.Column("date_of_birth", sa.Date(), nullable=False),
        sa.Column("gender", sa.String(32), nullable=False),
        sa.Column("blood_group", sa.String(16), nullable=False),
        sa.Column("nationality", sa.String(80), nullable=False),
        sa.Column("religion", sa.String(80), nullable=False),
        sa.Column("mother_tongue", sa.String(80), nullable=False),
        sa.Column("aadhar_number", sa.String(32), nullable=False),
        sa.Column("class_name", sa.String(80), nullable=False),
        sa.Column("academic_year", sa.String(9), nullable=False),
        sa.Column("date_of_admission", sa.Date(), nullable=False),
        sa.Column("admission_number", sa.String(64), nullable=True),
        sa.Column("roll_number", sa.String(32), nullable=True),
        sa.Column("status", sa.String(16), nullable=False),
        sa.Column("parent_details", sa.JSON(), nullable=False),
        sa.Column("contact_details", sa.JSON(), nullable=False),
        sa.Column("previous_school_details", sa.JSON(), nullable=False),
        sa.UniqueConstraint("tenant_id", "admission_number"),
    )
    op.create_index("ix_students_tenant_id", "students", ["tenant_id"])
    op.create_table(
        "enrollments",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column("tenant_id", sa.String(64), sa.ForeignKey("tenants.id"), nullable=False),
        sa.Column("student_id", sa.String(36), sa.ForeignKey("students.id"), nullable=False),
        sa.Column("academic_year", sa.String(9), nullable=False),
        sa.Column("class_name", sa.String(80), nullable=False),
        sa.Column("roll_number", sa.String(32), nullable=True),
        sa.Column("date_of_admission", sa.Date(), nullable=False),
        sa.Column("status", sa.String(16), nullable=False),
        sa.UniqueConstraint("tenant_id", "student_id", "academic_year"),
    )
    op.create_index("ix_enrollments_tenant_id", "enrollments", ["tenant_id"])
    op.create_index("ix_enrollments_student_id", "enrollments", ["student_id"])
    op.create_table(
        "fee_structures",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column("tenant_id", sa.String(64), sa.ForeignKey("tenants.id"), nullable=False),
        sa.Column("class_name", sa.String(80), nullable=False),
        sa.Column("academic_year", sa.String(9), nullable=False),
        sa.UniqueConstraint("tenant_id", "class_name", "academic_year"),
    )
    op.create_index("ix_fee_structures_tenant_id", "fee_structures", ["tenant_id"])
    op.create_table(
        "fee_components",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column("structure_id", sa.String(36), sa.ForeignKey("fee_structures.id"), nullable=False),
        sa.Column("position", sa.Integer(), nullable=False),
        sa.Column("name", sa.String(120), nullable=False),
        sa.Column("amount", sa.Numeric(12, 2), nullable=False),
        sa.Column("frequency", sa.String(16), nullable=False),
        sa.Column("description", sa.String(500), nullable=False),
        sa.UniqueConstraint("structure_id", "name"),
        sa.CheckConstraint("amount > 0", name="fee_component_amount_positive"),
    )
    op.create_table(
        "fee_profiles",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column("tenant_id", sa.String(64), sa.ForeignKey("tenants.id"), nullable=False),
        sa.Column("enrollment_id", sa.String(36), sa.ForeignKey("enrollments.id"), nullable=False),
        sa.Column("fee_structure_id", sa.String(36), sa.ForeignKey("fee_structures.id"), nullable=False),
        sa.UniqueConstraint("enrollment_id"),
    )
    op.create_index("ix_fee_profiles_tenant_id", "fee_profiles", ["tenant_id"])
    op.create_table(
        "fee_installments",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column("profile_id", sa.String(36), sa.ForeignKey("fee_profiles.id"), nullable=False),
        sa.Column("position", sa.Integer(), nullable=False),
        sa.Column("name", sa.String(160), nullable=False),
        sa.Column("amount_due", sa.Numeric(12, 2), nullable=False),
        sa.Column("status", sa.String(16), nullable=False),
        sa.UniqueConstraint("profile_id", "name"),
        sa.CheckConstraint("amount_due >= 0", name="fee_installment_amount_nonnegative"),
    )


def downgrade() -> None:
    for table in (
        "fee_installments", "fee_profiles", "fee_components", "fee_structures",
        "enrollments", "students", "tenants",
    ):
        op.drop_table(table)
