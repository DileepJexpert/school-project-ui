// ─────────────────────────────────────────────────────────────────────────────
// Result Module — Data Models
// One model per backend entity / DTO.
// ─────────────────────────────────────────────────────────────────────────────

// ── StudentResult ─────────────────────────────────────────────────────────────

class StudentResult {
  final String? id;
  final String studentId;
  final String studentName;
  final String? rollNumber;
  final String className;
  final String academicYear;
  final String examType;
  final String subject;
  final double marksObtained;
  final double maxMarks;
  final double percentage;
  final String grade;
  final double gradePoint;
  final bool isPassed;
  final int classRank;
  final String? teacherRemarks;
  final bool isPublished;
  final String? enteredBy;

  const StudentResult({
    this.id,
    required this.studentId,
    required this.studentName,
    this.rollNumber,
    required this.className,
    required this.academicYear,
    required this.examType,
    required this.subject,
    required this.marksObtained,
    required this.maxMarks,
    this.percentage = 0,
    this.grade = '',
    this.gradePoint = 0,
    this.isPassed = false,
    this.classRank = 0,
    this.teacherRemarks,
    this.isPublished = false,
    this.enteredBy,
  });

  factory StudentResult.fromJson(Map<String, dynamic> j) => StudentResult(
        id: j['id'],
        studentId: j['studentId'] ?? '',
        studentName: j['studentName'] ?? '',
        rollNumber: j['rollNumber'],
        className: j['className'] ?? '',
        academicYear: j['academicYear'] ?? '',
        examType: j['examType'] ?? '',
        subject: j['subject'] ?? '',
        marksObtained: (j['marksObtained'] ?? 0).toDouble(),
        maxMarks: (j['maxMarks'] ?? 100).toDouble(),
        percentage: (j['percentage'] ?? 0).toDouble(),
        grade: j['grade'] ?? '',
        gradePoint: (j['gradePoint'] ?? 0).toDouble(),
        isPassed: j['isPassed'] ?? false,
        classRank: j['classRank'] ?? 0,
        teacherRemarks: j['teacherRemarks'],
        isPublished: j['isPublished'] ?? false,
        enteredBy: j['enteredBy'],
      );
}

// ── ExamConfig ────────────────────────────────────────────────────────────────

class ExamConfig {
  final String? id;
  final String academicYear;
  final String examType;
  final String displayName;
  final int weightagePercent;
  final double maxMarksDefault;
  final bool isActive;

  const ExamConfig({
    this.id,
    required this.academicYear,
    required this.examType,
    required this.displayName,
    required this.weightagePercent,
    required this.maxMarksDefault,
    this.isActive = true,
  });

  factory ExamConfig.fromJson(Map<String, dynamic> j) => ExamConfig(
        id: j['id'],
        academicYear: j['academicYear'] ?? '',
        examType: j['examType'] ?? '',
        displayName: j['displayName'] ?? '',
        weightagePercent: j['weightagePercent'] ?? 0,
        maxMarksDefault: (j['maxMarksDefault'] ?? 100).toDouble(),
        isActive: j['isActive'] ?? true,
      );

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        'academicYear': academicYear,
        'examType': examType,
        'displayName': displayName,
        'weightagePercent': weightagePercent,
        'maxMarksDefault': maxMarksDefault,
        'isActive': isActive,
      };
}

// ── CoscholasticArea & Assessment ────────────────────────────────────────────

class CoscholasticArea {
  final String name;
  final String grade;
  final String? remarks;

  const CoscholasticArea({
    required this.name,
    required this.grade,
    this.remarks,
  });

  factory CoscholasticArea.fromJson(Map<String, dynamic> j) => CoscholasticArea(
        name: j['name'] ?? '',
        grade: j['grade'] ?? '',
        remarks: j['remarks'],
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'grade': grade,
        if (remarks != null) 'remarks': remarks,
      };
}

class CoscholasticAssessment {
  final String? id;
  final String studentId;
  final String studentName;
  final String className;
  final String academicYear;
  final String term;
  final List<CoscholasticArea> areas;

  const CoscholasticAssessment({
    this.id,
    required this.studentId,
    required this.studentName,
    required this.className,
    required this.academicYear,
    required this.term,
    required this.areas,
  });

