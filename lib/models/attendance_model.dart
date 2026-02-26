class AttendanceModel {
  final String? id;
  final String studentId;
  final String studentName;
  final String className;
  final String academicYear;
  final String date;
  final String status; // PRESENT, ABSENT, LATE, HALF_DAY
  final String? markedBy;
  final String? remarks;

  const AttendanceModel({
    this.id,
    required this.studentId,
    required this.studentName,
    required this.className,
    required this.academicYear,
    required this.date,
    required this.status,
    this.markedBy,
    this.remarks,
  });

  factory AttendanceModel.fromJson(Map<String, dynamic> json) {
    return AttendanceModel(
      id: json['id'],
      studentId: json['studentId'] ?? '',
      studentName: json['studentName'] ?? '',
      className: json['className'] ?? '',
      academicYear: json['academicYear'] ?? '',
      date: json['date'] ?? '',
      status: json['status'] ?? 'PRESENT',
      markedBy: json['markedBy'],
      remarks: json['remarks'],
    );
  }
}

class AttendanceSummaryModel {
  final String studentId;
  final String studentName;
  final String className;
  final String academicYear;
  final int totalDays;
  final int presentDays;
  final int absentDays;
  final int lateDays;
  final int halfDays;
  final double attendancePercentage;

  const AttendanceSummaryModel({
    required this.studentId,
    required this.studentName,
    required this.className,
    required this.academicYear,
    required this.totalDays,
    required this.presentDays,
    required this.absentDays,
    required this.lateDays,
    required this.halfDays,
    required this.attendancePercentage,
  });

  factory AttendanceSummaryModel.fromJson(Map<String, dynamic> json) {
    return AttendanceSummaryModel(
      studentId: json['studentId'] ?? '',
      studentName: json['studentName'] ?? '',
      className: json['className'] ?? '',
      academicYear: json['academicYear'] ?? '',
      totalDays: (json['totalDays'] ?? 0) as int,
      presentDays: (json['presentDays'] ?? 0) as int,
      absentDays: (json['absentDays'] ?? 0) as int,
      lateDays: (json['lateDays'] ?? 0) as int,
      halfDays: (json['halfDays'] ?? 0) as int,
      attendancePercentage: (json['attendancePercentage'] ?? 0.0).toDouble(),
    );
  }
}
