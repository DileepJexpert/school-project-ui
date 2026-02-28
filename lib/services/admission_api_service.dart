import '../models/admission_data.dart';
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

  static Future<void> updateStudent(String id, Student student) async {
    await DioClient.put('$_base/$id', data: student.toJson());
  }

  static Future<void> deleteStudent(String id) async {
    await DioClient.delete('$_base/$id');
  }

  /// Promotes all ACTIVE students in [fromClass] to [toClass] with [newYear].
  /// Pass [toClass] = null to graduate Class-12 students (sets status → INACTIVE).
  /// Returns the number of students updated.
  static Future<int> promoteClass(
      String fromClass, String? toClass, String newYear) async {
    final all = await getStudents();
    final toUpdate = all
        .where((s) => s.classForAdmission == fromClass && s.status == 'ACTIVE')
        .toList();
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
        status: toClass != null ? s.status : 'INACTIVE',
        parentDetails: s.parentDetails,
        contactDetails: s.contactDetails,
        previousSchoolDetails: s.previousSchoolDetails,
      );
      await updateStudent(s.id!, updated);
    }
    return toUpdate.length;
  }

  /// Fetches the full student record, flips [newStatus], then PUTs it back.
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
      status: newStatus,
      parentDetails: s.parentDetails,
      contactDetails: s.contactDetails,
      previousSchoolDetails: s.previousSchoolDetails,
    );
    await updateStudent(id, updated);
  }
}