  factory CoscholasticAssessment.fromJson(Map<String, dynamic> j) =>
      CoscholasticAssessment(
        id: j['id'],
        studentId: j['studentId'] ?? '',
        studentName: j['studentName'] ?? '',
        className: j['className'] ?? '',
        academicYear: j['academicYear'] ?? '',
        term: j['term'] ?? '',
        areas: (j['areas'] as List? ?? [])
            .map((a) => CoscholasticArea.fromJson(a as Map<String, dynamic>))
            .toList(),
      );
}

// ── Report Card ───────────────────────────────────────────────────────────────

class ReportCardExamResult {
  final double marksObtained;
  final double maxMarks;
  final double percentage;
  final String grade;
  final double gradePoint;
  final bool isPassed;
  final int classRank;
  final String? teacherRemarks;

  const ReportCardExamResult({
    required this.marksObtained,
    required this.maxMarks,
    required this.percentage,
    required this.grade,
    required this.gradePoint,
    required this.isPassed,
    required this.classRank,
    this.teacherRemarks,
  });

  factory ReportCardExamResult.fromJson(Map<String, dynamic> j) =>
      ReportCardExamResult(
        marksObtained: (j['marksObtained'] ?? 0).toDouble(),
        maxMarks: (j['maxMarks'] ?? 100).toDouble(),
        percentage: (j['percentage'] ?? 0).toDouble(),
        grade: j['grade'] ?? '',
        gradePoint: (j['gradePoint'] ?? 0).toDouble(),
        isPassed: j['isPassed'] ?? false,
        classRank: j['classRank'] ?? 0,
        teacherRemarks: j['teacherRemarks'],
      );
}

class ReportCardSubjectSummary {
  final String subject;
  final Map<String, ReportCardExamResult> examResults;
  final double weightedPercentage;
  final String predictedGrade;
  final String trend;

  const ReportCardSubjectSummary({
    required this.subject,
    required this.examResults,
    required this.weightedPercentage,
    required this.predictedGrade,
    required this.trend,
  });

  factory ReportCardSubjectSummary.fromJson(Map<String, dynamic> j) {
    final raw = j['examResults'] as Map<String, dynamic>? ?? {};
    final mapped = raw.map((k, v) =>
        MapEntry(k, ReportCardExamResult.fromJson(v as Map<String, dynamic>)));
    return ReportCardSubjectSummary(
      subject: j['subject'] ?? '',
      examResults: mapped,
      weightedPercentage: (j['weightedPercentage'] ?? 0).toDouble(),
      predictedGrade: j['predictedGrade'] ?? '',
      trend: j['trend'] ?? 'STABLE',
    );
  }
}

class StudentReportCard {
  final String studentId;
  final String studentName;
  final String className;
  final String? rollNumber;
  final String academicYear;
  final List<ReportCardSubjectSummary> subjects;
  final double cumulativePercentage;
  final String overallGrade;
  final double overallGradePoint;
  final int classRank;
  final CoscholasticAssessment? coscholasticTerm1;
  final CoscholasticAssessment? coscholasticTerm2;

  const StudentReportCard({
    required this.studentId,
    required this.studentName,
    required this.className,
    this.rollNumber,
    required this.academicYear,
    required this.subjects,
    required this.cumulativePercentage,
    required this.overallGrade,
    required this.overallGradePoint,
    required this.classRank,
    this.coscholasticTerm1,
    this.coscholasticTerm2,
  });

  factory StudentReportCard.fromJson(Map<String, dynamic> j) => StudentReportCard(
        studentId: j['studentId'] ?? '',
        studentName: j['studentName'] ?? '',
        className: j['className'] ?? '',
        rollNumber: j['rollNumber'],
        academicYear: j['academicYear'] ?? '',
        subjects: (j['subjects'] as List? ?? [])
            .map((s) =>
                ReportCardSubjectSummary.fromJson(s as Map<String, dynamic>))
            .toList(),
        cumulativePercentage: (j['cumulativePercentage'] ?? 0).toDouble(),
        overallGrade: j['overallGrade'] ?? '',
        overallGradePoint: (j['overallGradePoint'] ?? 0).toDouble(),
        classRank: j['classRank'] ?? 0,
        coscholasticTerm1: j['coscholasticTerm1'] != null
            ? CoscholasticAssessment.fromJson(
                j['coscholasticTerm1'] as Map<String, dynamic>)
            : null,
        coscholasticTerm2: j['coscholasticTerm2'] != null
            ? CoscholasticAssessment.fromJson(
                j['coscholasticTerm2'] as Map<String, dynamic>)
            : null,
      );
}

