import '../models/timetable_model.dart';
import 'dio_client.dart';

class TimetableApiService {
  static const _base = '/timetable';

  /// Returns the full weekly timetable for a class.
  static Future<List<TimetableModel>> getClassTimetable(
      String className, String academicYear) async {
    final response = await DioClient.get(
      '$_base/$className',
      queryParams: {'academicYear': academicYear},
    );
    return (response.data as List)
        .map((e) => TimetableModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Creates or updates a day's timetable entry.
  static Future<TimetableModel> saveOrUpdateTimetable(
      TimetableModel timetable) async {
    final response = await DioClient.post(_base, data: timetable.toJson());
    return TimetableModel.fromJson(response.data as Map<String, dynamic>);
  }

  /// Deletes a single timetable entry by ID.
  static Future<void> deleteTimetableEntry(String id) async {
    await DioClient.delete('$_base/entry/$id');
  }

  /// Deletes all timetable entries for a class in an academic year.
  static Future<void> deleteTimetableByClass(
      String className, String academicYear) async {
    await DioClient.delete(
      '$_base/$className',
      queryParams: {'academicYear': academicYear},
    );
  }
}
