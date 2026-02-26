class TimetableModel {
  final String? id;
  final String className;
  final String academicYear;
  final String dayOfWeek;
  final List<PeriodModel> periods;

  const TimetableModel({
    this.id,
    required this.className,
    required this.academicYear,
    required this.dayOfWeek,
    required this.periods,
  });

  factory TimetableModel.fromJson(Map<String, dynamic> json) {
    return TimetableModel(
      id: json['id'],
      className: json['className'] ?? '',
      academicYear: json['academicYear'] ?? '',
      dayOfWeek: json['dayOfWeek'] ?? '',
      periods: (json['periods'] as List<dynamic>? ?? [])
          .map((p) => PeriodModel.fromJson(p as Map<String, dynamic>))
          .toList()
        ..sort((a, b) => a.periodNumber.compareTo(b.periodNumber)),
    );
  }

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        'className': className,
        'academicYear': academicYear,
        'dayOfWeek': dayOfWeek,
        'periods': periods.map((p) => p.toJson()).toList(),
      };
}

class PeriodModel {
  final int periodNumber;
  final String subject;
  final String teacherName;
  final String startTime;
  final String endTime;

  const PeriodModel({
    required this.periodNumber,
    required this.subject,
    required this.teacherName,
    required this.startTime,
    required this.endTime,
  });

  factory PeriodModel.fromJson(Map<String, dynamic> json) {
    return PeriodModel(
      periodNumber: (json['periodNumber'] ?? 1) as int,
      subject: json['subject'] ?? '',
      teacherName: json['teacherName'] ?? '',
      startTime: json['startTime'] ?? '',
      endTime: json['endTime'] ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'periodNumber': periodNumber,
        'subject': subject,
        'teacherName': teacherName,
        'startTime': startTime,
        'endTime': endTime,
      };
}
