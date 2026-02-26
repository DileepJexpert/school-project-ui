class NotificationModel {
  final String? id;
  final String title;
  final String message;
  final String type; // GENERAL, FEE_REMINDER, EXAM, EVENT, HOLIDAY, EMERGENCY
  final String targetAudience; // ALL, CLASS_SPECIFIC, INDIVIDUAL
  final String? targetClass;
  final String? targetStudentId;
  final String priority; // LOW, MEDIUM, HIGH
  final String? createdBy;
  final String? createdAt;
  final String? expiresAt;
  final bool read;

  const NotificationModel({
    this.id,
    required this.title,
    required this.message,
    required this.type,
    required this.targetAudience,
    this.targetClass,
    this.targetStudentId,
    this.priority = 'MEDIUM',
    this.createdBy,
    this.createdAt,
    this.expiresAt,
    this.read = false,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['id'],
      title: json['title'] ?? '',
      message: json['message'] ?? '',
      type: json['type'] ?? 'GENERAL',
      targetAudience: json['targetAudience'] ?? 'ALL',
      targetClass: json['targetClass'],
      targetStudentId: json['targetStudentId'],
      priority: json['priority'] ?? 'MEDIUM',
      createdBy: json['createdBy'],
      createdAt: json['createdAt'],
      expiresAt: json['expiresAt'],
      read: json['read'] ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'title': title,
        'message': message,
        'type': type,
        'targetAudience': targetAudience,
        if (targetClass != null) 'targetClass': targetClass,
        if (targetStudentId != null) 'targetStudentId': targetStudentId,
        'priority': priority,
        if (createdBy != null) 'createdBy': createdBy,
        if (expiresAt != null) 'expiresAt': expiresAt,
      };
}
