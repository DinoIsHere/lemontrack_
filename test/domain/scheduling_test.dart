import 'package:flutter_test/flutter_test.dart';
import 'package:lemontrack_/domain/models/time_block.dart';
import 'package:lemontrack_/domain/scheduling/conflict.dart';
import 'package:lemontrack_/domain/scheduling/free_slot.dart';

TimeBlock block(String id, int sh, int sm, int eh, int em) {
  final day = DateTime(2026, 10, 30);
  return TimeBlock(
    id: id,
    title: id,
    startUtc: day.add(Duration(hours: sh, minutes: sm)).toUtc(),
    endUtc: day.add(Duration(hours: eh, minutes: em)).toUtc(),
    timezone: 'TEST',
    categoryId: 'deep_work',
    status: BlockStatus.planned,
    trackedSeconds: 0,
    priority: 1,
    source: BlockSource.user,
    createdAtUtc: DateTime.utc(2026),
    updatedAtUtc: DateTime.utc(2026),
  );
}

void main() {
  group('conflict detection', () {
    test('overlapping blocks conflict', () {
      final a = block('a', 9, 0, 11, 0);
      final b = block('b', 10, 30, 12, 0);
      final conflicts = findConflicts(a, [a, b]);
      expect(conflicts.length, 1);
      expect(conflicts.first.overlapMinutes, 30);
    });

    test('adjacent blocks do not conflict', () {
      final a = block('a', 9, 0, 11, 0);
      final b = block('b', 11, 0, 12, 0);
      expect(hasConflict(a, [a, b]), isFalse);
    });
  });

  group('free slot search', () {
    final day = DateTime(2026, 10, 30);

    test('finds gap between blocks within workday', () {
      final a = block('a', 9, 0, 11, 0);
      final b = block('b', 12, 0, 13, 0);
      final slots = findFreeSlots([a, b], day);
      expect(slots.any((s) => s.start == DateTime(2026, 10, 30, 11) && s.end == DateTime(2026, 10, 30, 12)), true);
    });

    test('earliest free slot respects duration', () {
      final a = block('a', 9, 0, 11, 30);
      final slot = findEarliestFreeSlot([a], day, 30);
      expect(slot, isNotNull);
      expect(slot!.start.hour, 11);
      expect(slot.start.minute, 30);
    });

    test('no slot when day is full', () {
      final full = [
        block('x', 9, 0, 13, 30),
        block('y', 13, 30, 18, 0),
      ];
      expect(findEarliestFreeSlot(full, day, 30), isNull);
    });
  });
}
