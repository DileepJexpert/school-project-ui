import '../models/admission_data.dart';
import '../core/constants/academic_year.dart';
import 'dio_client.dart';

class AdmissionApiService {
  static const _base = '/students';

  static Future<List<Student>> getStudents() async {
    final response = await DioClient.get(_base);
    return (response.data as List)
        .map((e) => Student.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<Student> getStudentById(String id) async {
    final response = await DioClient.get('$_base/$id');
    return Student.fromJson(response.data as Map<String, dynamic>);
  }

  static Future<void> submitAdmission(Student student) async {
    await DioClient.post('$_base/add', data: student.toJson());
  }

  /// Saves a walk-in enquiry WITHOUT generating a fee profile.
  /// Backend forces status = ENQUIRY and uses ENQ- prefix for the number.
  static Future<void> submitEnquiry(Student student) async {
    await DioClient.post('$_base/enquiry', data: student.toJson());
  }

  static Future<void> updateStudent(String id, Student student) async {
    await DioClient.put('$_base/$id', data: student.toJson());
  }

  static Future<void> deleteStudent(String id) async {
    await DioClient.delete('$_base/$id');
  }

  /// A failed run can be retried: already moved students no longer match the
  /// source class and year. The server still needs a transactional rollover API
  /// for an atomic school-wide operation.
  static Future<int> promoteClass(
      String fromClass, String fromYear, String? toClass, String newYear) async {
    if (AcademicYear.next(fromYear) != newYear) {
      throw ArgumentError('The target must be the year immediately after $fromYear.');
    }
    if (toClass != null && toClass == fromClass) {
      throw ArgumentError('The target class must differ from the source class.');
    }
    final all = await getStudents();
    final toUpdate = promotionCandidates(all, fromClass, fromYear);
    if (toUpdate.any((s) => s.id == null || s.id!.isEmpty)) {
      throw StateError('A student has no ID; promotion was not started.');
    }
    var completed = 0;
    for (final s in toUpdate) {
      final updated = Student(
        id: s.id,
        fullName: s.fullName,
        dateOfBirth: s.dateOfBirth,
        gender: s.gender,
        bloodGroup: s.bloodGroup,
        nationality: s.nationality,
        religion: s.religion,
        motherTongue: s.motherTongue,
        aadharNumber: s.aadharNumber,
        classForAdmission: toClass ?? s.classForAdmission,
        academicYear: toClass != null ? newYear : s.academicYear,
        dateOfAdmission: s.dateOfAdmission,
        admissionNumber: s.admissionNumber,
        rollNumber: s.rollNumber,
        status: toClass != null ? s.status : 'INACTIVE',
        parentDetails: s.parentDetails,
        contactDetails: s.contactDetails,
        previousSchoolDetails: s.previousSchoolDetails,
      );
      try {
        await updateStudent(s.id!, updated);
        completed++;
      } catch (error) {
        throw StateError(
            '$completed of ${toUpdate.length} students updated. Refresh the list '
            'and retry $fromClass ($fromYear); already moved students are skipped. '
            'Last error: $error');
      }
    }
    return completed;
  }

  static List<Student> promotionCandidates(
          List<Student> students, String fromClass, String fromYear) =>
      students
          .where((s) =>
              s.classForAdmission == fromClass &&
              s.academicYear == fromYear &&
              s.status.toUpperCase() == 'ACTIVE')
          .toList();

  /// Fetches the full student record, sets [newStatus], then PUTs it back.
  static Future<void> toggleStatus(String id, String newStatus) async {
    final s = await getStudentById(id);
    final updated = Student(
      id: s.id,
      fullName: s.fullName,
      dateOfBirth: s.dateOfBirth,
      gender: s.gender,
      bloodGroup: s.bloodGroup,
      nationality: s.nationality,
      religion: s.religion,
      motherTongue: s.motherTongue,
      aadharNumber: s.aadharNumber,
      classForAdmission: s.classForAdmission,
      academicYear: s.academicYear,
      dateOfAdmission: s.dateOfAdmission,
      admissionNumber: s.admissionNumber,
      rollNumber: s.rollNumber,
      status: newStatus,
      parentDetails: s.parentDetails,
      contactDetails: s.contactDetails,
      previousSchoolDetails: s.previousSchoolDetails,
    );
    await updateStudent(id, updated);
  }

  /// Bulk-assigns roll numbers. [assignments] maps student id → roll number string.
  /// Fetches each student once and PUTs back with the new roll number.
  /// Returns the count of successful updates.
  static Future<int> assignRollNumbers(
      Map<String, String> assignments) async {
    int count = 0;
    for (final entry in assignments.entries) {
      final id = entry.key;
      final roll = entry.value.trim();
      if (roll.isEmpty) continue;
      final s = await getStudentById(id);
      final updated = Student(
        id: s.id,
        fullName: s.fullName,
        dateOfBirth: s.dateOfBirth,
        gender: s.gender,
        bloodGroup: s.bloodGroup,
        nationality: s.nationality,
        religion: s.religion,
        motherTongue: s.motherTongue,
        aadharNumber: s.aadharNumber,
        classForAdmission: s.classForAdmission,
        academicYear: s.academicYear,
        dateOfAdmission: s.dateOfAdmission,
        admissionNumber: s.admissionNumber,
        rollNumber: roll,
        status: s.status,
        parentDetails: s.parentDetails,
        contactDetails: s.contactDetails,
        previousSchoolDetails: s.previousSchoolDetails,
      );
      await updateStudent(id, updated);
      count++;
    }
    return count;
  }
}
