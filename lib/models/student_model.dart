class StudentModel {
  final String? id;
  final String fullName;
  final String? gender;
  final String? bloodGroup;
  final String? classForAdmission;
  final String? academicYear;
  final String? admissionNumber;
  final String? rollNumber;
  final String status;
  final Map<String, dynamic>? parentDetails;
  final Map<String, dynamic>? contactDetails;

  const StudentModel({
    this.id,
    required this.fullName,
    this.gender,
    this.bloodGroup,
    this.classForAdmission,
    this.academicYear,
    this.admissionNumber,
    this.rollNumber,
    this.status = 'ACTIVE',
    this.parentDetails,
    this.contactDetails,
  });

  factory StudentModel.fromJson(Map<String, dynamic> json) {
    return StudentModel(
      id: json['id'],
      fullName: json['fullName'] ?? '',
      gender: json['gender'],
      bloodGroup: json['bloodGroup'],
      classForAdmission: json['classForAdmission'],
      academicYear: json['academicYear'],
      admissionNumber: json['admissionNumber'],
      rollNumber: json['rollNumber'],
      status: json['status'] ?? 'ACTIVE',
      parentDetails: json['parentDetails'] is Map<String, dynamic>
          ? json['parentDetails'] as Map<String, dynamic>
          : null,
      contactDetails: json['contactDetails'] is Map<String, dynamic>
          ? json['contactDetails'] as Map<String, dynamic>
          : null,
    );
  }

  /// Extracts parent's primary phone number if available.
  String? get parentPhone {
    final contact = contactDetails;
    if (contact != null) {
      final p = contact['primaryContactNumber'];
      if (p != null && p.toString().trim().isNotEmpty) {
        return p.toString().trim();
      }
    }
    final parent = parentDetails;
    if (parent != null) {
      final f = parent['fatherMobile'];
      if (f != null && f.toString().trim().isNotEmpty) {
        return f.toString().trim();
      }
      final m = parent['motherMobile'];
      if (m != null && m.toString().trim().isNotEmpty) {
        return m.toString().trim();
      }
    }
    return null;
  }

  /// Extracts father or guardian name if available.
  String? get fatherName {
    final parent = parentDetails;
    if (parent != null) {
      final f = parent['fatherName'];
      if (f != null && f.toString().trim().isNotEmpty) {
        return f.toString().trim();
      }
      final m = parent['motherName'];
      if (m != null && m.toString().trim().isNotEmpty) {
        return m.toString().trim();
      }
    }
    return null;
  }
}
