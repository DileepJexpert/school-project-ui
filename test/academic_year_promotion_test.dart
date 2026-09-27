import 'package:flutter_test/flutter_test.dart';
import 'package:school_website/core/constants/academic_year.dart';
import 'package:school_website/models/admission_data.dart';
import 'package:school_website/services/admission_api_service.dart';

Student student(String id, String className, String year, String status) => Student(
      id: id,
      fullName: id,
      dateOfBirth: DateTime(2010),
      gender: 'Female',
      bloodGroup: '',
      nationality: '',
      religion: '',
      motherTongue: '',
      aadharNumber: '',
      classForAdmission: className,
      academicYear: year,
      dateOfAdmission: DateTime(2025),
      admissionNumber: id,
      status: status,
      parentDetails: ParentDetails(
        fatherName: '', fatherOccupation: '', fatherMobile: '', fatherEmail: '',
        motherName: '', motherOccupation: '', motherMobile: '', motherEmail: '',
      ),
      contactDetails: ContactDetails(
        permanentAddress: '', correspondenceAddress: '', primaryContactNumber: '',
      ),
      previousSchoolDetails: PreviousSchoolDetails(
        schoolName: '', lastClass: '', board: '',
      ),
    );

void main() {
  test('April starts a new academic year and March stays in the old year', () {
    expect(AcademicYear.currentLong(DateTime(2027, 3, 31)), '2026-2027');
    expect(AcademicYear.currentLong(DateTime(2027, 4, 1)), '2027-2028');
    expect(AcademicYear.currentShort(DateTime(2027, 3, 31)), '2026-27');
  });

  test('next year is valid for both API year formats', () {
    expect(AcademicYear.next('2025-2026'), '2026-2027');
    expect(AcademicYear.next('2025-26'), '2026-27');
    expect(AcademicYear.next('2025-2027'), isNull);
    expect(AcademicYear.next('bad'), isNull);
  });

  test('retry targets only the remaining active source cohort', () {
    final students = [
      student('remaining', 'Class 5 - A', '2025-2026', 'ACTIVE'),
      student('already-moved', 'Class 6 - A', '2026-2027', 'ACTIVE'),
      student('other-year', 'Class 5 - A', '2024-2025', 'ACTIVE'),
      student('inactive', 'Class 5 - A', '2025-2026', 'INACTIVE'),
    ];
    final candidates = AdmissionApiService.promotionCandidates(
        students, 'Class 5 - A', '2025-2026');
    expect(candidates.map((s) => s.id), ['remaining']);
  });
}
