// All fee-related models — no code generation, manual fromJson/toJson

// ─── School Summary (Reports Screen) ─────────────────────────────────────────

class MonthlyFeeSummary {
  final int month;
  final int year;
  final String label;
  final double amount;

  MonthlyFeeSummary({
    required this.month,
    required this.year,
    required this.label,
    required this.amount,
  });

  factory MonthlyFeeSummary.fromJson(Map<String, dynamic> json) =>
      MonthlyFeeSummary(
        month: json['month'] ?? 1,
        year: json['year'] ?? DateTime.now().year,
        label: json['label'] ?? '',
        amount: (json['amount'] ?? 0).toDouble(),
      );
}

class SchoolSummary {
  final int totalStudents;
  final Map<String, int> enrollmentByClass;
  final double totalFeesCollected;
  final double totalFeesDue;
  final double totalDiscountGiven;
  final int totalTransactions;
  final List<MonthlyFeeSummary> monthlyCollections;
  final List<PaymentModeSummary> paymentModeSummary;

  SchoolSummary({
    required this.totalStudents,
    required this.enrollmentByClass,
    required this.totalFeesCollected,
    required this.totalFeesDue,
    required this.totalDiscountGiven,
    required this.totalTransactions,
    required this.monthlyCollections,
    required this.paymentModeSummary,
  });

