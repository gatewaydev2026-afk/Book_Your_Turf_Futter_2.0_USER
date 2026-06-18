// utils/helpers.dart
String formatTo12Hour(String time24) {
  if (time24.isEmpty || time24 == 'null' || time24 == 'NULL') {
    return 'Not specified';
  }

  try {
    String cleanTime = time24;
    if (cleanTime.contains(':')) {
      final parts = cleanTime.split(':');
      if (parts.length >= 2) {
        String hourStr = parts[0];
        String minuteStr = parts[1];
        if (minuteStr.contains(',')) minuteStr = minuteStr.split(',').first;
        if (minuteStr.contains('.')) minuteStr = minuteStr.split('.').first;
        if (minuteStr.length > 2) minuteStr = minuteStr.substring(0, 2);
        cleanTime = '$hourStr:$minuteStr';
      }
    }

    final parts = cleanTime.split(':');
    if (parts.length < 2) return time24;

    int hour = int.parse(parts[0]);
    int minute = int.parse(parts[1].split(',').first.split('.').first);
    String period = hour >= 12 ? 'PM' : 'AM';
    int hour12 = hour % 12;
    if (hour12 == 0) hour12 = 12;

    return '$hour12:${minute.toString().padLeft(2, '0')} $period';
  } catch (e) {
    return time24;
  }
}

String formatDate(DateTime date) {
  return "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
}