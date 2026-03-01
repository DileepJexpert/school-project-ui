import '../models/transport_models.dart';
import 'dio_client.dart';

class TransportApiService {
  static const _buses      = '/transport/buses';
  static const _routes     = '/transport/routes';
  static const _assignments = '/transport/assignments';
  static const _stats      = '/transport/stats';

  // ── Buses ─────────────────────────────────────────────────────────────────

  static Future<List<TransportBus>> getAllBuses() async {
    final r = await DioClient.get(_buses);
    return (r.data as List)
        .map((e) => TransportBus.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<TransportBus> createBus(Map<String, dynamic> data) async {
    final r = await DioClient.post(_buses, data: data);
    return TransportBus.fromJson(r.data as Map<String, dynamic>);
  }

  static Future<TransportBus> updateBus(
      String id, Map<String, dynamic> data) async {
    final r = await DioClient.put('$_buses/$id', data: data);
    return TransportBus.fromJson(r.data as Map<String, dynamic>);
  }

  static Future<void> deleteBus(String id) async {
    await DioClient.delete('$_buses/$id');
  }

  // ── Routes ────────────────────────────────────────────────────────────────

  static Future<List<TransportRoute>> getAllRoutes() async {
    final r = await DioClient.get(_routes);
    return (r.data as List)
        .map((e) => TransportRoute.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<TransportRoute> createRoute(Map<String, dynamic> data) async {
    final r = await DioClient.post(_routes, data: data);
    return TransportRoute.fromJson(r.data as Map<String, dynamic>);
  }

  static Future<TransportRoute> updateRoute(
      String id, Map<String, dynamic> data) async {
    final r = await DioClient.put('$_routes/$id', data: data);
    return TransportRoute.fromJson(r.data as Map<String, dynamic>);
  }

  static Future<void> deleteRoute(String id) async {
    await DioClient.delete('$_routes/$id');
  }

  // ── Assignments ───────────────────────────────────────────────────────────

  static Future<List<StudentTransportAssignment>> getAllAssignments() async {
    final r = await DioClient.get(_assignments);
    return (r.data as List)
        .map((e) =>
            StudentTransportAssignment.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<List<StudentTransportAssignment>> getBusRoster(
      String busId) async {
    final r = await DioClient.get('$_assignments/bus/$busId');
    return (r.data as List)
        .map((e) =>
            StudentTransportAssignment.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Returns null if the student has no active assignment.
  static Future<StudentTransportAssignment?> getStudentAssignment(
      String studentId) async {
    try {
      final r = await DioClient.get('$_assignments/student/$studentId');
      if (r.statusCode == 204 || r.data == null) return null;
      return StudentTransportAssignment.fromJson(
          r.data as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  static Future<StudentTransportAssignment> assignStudent(
      Map<String, dynamic> data) async {
    final r = await DioClient.post(_assignments, data: data);
    return StudentTransportAssignment.fromJson(r.data as Map<String, dynamic>);
  }

  static Future<void> removeAssignment(String id) async {
    await DioClient.delete('$_assignments/$id');
  }

  // ── Stats ─────────────────────────────────────────────────────────────────

  static Future<TransportStats> getStats() async {
    final r = await DioClient.get(_stats);
    return TransportStats.fromJson(r.data as Map<String, dynamic>);
  }
}
