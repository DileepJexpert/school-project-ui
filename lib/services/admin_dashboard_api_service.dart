import '../models/fee_models.dart';
import 'dio_client.dart';

class AdminDashboardApiService {
  static Future<AdminDashboardData> getDashboard() async {
    final response = await DioClient.get('/admin/dashboard');
    return AdminDashboardData.fromJson(response.data as Map<String, dynamic>);
  }
}

class AdminDashboardData {
  final SchoolSummary schoolSummary;
  final Map<String, dynamic> staffDashboard;
  final AttendancePulse attendancePulse;
  final AdmissionPulse admissionPulse;
  final AcademicPulse academicPulse;
  final DisciplinePulse disciplinePulse;
  final CommunicationPulse communicationPulse;
  final TransportPulse transportPulse;
  final List<DashboardDueStudent> topDueStudents;
  final List<DashboardActionItem> actionQueue;

  AdminDashboardData({
    required this.schoolSummary,
    required this.staffDashboard,
    required this.attendancePulse,
    required this.admissionPulse,
    required this.academicPulse,
    required this.disciplinePulse,
    required this.communicationPulse,
    required this.transportPulse,
    required this.topDueStudents,
    required this.actionQueue,
  });

  factory AdminDashboardData.fromJson(Map<String, dynamic> json) {
    return AdminDashboardData(
      schoolSummary: SchoolSummary.fromJson(
          json['schoolSummary'] as Map<String, dynamic>? ?? {}),
      staffDashboard:
          Map<String, dynamic>.from(json['staffDashboard'] as Map? ?? {}),
      attendancePulse: AttendancePulse.fromJson(
          json['attendancePulse'] as Map<String, dynamic>? ?? {}),
      admissionPulse: AdmissionPulse.fromJson(
          json['admissionPulse'] as Map<String, dynamic>? ?? {}),
      academicPulse: AcademicPulse.fromJson(
          json['academicPulse'] as Map<String, dynamic>? ?? {}),
      disciplinePulse: DisciplinePulse.fromJson(
          json['disciplinePulse'] as Map<String, dynamic>? ?? {}),
      communicationPulse: CommunicationPulse.fromJson(
          json['communicationPulse'] as Map<String, dynamic>? ?? {}),
      transportPulse: TransportPulse.fromJson(
          json['transportPulse'] as Map<String, dynamic>? ?? {}),
      topDueStudents: (json['topDueStudents'] as List? ?? [])
          .map((e) => DashboardDueStudent.fromJson(e as Map<String, dynamic>))
          .toList(),
      actionQueue: (json['actionQueue'] as List? ?? [])
          .map((e) => DashboardActionItem.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class AttendancePulse {
  final int totalClasses;
  final int markedClasses;
  final int unmarkedClasses;
  final int present;
  final int absent;
  final int late;
  final int halfDay;
  final List<String> unmarkedClassNames;

  AttendancePulse({
    required this.totalClasses,
    required this.markedClasses,
    required this.unmarkedClasses,
    required this.present,
    required this.absent,
    required this.late,
    required this.halfDay,
    required this.unmarkedClassNames,
  });

  factory AttendancePulse.fromJson(Map<String, dynamic> json) =>
      AttendancePulse(
        totalClasses: (json['totalClasses'] as num?)?.toInt() ?? 0,
        markedClasses: (json['markedClasses'] as num?)?.toInt() ?? 0,
        unmarkedClasses: (json['unmarkedClasses'] as num?)?.toInt() ?? 0,
        present: (json['present'] as num?)?.toInt() ?? 0,
        absent: (json['absent'] as num?)?.toInt() ?? 0,
        late: (json['late'] as num?)?.toInt() ?? 0,
        halfDay: (json['halfDay'] as num?)?.toInt() ?? 0,
        unmarkedClassNames: (json['unmarkedClassNames'] as List? ?? [])
            .map((e) => '$e')
            .toList(),
      );
}

class AdmissionPulse {
  final int activeStudents;
  final int enquiries;
  final int todayAdmissions;
  final int followUpsNeeded;

  AdmissionPulse({
    required this.activeStudents,
    required this.enquiries,
    required this.todayAdmissions,
    required this.followUpsNeeded,
  });

  factory AdmissionPulse.fromJson(Map<String, dynamic> json) => AdmissionPulse(
        activeStudents: (json['activeStudents'] as num?)?.toInt() ?? 0,
        enquiries: (json['enquiries'] as num?)?.toInt() ?? 0,
        todayAdmissions: (json['todayAdmissions'] as num?)?.toInt() ?? 0,
        followUpsNeeded: (json['followUpsNeeded'] as num?)?.toInt() ?? 0,
      );
}

class AcademicPulse {
  final int totalResultRecords;
  final int unpublishedResultRecords;
  final int failedResultRecords;
  final int atRiskStudents;
  final List<ClassAcademicSignal> weakClasses;

  AcademicPulse({
    required this.totalResultRecords,
    required this.unpublishedResultRecords,
    required this.failedResultRecords,
    required this.atRiskStudents,
    required this.weakClasses,
  });

  factory AcademicPulse.fromJson(Map<String, dynamic> json) => AcademicPulse(
        totalResultRecords: (json['totalResultRecords'] as num?)?.toInt() ?? 0,
        unpublishedResultRecords:
            (json['unpublishedResultRecords'] as num?)?.toInt() ?? 0,
        failedResultRecords:
            (json['failedResultRecords'] as num?)?.toInt() ?? 0,
        atRiskStudents: (json['atRiskStudents'] as num?)?.toInt() ?? 0,
        weakClasses: (json['weakClasses'] as List? ?? [])
            .map((e) => ClassAcademicSignal.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class ClassAcademicSignal {
  final String className;
  final double averagePercentage;
  final int failedRecords;
  final int unpublishedRecords;

  ClassAcademicSignal({
    required this.className,
    required this.averagePercentage,
    required this.failedRecords,
    required this.unpublishedRecords,
  });

  factory ClassAcademicSignal.fromJson(Map<String, dynamic> json) =>
      ClassAcademicSignal(
        className: json['className']?.toString() ?? 'Unknown',
        averagePercentage: (json['averagePercentage'] as num?)?.toDouble() ?? 0,
        failedRecords: (json['failedRecords'] as num?)?.toInt() ?? 0,
        unpublishedRecords: (json['unpublishedRecords'] as num?)?.toInt() ?? 0,
      );
}

class DisciplinePulse {
  final int openIncidents;
  final int criticalIncidents;
  final int parentNotPending;

  DisciplinePulse({
    required this.openIncidents,
    required this.criticalIncidents,
    required this.parentNotPending,
  });

  factory DisciplinePulse.fromJson(Map<String, dynamic> json) =>
      DisciplinePulse(
        openIncidents: (json['openIncidents'] as num?)?.toInt() ?? 0,
        criticalIncidents: (json['criticalIncidents'] as num?)?.toInt() ?? 0,
        parentNotPending: (json['parentNotPending'] as num?)?.toInt() ?? 0,
      );
}

class CommunicationPulse {
  final int totalNotifications;
  final int unreadNotifications;
  final int highPriorityNotifications;

  CommunicationPulse({
    required this.totalNotifications,
    required this.unreadNotifications,
    required this.highPriorityNotifications,
  });

  factory CommunicationPulse.fromJson(Map<String, dynamic> json) =>
      CommunicationPulse(
        totalNotifications: (json['totalNotifications'] as num?)?.toInt() ?? 0,
        unreadNotifications:
            (json['unreadNotifications'] as num?)?.toInt() ?? 0,
        highPriorityNotifications:
            (json['highPriorityNotifications'] as num?)?.toInt() ?? 0,
      );
}

class TransportPulse {
  final int totalBuses;
  final int activeBuses;
  final int maintenanceBuses;
  final int assignedStudents;

  TransportPulse({
    required this.totalBuses,
    required this.activeBuses,
    required this.maintenanceBuses,
    required this.assignedStudents,
  });

  factory TransportPulse.fromJson(Map<String, dynamic> json) => TransportPulse(
        totalBuses: (json['totalBuses'] as num?)?.toInt() ?? 0,
        activeBuses: (json['activeBuses'] as num?)?.toInt() ?? 0,
        maintenanceBuses: (json['maintenanceBuses'] as num?)?.toInt() ?? 0,
        assignedStudents: (json['assignedStudents'] as num?)?.toInt() ?? 0,
      );
}

class DashboardDueStudent {
  final String studentId;
  final String name;
  final String className;
  final String rollNumber;
  final double dueFees;

  DashboardDueStudent({
    required this.studentId,
    required this.name,
    required this.className,
    required this.rollNumber,
    required this.dueFees,
  });

  factory DashboardDueStudent.fromJson(Map<String, dynamic> json) =>
      DashboardDueStudent(
        studentId: json['studentId']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
        className: json['className']?.toString() ?? '',
        rollNumber: json['rollNumber']?.toString() ?? '',
        dueFees: (json['dueFees'] as num?)?.toDouble() ??
            double.tryParse(json['dueFees']?.toString() ?? '') ??
            0,
      );
}

class DashboardActionItem {
  final String title;
  final String subtitle;
  final String severity;
  final String module;
  final String routeHint;

  DashboardActionItem({
    required this.title,
    required this.subtitle,
    required this.severity,
    required this.module,
    required this.routeHint,
  });

  factory DashboardActionItem.fromJson(Map<String, dynamic> json) =>
      DashboardActionItem(
        title: json['title']?.toString() ?? '',
        subtitle: json['subtitle']?.toString() ?? '',
        severity: json['severity']?.toString() ?? 'LOW',
        module: json['module']?.toString() ?? '',
        routeHint: json['routeHint']?.toString() ?? '',
      );
}
