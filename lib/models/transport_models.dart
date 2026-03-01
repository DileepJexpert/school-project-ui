class TransportBus {
  final String? id;
  final String busNumber;
  final String driverName;
  final String driverMobile;
  final String? routeId;
  final int capacity;
  final int assignedCount;
  final String status; // ACTIVE | MAINTENANCE | RETIRED
  final String? insuranceExpiry;
  final String? notes;

  const TransportBus({
    this.id,
    required this.busNumber,
    required this.driverName,
    required this.driverMobile,
    this.routeId,
    required this.capacity,
    this.assignedCount = 0,
    this.status = 'ACTIVE',
    this.insuranceExpiry,
    this.notes,
  });

  factory TransportBus.fromJson(Map<String, dynamic> j) => TransportBus(
        id:              j['id'] as String?,
        busNumber:       j['busNumber'] as String? ?? '',
        driverName:      j['driverName'] as String? ?? '',
        driverMobile:    j['driverMobile'] as String? ?? '',
        routeId:         j['routeId'] as String?,
        capacity:        (j['capacity'] as num?)?.toInt() ?? 0,
        assignedCount:   (j['assignedCount'] as num?)?.toInt() ?? 0,
        status:          j['status'] as String? ?? 'ACTIVE',
        insuranceExpiry: j['insuranceExpiry'] as String?,
        notes:           j['notes'] as String?,
      );

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        'busNumber':    busNumber,
        'driverName':   driverName,
        'driverMobile': driverMobile,
        if (routeId != null) 'routeId': routeId,
        'capacity':     capacity,
        'status':       status,
        if (insuranceExpiry != null) 'insuranceExpiry': insuranceExpiry,
        if (notes != null) 'notes': notes,
      };

  TransportBus copyWith({
    String? busNumber,
    String? driverName,
    String? driverMobile,
    String? routeId,
    int? capacity,
    String? status,
    String? insuranceExpiry,
    String? notes,
  }) =>
      TransportBus(
        id:              id,
        busNumber:       busNumber    ?? this.busNumber,
        driverName:      driverName   ?? this.driverName,
        driverMobile:    driverMobile ?? this.driverMobile,
        routeId:         routeId      ?? this.routeId,
        capacity:        capacity     ?? this.capacity,
        assignedCount:   assignedCount,
        status:          status       ?? this.status,
        insuranceExpiry: insuranceExpiry ?? this.insuranceExpiry,
        notes:           notes        ?? this.notes,
      );
}

// ─────────────────────────────────────────────────────────────────────────────

class TransportRoute {
  final String? id;
  final String zoneName;
  final String? displayName;
  final String areasCovered;
  final List<String> stops;
  final String firstPickupTime;
  final double monthlyFee;
  final int assignedCount;

  const TransportRoute({
    this.id,
    required this.zoneName,
    this.displayName,
    required this.areasCovered,
    required this.stops,
    required this.firstPickupTime,
    required this.monthlyFee,
    this.assignedCount = 0,
  });

  factory TransportRoute.fromJson(Map<String, dynamic> j) => TransportRoute(
        id:              j['id'] as String?,
        zoneName:        j['zoneName'] as String? ?? '',
        displayName:     j['displayName'] as String?,
        areasCovered:    j['areasCovered'] as String? ?? '',
        stops:           (j['stops'] as List<dynamic>?)
                             ?.map((e) => e as String)
                             .toList() ??
                         const [],
        firstPickupTime: j['firstPickupTime'] as String? ?? '',
        monthlyFee:      (j['monthlyFee'] as num?)?.toDouble() ?? 0,
        assignedCount:   (j['assignedCount'] as num?)?.toInt() ?? 0,
      );

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        'zoneName':        zoneName,
        if (displayName != null) 'displayName': displayName,
        'areasCovered':    areasCovered,
        'stops':           stops,
        'firstPickupTime': firstPickupTime,
        'monthlyFee':      monthlyFee,
      };
}

// ─────────────────────────────────────────────────────────────────────────────

class StudentTransportAssignment {
  final String? id;
  final String studentId;
  final String studentName;
  final String className;
  final String? rollNumber;
  final String busId;
  final String routeId;
  final String? pickupStop;
  final String status;
  final String? assignedDate;

  const StudentTransportAssignment({
    this.id,
    required this.studentId,
    required this.studentName,
    required this.className,
    this.rollNumber,
    required this.busId,
    required this.routeId,
    this.pickupStop,
    this.status = 'ACTIVE',
    this.assignedDate,
  });

  factory StudentTransportAssignment.fromJson(Map<String, dynamic> j) =>
      StudentTransportAssignment(
        id:           j['id'] as String?,
        studentId:    j['studentId'] as String? ?? '',
        studentName:  j['studentName'] as String? ?? '',
        className:    j['className'] as String? ?? '',
        rollNumber:   j['rollNumber'] as String?,
        busId:        j['busId'] as String? ?? '',
        routeId:      j['routeId'] as String? ?? '',
        pickupStop:   j['pickupStop'] as String?,
        status:       j['status'] as String? ?? 'ACTIVE',
        assignedDate: j['assignedDate'] as String?,
      );

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        'studentId':   studentId,
        'studentName': studentName,
        'className':   className,
        if (rollNumber != null) 'rollNumber': rollNumber,
        'busId':       busId,
        'routeId':     routeId,
        if (pickupStop != null) 'pickupStop': pickupStop,
        'status':      status,
      };
}

// ─────────────────────────────────────────────────────────────────────────────

class TransportStats {
  final int totalBuses;
  final int activeBuses;
  final int maintenanceBuses;
  final int totalRoutes;
  final int totalStudentsAssigned;

  const TransportStats({
    required this.totalBuses,
    required this.activeBuses,
    required this.maintenanceBuses,
    required this.totalRoutes,
    required this.totalStudentsAssigned,
  });

  factory TransportStats.fromJson(Map<String, dynamic> j) => TransportStats(
        totalBuses:            (j['totalBuses'] as num?)?.toInt() ?? 0,
        activeBuses:           (j['activeBuses'] as num?)?.toInt() ?? 0,
        maintenanceBuses:      (j['maintenanceBuses'] as num?)?.toInt() ?? 0,
        totalRoutes:           (j['totalRoutes'] as num?)?.toInt() ?? 0,
        totalStudentsAssigned: (j['totalStudentsAssigned'] as num?)?.toInt() ?? 0,
      );
}
