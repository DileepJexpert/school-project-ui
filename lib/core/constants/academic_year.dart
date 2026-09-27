/// Academic years accepted by the school APIs use either YYYY-YYYY or YYYY-YY.
class AcademicYear {
  static int currentStart([DateTime? date]) {
    final today = date ?? DateTime.now();
    return today.month >= 4 ? today.year : today.year - 1;
  }

  static String currentLong([DateTime? date]) => longYear(currentStart(date));

  static String currentShort([DateTime? date]) => shortYear(currentStart(date));

  static String longYear(int start) => '$start-${start + 1}';

  static String shortYear(int start) =>
      '$start-${((start + 1) % 100).toString().padLeft(2, '0')}';

  static String? next(String value) {
    final match = RegExp(r'^(\d{4})-(\d{2}|\d{4})$').firstMatch(value.trim());
    if (match == null) return null;
    final start = int.parse(match.group(1)!);
    final end = int.parse(match.group(2)!);
    final expected = match.group(2)!.length == 2 ? (start + 1) % 100 : start + 1;
    if (end != expected) return null;
    return match.group(2)!.length == 2
        ? shortYear(start + 1)
        : longYear(start + 1);
  }

  /// Covers older records and future admissions without a release each year.
  static List<String> choices({bool short = false, String? include}) {
    final current = currentStart();
    final years = [
      for (var start = current - 5; start <= current + 5; start++)
        short ? shortYear(start) : longYear(start),
    ];
    if (include != null && include.isNotEmpty && !years.contains(include)) {
      years.add(include);
      years.sort();
    }
    return years;
  }
}
