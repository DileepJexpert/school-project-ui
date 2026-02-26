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
    );
  }
}
