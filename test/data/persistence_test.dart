import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lemontrack_/data/repositories/block_repository.dart';
import 'package:lemontrack_/domain/models/time_block.dart';

TimeBlock makeBlock(String title, int hour) {
  final day = DateTime(2026, 10, 30);
  final now = DateTime.utc(2026, 10, 29);
  return TimeBlock(
    id: 'id-$title',
    title: title,
    startUtc: day.add(Duration(hours: hour)).toUtc(),
    endUtc: day.add(Duration(hours: hour + 1)).toUtc(),
    timezone: 'TEST',
    categoryId: 'deep_work',
    status: BlockStatus.planned,
    trackedSeconds: 0,
    priority: 1,
    source: BlockSource.user,
    createdAtUtc: now,
    updatedAtUtc: now,
  );
}

void main() {
  test('fresh install starts empty — no fake data', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final repo = PrefsBlockRepository(prefs);
    expect(repo.getAll(), isEmpty);
  });

  test('blocks persist across repository instances', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final repo = PrefsBlockRepository(prefs);
    await repo.upsert(makeBlock('Real work', 9));
    await repo.upsert(makeBlock('Lunch', 12));

    // New instance reads the same store.
    final repo2 = PrefsBlockRepository(prefs);
    final titles = repo2.getAll().map((b) => b.title).toSet();
    expect(titles, containsAll(['Real work', 'Lunch']));
  });

  test('deletes persist too (soft delete survives reload)', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final repo = PrefsBlockRepository(prefs);
    await repo.upsert(makeBlock('Gone soon', 14));
    await repo.softDelete('id-Gone soon');

    final repo2 = PrefsBlockRepository(prefs);
    expect(repo2.getAll().where((b) => b.title == 'Gone soon'), isEmpty);
    // But the row still exists for undo/restore.
    expect(await repo2.getById('id-Gone soon'), isNotNull);
    await repo2.restore('id-Gone soon');
    expect(repo2.getAll().where((b) => b.title == 'Gone soon'), isNotEmpty);
  });

  test('clearAll wipes the store', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final repo = PrefsBlockRepository(prefs);
    await repo.upsert(makeBlock('Temp', 10));
    await repo.clearAll();

    final repo2 = PrefsBlockRepository(prefs);
    expect(repo2.getAll(), isEmpty);
  });

  test('seedDemoData is opt-in only', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final repo = PrefsBlockRepository(prefs);
    expect(repo.getAll(), isEmpty);
    repo.seedDemoData();
    expect(repo.getAll(), isNotEmpty);
  });
}
