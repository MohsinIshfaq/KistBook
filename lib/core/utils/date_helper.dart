class DateHelper {
  static DateTime startOfDay(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  static DateTime shiftFridayToSaturday(DateTime value) {
    final normalized = startOfDay(value);
    if (normalized.weekday == DateTime.friday) {
      return normalized.add(const Duration(days: 1));
    }
    return normalized;
  }

  static DateTime nextCollectibleDay(DateTime value) =>
      shiftFridayToSaturday(startOfDay(value).add(const Duration(days: 1)));

  static DateTime reconcileMissedDueDate({
    required DateTime currentDueDate,
    required DateTime today,
  }) {
    var dueDate = shiftFridayToSaturday(currentDueDate);
    final normalizedToday = startOfDay(today);
    while (dueDate.isBefore(normalizedToday)) {
      dueDate = nextCollectibleDay(dueDate);
    }
    return dueDate;
  }
}
