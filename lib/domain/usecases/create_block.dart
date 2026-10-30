import 'package:uuid/uuid.dart';
import '../models/time_block.dart';
import '../../data/repositories/block_repository.dart';

class CreateBlockUseCase {
  final BlockRepository repo;
  final _uuid = const Uuid();

  CreateBlockUseCase(this.repo);

  Future<TimeBlock> execute({
    required String title,
    required DateTime startLocal,
    required int durationMinutes,
    required String categoryId,
    int priority = 1,
    String? notes,
  }) async {
    final now = DateTime.now().toUtc();
    final startUtc = startLocal.toUtc();
    final endUtc = startUtc.add(Duration(minutes: durationMinutes));
    final block = TimeBlock(
      id: _uuid.v4(),
      title: title.trim(),
      notes: notes,
      startUtc: startUtc,
      endUtc: endUtc,
      timezone: DateTime.now().timeZoneName,
      categoryId: categoryId,
      status: BlockStatus.planned,
      trackedSeconds: 0,
      priority: priority,
      source: BlockSource.user,
      createdAtUtc: now,
      updatedAtUtc: now,
    );
    await repo.upsert(block);
    return block;
  }
}