  factory SchoolSummary.fromJson(Map<String, dynamic> json) => SchoolSummary(
        totalStudents: json['totalStudents'] ?? 0,
        enrollmentByClass: (json['enrollmentByClass'] as Map<String, dynamic>? ?? {})
            .map((k, v) => MapEntry(k, (v as num).toInt())),
        totalFeesCollected: (json['totalFeesCollected'] ?? 0).toDouble(),
        totalFeesDue: (json['totalFeesDue'] ?? 0).toDouble(),
        totalDiscountGiven: (json['totalDiscountGiven'] ?? 0).toDouble(),
        totalTransactions: json['totalTransactions'] ?? 0,
        monthlyCollections: (json['monthlyCollections'] as List? ?? [])
            .map((e) => MonthlyFeeSummary.fromJson(e as Map<String, dynamic>))
            .toList(),
        paymentModeSummary: (json['paymentModeSummary'] as List? ?? [])
            .map((e) => PaymentModeSummary.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

// ─── Fee Installment ────────────────────────────────────────────────────────
class FeeInstallment {
  final String installmentName;
  final double amountDue;
  final String status;
  bool isSelectedForPayment;

  FeeInstallment({
    required this.installmentName,
    required this.amountDue,
    required this.status,
    this.isSelectedForPayment = false,
  });

  factory FeeInstallment.fromJson(Map<String, dynamic> json) => FeeInstallment(
        installmentName: json['installmentName'] ?? '',
        amountDue: (json['amountDue'] ?? 0).toDouble(),
        status: json['status'] ?? 'PENDING',
      );

  Map<String, dynamic> toJson() => {
        'installmentName': installmentName,
        'amountDue': amountDue,
        'status': status,
      };
}

// ─── Payment Record ──────────────────────────────────────────────────────────
class PaymentRecord {
  final String id;
  final String receiptNumber;
  final String studentId;
  final String studentName;
  final DateTime paymentDate;
  final double amountPaid;
  final double discount;
  final String paymentMode;
  final List<String> paidForInstallments;
  final String? remarks;

  PaymentRecord({
    required this.id,
    required this.receiptNumber,
    required this.studentId,
    required this.studentName,
    required this.paymentDate,
    required this.amountPaid,
    required this.discount,
    required this.paymentMode,
    required this.paidForInstallments,
    this.remarks,
  });

  factory PaymentRecord.fromJson(Map<String, dynamic> json) => PaymentRecord(
        id: json['transactionId'] ?? json['id'] ?? '',
        receiptNumber: json['receiptNumber'] ?? '',
        studentId: json['studentId'] ?? '',
        studentName: json['studentName'] ?? '',
        paymentDate: json['paymentDate'] != null
            ? DateTime.tryParse(json['paymentDate'].toString()) ?? DateTime.now()
            : DateTime.now(),
        amountPaid: (json['amountPaid'] ?? 0).toDouble(),
        discount: (json['discount'] ?? 0).toDouble(),
        paymentMode: json['paymentMode'] ?? '',
        paidForInstallments: List<String>.from(
            json['paidForInstallments'] ?? json['paidForMonths'] ?? []),
        remarks: json['remarks'],
      );
}

// ─── Student Fee Profile ─────────────────────────────────────────────────────
class StudentFeeProfile {
  final String id;
  final String name;
  final String className;
  final String rollNumber;
  final String parentName;
  final List<FeeInstallment> feeInstallments;
  final PaymentRecord? lastPayment;
  final double totalFees;
  final double paidFees;
  final double dueFees;
  final double totalDiscountGiven;

  StudentFeeProfile({
    required this.id,
    required this.name,
    required this.className,
    required this.rollNumber,
    required this.parentName,
    required this.feeInstallments,
    this.lastPayment,
    required this.totalFees,
    required this.paidFees,
    required this.dueFees,
    required this.totalDiscountGiven,
  });

  factory StudentFeeProfile.fromJson(Map<String, dynamic> json) =>
      StudentFeeProfile(
        id: json['id'] ?? '',
        name: json['name'] ?? '',
        className: json['className'] ?? '',
        rollNumber: json['rollNumber'] ?? '',
        parentName: json['parentName'] ?? '',
        feeInstallments: (json['feeInstallments'] as List? ?? [])
            .map((e) => FeeInstallment.fromJson(e))
            .toList(),
        lastPayment: json['lastPayment'] != null
            ? PaymentRecord.fromJson(json['lastPayment'])
            : null,
        totalFees: (json['totalFees'] ?? 0).toDouble(),
        paidFees: (json['paidFees'] ?? 0).toDouble(),
        dueFees: (json['dueFees'] ?? 0).toDouble(),
        totalDiscountGiven: (json['totalDiscountGiven'] ?? 0).toDouble(),
      );
}

// ─── Fee Payment Request ─────────────────────────────────────────────────────
class FeePaymentRequest {
  final String studentId;
  final double amount;
  final double discount;
  final List<String> installmentNames;
  final String paymentMode;
  final String? remarks;
  final String? chequeDetails;
  final String? transactionId;

  FeePaymentRequest({
    required this.studentId,
    required this.amount,
    required this.discount,
    required this.installmentNames,
    required this.paymentMode,
    this.remarks,
    this.chequeDetails,
    this.transactionId,
  });

  Map<String, dynamic> toJson() => {
        'studentId': studentId,
        'amount': amount,
        'discount': discount,
        'installmentNames': installmentNames,
        'paymentMode': paymentMode,
        if (remarks != null) 'remarks': remarks,
        if (chequeDetails != null) 'chequeDetails': chequeDetails,
        if (transactionId != null) 'transactionId': transactionId,
      };
}

// ─── Fee Report Models ───────────────────────────────────────────────────────
class FeeReportSummary {
  final double totalCollected;
  final double totalDue;
  final double totalDiscountGiven;
  final int totalTransactions;

  FeeReportSummary({
    required this.totalCollected,
    required this.totalDue,
    required this.totalDiscountGiven,
    required this.totalTransactions,
  });

  factory FeeReportSummary.fromJson(Map<String, dynamic> json) =>
      FeeReportSummary(
        totalCollected: (json['totalCollected'] ?? 0).toDouble(),
        totalDue: (json['totalDue'] ?? 0).toDouble(),
        totalDiscountGiven: (json['totalDiscountGiven'] ?? 0).toDouble(),
        totalTransactions: json['totalTransactions'] ?? 0,
      );
}

class ClassWiseFeeSummary {
  final String className;
  final double totalCollected;
  final double totalDiscount;
  final int transactionCount;

  ClassWiseFeeSummary({
    required this.className,
    required this.totalCollected,
    required this.totalDiscount,
    required this.transactionCount,
  });

  factory ClassWiseFeeSummary.fromJson(Map<String, dynamic> json) =>
      ClassWiseFeeSummary(
        className: json['classForAdmission'] ?? json['className'] ?? 'Unknown',
        totalCollected: (json['totalCollectedInClass'] ?? 0).toDouble(),
        totalDiscount: (json['totalDiscountInClass'] ?? 0).toDouble(),
        transactionCount: json['transactionCountInClass'] ?? 0,
      );
}

class PaymentModeSummary {
  final String paymentMode;
  final double totalAmount;

  PaymentModeSummary({required this.paymentMode, required this.totalAmount});

  factory PaymentModeSummary.fromJson(Map<String, dynamic> json) =>
      PaymentModeSummary(
        paymentMode: json['paymentMode'] ?? '',
        totalAmount: (json['totalAmount'] ?? 0).toDouble(),
      );
}

class TransactionRecord {
  final String id;
  final String studentName;
  final String className;
  final String rollNumber;
  final String receiptNumber;
  final DateTime paymentDate;
  final double amountPaid;
  final double discount;
  final String paymentMode;
  final List<String> paidForMonths;
  final String collectedBy;
  final String? remarks;

  TransactionRecord({
    required this.id,
    required this.studentName,
    required this.className,
    required this.rollNumber,
    required this.receiptNumber,
    required this.paymentDate,
    required this.amountPaid,
    required this.discount,
    required this.paymentMode,
    required this.paidForMonths,
    required this.collectedBy,
    this.remarks,
  });

  factory TransactionRecord.fromJson(Map<String, dynamic> json) =>
      TransactionRecord(
        id: json['id'] ?? '',
        studentName: json['studentName'] ?? '',
        className: json['className'] ?? '',
        rollNumber: json['rollNumber'] ?? '',
        receiptNumber: json['receiptNumber'] ?? '',
        paymentDate: json['paymentDate'] != null
            ? DateTime.tryParse(json['paymentDate'].toString()) ?? DateTime.now()
            : DateTime.now(),
        amountPaid: (json['amountPaid'] ?? 0).toDouble(),
        discount: (json['discount'] ?? 0).toDouble(),
        paymentMode: json['paymentMode'] ?? '',
        paidForMonths: List<String>.from(
            json['paidForMonths'] ?? json['paidForInstallments'] ?? []),
        collectedBy: json['collectedBy'] ?? 'Admin',
        remarks: json['remarks'],
      );
}

class FeeReportResponse {
  final FeeReportSummary summary;
  final List<ClassWiseFeeSummary> classSummaries;
  final List<PaymentModeSummary> paymentModeSummary;
  final List<TransactionRecord> transactions;

  FeeReportResponse({
    required this.summary,
    required this.classSummaries,
    required this.paymentModeSummary,
    required this.transactions,
  });

  factory FeeReportResponse.fromJson(Map<String, dynamic> json) {
    final txPage = json['transactionsPage'];
    final txList = txPage != null
        ? (txPage['content'] as List? ?? [])
        : (json['transactions'] as List? ?? []);
    return FeeReportResponse(
      summary: FeeReportSummary.fromJson(json['summary'] ?? {}),
      classSummaries: (json['classSummaries'] as List? ?? [])
          .map((e) => ClassWiseFeeSummary.fromJson(e))
          .toList(),
      paymentModeSummary: (json['paymentModeSummary'] as List? ?? [])
          .map((e) => PaymentModeSummary.fromJson(e))
          .toList(),
      transactions: txList.map((e) => TransactionRecord.fromJson(e)).toList(),
    );
  }
}

// ─── Fee Structure ───────────────────────────────────────────────────────────
class FeeComponent {
  String name;
  double amount;
  String frequency;
  String description;

  FeeComponent({
    required this.name,
    required this.amount,
    this.frequency = 'YEARLY',
    this.description = '',
  });

  // Backend field: feeName (not name), feeComponents list inside FeeStructure
  factory FeeComponent.fromJson(Map<String, dynamic> json) => FeeComponent(
        name: json['feeName'] ?? json['name'] ?? '',
        amount: (json['amount'] ?? 0) is num
            ? (json['amount'] ?? 0).toDouble()
            : double.tryParse(json['amount'].toString()) ?? 0.0,
        frequency: json['frequency'] ?? 'YEARLY',
        description: json['description'] ?? '',
      );

  Map<String, dynamic> toJson() => {
        'feeName': name,
        'amount': amount,
        'frequency': frequency,
        if (description.isNotEmpty) 'description': description,
      };
}

class FeeStructure {
  String? id;
  String className;
  String academicYear;
  List<FeeComponent> components;

  FeeStructure({
    this.id,
    required this.className,
    required this.academicYear,
    required this.components,
  });

  // Backend field: feeComponents (not components)
  factory FeeStructure.fromJson(Map<String, dynamic> json) => FeeStructure(
        id: json['id'],
        className: json['className'] ?? '',
        academicYear: json['academicYear'] ?? '',
        components: (json['feeComponents'] as List? ?? json['components'] as List? ?? [])
            .map((e) => FeeComponent.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  Map<String, dynamic> toJson() => {
        'className': className,
        'academicYear': academicYear,
        'feeComponents': components.map((c) => c.toJson()).toList(),
      };

  double get totalFee => components.fold<double>(0.0, (sum, c) => sum + c.amount);
}

// ─── Expense Model ───────────────────────────────────────────────────────────
class Expense {
  final String? id;
  final String title;
  final String category;
  final double amount;
  final DateTime date;
  final String paidTo;
  final String? remarks;

  Expense({
    this.id,
    required this.title,
    required this.category,
    required this.amount,
    required this.date,
    required this.paidTo,
    this.remarks,
  });

  factory Expense.fromJson(Map<String, dynamic> json) => Expense(
        id: json['id'],
        title: json['title'] ?? '',
        category: json['category'] ?? '',
        amount: (json['amount'] ?? 0).toDouble(),
        date: json['date'] != null
            ? DateTime.tryParse(json['date'].toString()) ?? DateTime.now()
            : DateTime.now(),
        paidTo: json['paidTo'] ?? '',
        remarks: json['remarks'],
      );

  Map<String, dynamic> toJson() => {
        'title': title,
        'category': category,
        'amount': amount,
        'date': date.toIso8601String().substring(0, 10),
        'paidTo': paidTo,
        if (remarks != null) 'remarks': remarks,
      };
}