// ── Analytics ─────────────────────────────────────────────────────────────────

class SubjectAnalysis {
  final String subject;
  final double classAverage;
  final double passPercentage;
  final String performance;
  final int totalStudents;

  const SubjectAnalysis({
    required this.subject,
    required this.classAverage,
    required this.passPercentage,
    required this.performance,
    required this.totalStudents,
  });

  factory SubjectAnalysis.fromJson(Map<String, dynamic> j) => SubjectAnalysis(
        subject: j['subject'] ?? '',
        classAverage: (j['classAverage'] ?? 0).toDouble(),
        passPercentage: (j['passPercentage'] ?? 0).toDouble(),
        performance: j['performance'] ?? 'AVERAGE',
        totalStudents: j['totalStudents'] ?? 0,
      );
}

class AtRiskStudentInfo {
  final String studentId;
  final String studentName;
  final String? rollNumber;
  final List<String> failedSubjects;
  final List<String> droppingSubjects;
  final double overallPercentage;
  final String riskLevel;

  const AtRiskStudentInfo({
    required this.studentId,
    required this.studentName,
    this.rollNumber,
    required this.failedSubjects,
    required this.droppingSubjects,
    required this.overallPercentage,
    required this.riskLevel,
  });

  factory AtRiskStudentInfo.fromJson(Map<String, dynamic> j) => AtRiskStudentInfo(
        studentId: j['studentId'] ?? '',
        studentName: j['studentName'] ?? '',
        rollNumber: j['rollNumber'],
        failedSubjects: List<String>.from(j['failedSubjects'] ?? []),
        droppingSubjects: List<String>.from(j['droppingSubjects'] ?? []),
        overallPercentage: (j['overallPercentage'] ?? 0).toDouble(),
        riskLevel: j['riskLevel'] ?? 'WARNING',
      );
}

class RecognitionEntry {
  final String category;
  final String studentName;
  final String detail;

  const RecognitionEntry({
    required this.category,
    required this.studentName,
    required this.detail,
  });

  factory RecognitionEntry.fromJson(Map<String, dynamic> j) => RecognitionEntry(
        category: j['category'] ?? '',
        studentName: j['studentName'] ?? '',
        detail: j['detail'] ?? '',
      );
}

class ClassAnalytics {
  final String className;
  final String? examType;
  final String academicYear;
  final int totalStudents;
  final double classAverage;
  final double highestPercentage;
  final double lowestPercentage;
  final double passPercentage;
  final List<SubjectAnalysis> subjectHeatmap;
  final List<AtRiskStudentInfo> atRiskStudents;
  final List<RecognitionEntry> recognition;

  const ClassAnalytics({
    required this.className,
    this.examType,
    required this.academicYear,
    required this.totalStudents,
    required this.classAverage,
    required this.highestPercentage,
    required this.lowestPercentage,
    required this.passPercentage,
    required this.subjectHeatmap,
    required this.atRiskStudents,
    required this.recognition,
  });

  factory ClassAnalytics.fromJson(Map<String, dynamic> j) => ClassAnalytics(
        className: j['className'] ?? '',
        examType: j['examType'],
        academicYear: j['academicYear'] ?? '',
        totalStudents: j['totalStudents'] ?? 0,
        classAverage: (j['classAverage'] ?? 0).toDouble(),
        highestPercentage: (j['highestPercentage'] ?? 0).toDouble(),
        lowestPercentage: (j['lowestPercentage'] ?? 0).toDouble(),
        passPercentage: (j['passPercentage'] ?? 0).toDouble(),
        subjectHeatmap: (j['subjectHeatmap'] as List? ?? [])
            .map((s) => SubjectAnalysis.fromJson(s as Map<String, dynamic>))
            .toList(),
        atRiskStudents: (j['atRiskStudents'] as List? ?? [])
            .map((s) => AtRiskStudentInfo.fromJson(s as Map<String, dynamic>))
            .toList(),
        recognition: (j['recognition'] as List? ?? [])
            .map((s) => RecognitionEntry.fromJson(s as Map<String, dynamic>))
            .toList(),
      );
}
