import 'package:intl/intl.dart';

DateTime startOfDay(DateTime d) => DateTime(d.year, d.month, d.day);
DateTime endOfDay(DateTime d) => DateTime(d.year, d.month, d.day, 23, 59, 59);

String formatTime(DateTime dt) => DateFormat('HH:mm').format(dt);
String formatDate(DateTime dt) => DateFormat('yyyy-MM-dd').format(dt);

DateTime roundToSnap(DateTime dt, int snapMinutes) {
  final mins = dt.minute + dt.hour * 60;
  final rounded = ((mins / snapMinutes).round() * snapMinutes);
  return DateTime(dt.year, dt.month, dt.day, rounded ~/ 60, rounded % 60);
}

String formatDuration(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes.remainder(60);
  if (h > 0) return '${h}h ${m}m';
  return '${m}m';
}
