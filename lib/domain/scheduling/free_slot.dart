import '../models/time_block.dart';

class FreeSlot {
  final DateTime start;
  final DateTime end;
  const FreeSlot({required this.start, required this.end});
  int get durationMinutes => end.difference(start).inMinutes;
}

List<FreeSlot> findFreeSlots(
  List<TimeBlock> blocks,
  DateTime day, {
  int workStart = 9,
  int workEnd = 18,
  int minDuration = 5,
}) {
  final slots = <FreeSlot>[];
  final dayStart = DateTime(day.year, day.month, day.day, workStart);
  final dayEnd = DateTime(day.year, day.month, day.day, workEnd);

  final sorted = blocks.where((b) => b.deletedAtUtc == null)
      .where((b) {
        final l = b.startUtc.toLocal();
        return l.year == day.year && l.month == day.month && l.day == day.day;
      })
      .toList()
        ..sort((a, b) => a.startUtc.compareTo(b.startUtc));

  var cursor = dayStart;
  for (final block in sorted) {
    final blockStart = block.startUtc.toLocal();
    final blockEnd = block.endUtc.toLocal();
    if (blockStart.isAfter(cursor) && blockStart.difference(cursor).inMinutes >= minDuration) {
      slots.add(FreeSlot(start: cursor, end: blockStart));
    }
    if (blockEnd.isAfter(cursor)) cursor = blockEnd;
  }
  if (dayEnd.isAfter(cursor) && dayEnd.difference(cursor).inMinutes >= minDuration) {
    slots.add(FreeSlot(start: cursor, end: dayEnd));
  }
  return slots;
}

FreeSlot? findEarliestFreeSlot(
  List<TimeBlock> blocks,
  DateTime day,
  int durationMinutes, {
  int workStart = 9,
  int workEnd = 18,
}) {
  final slots = findFreeSlots(blocks, day, workStart: workStart, workEnd: workEnd, minDuration: durationMinutes);
  return slots.isEmpty ? null : slots.first;
}
