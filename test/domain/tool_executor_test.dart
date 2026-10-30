import 'package:flutter_test/flutter_test.dart';
import 'package:lemontrack_/data/repositories/block_repository.dart';
import 'package:lemontrack_/domain/ai/tool_executor.dart';
import 'package:lemontrack_/domain/models/time_block.dart';

void main() {
  late MemoryBlockRepository repo;
  late ToolExecutor exec;

  setUp(() {
    repo = MemoryBlockRepository();
    repo.seedDemoData();
    exec = ToolExecutor(repo);
  });

  test('create via natural language adds a real block', () async {
    final r = await exec.handleNaturalLanguage('create gym at 18:00 for 45 min');
    expect(r, isNotNull);
    expect(r!.ok, isTrue);
    final found = repo.getAll().where((b) => b.title.toLowerCase().contains('gym'));
    expect(found.length, 2); // seed gym + new one
    final created = found.last;
    expect(created.duration.inMinutes, 45);
    expect(created.categoryId, 'health');
  });

  test('move shifts the block and keeps duration', () async {
    await exec.handleNaturalLanguage('move standup to 11:30');
    final b = repo.getAll().firstWhere((b) => b.title == 'Standup');
    final local = b.startUtc.toLocal();
    expect(local.hour, 11);
    expect(local.minute, 30);
    expect(b.duration.inMinutes, 30);
  });

  test('shift afternoon moves blocks after noon', () async {
    final before = repo.getAll().where((b) => b.startUtc.toLocal().hour >= 12).toList();
    final r = await exec.handleNaturalLanguage('shift afternoon back 30 min');
    expect(r!.ok, isTrue);
    for (final b in before) {
      final now = repo.getAll().firstWhere((x) => x.id == b.id);
      expect(now.startUtc, b.startUtc.add(const Duration(minutes: 30)));
    }
  });

  test('undo of create removes the block', () async {
    final r = await exec.handleNaturalLanguage('create yoga at 07:00 for 30 min');
    final id = r!.actionLogId!;
    expect(repo.getAll().any((b) => b.title == 'Yoga'), isTrue);
    await exec.undo(id);
    expect(repo.getAll().any((b) => b.title == 'Yoga'), isFalse);
  });

  test('undo of delete restores the block', () async {
    final r = await exec.handleNaturalLanguage('delete gym');
    expect(repo.getAll().any((b) => b.title == 'Gym'), isFalse);
    await exec.undo(r!.actionLogId!);
    expect(repo.getAll().any((b) => b.title == 'Gym'), isTrue);
  });

  test('seed data contains a demo conflict', () {
    final bs = repo.getAll();
    final email = bs.firstWhere((b) => b.title == 'Email and invoices');
    final conflicts = findConflictsFor(email, bs);
    expect(conflicts, isNotEmpty);
  });

  test('find free slot reports a window', () async {
    final r = await exec.handleNaturalLanguage('find 30 min');
    expect(r!.ok, isTrue);
    expect(r.reply, contains('Free slot'));
  });

  test('summarize counts blocks', () async {
    final r = await exec.handleNaturalLanguage('summarize my day');
    expect(r!.reply, contains('Blocks:'));
  });
}

List<Conflict> findConflictsFor(TimeBlock b, List<TimeBlock> all) {
  return all
      .where((o) => o.id != b.id && b.startUtc.isBefore(o.endUtc) && o.startUtc.isBefore(b.endUtc))
      .map((o) => Conflict(b, o))
      .toList();
}

class Conflict {
  final TimeBlock a;
  final TimeBlock b;
  Conflict(this.a, this.b);
}
