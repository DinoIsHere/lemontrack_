import '../models/time_block.dart';

class Conflict {
  final TimeBlock blockA;
  final TimeBlock blockB;
  final int overlapMinutes;

  Conflict({required this.blockA, required this.blockB, required this.overlapMinutes});
}

List<Conflict> findConflicts(TimeBlock block, List<TimeBlock> allBlocks) {
  final conflicts = <Conflict>[];
  for (final other in allBlocks) {
    if (other.id == block.id || other.deletedAtUtc != null) continue;
    if (block.startUtc.isBefore(other.endUtc) && other.startUtc.isBefore(block.endUtc)) {
      final overlap = block.startUtc.isAfter(other.startUtc) ? block.startUtc : other.startUtc;
      final overlapEnd = block.endUtc.isBefore(other.endUtc) ? block.endUtc : other.endUtc;
      conflicts.add(Conflict(
        blockA: block,
        blockB: other,
        overlapMinutes: overlapEnd.difference(overlap).inMinutes,
      ));
    }
  }
  return conflicts;
}

bool hasConflict(TimeBlock block, List<TimeBlock> allBlocks) => findConflicts(block, allBlocks).isNotEmpty;
