import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../../domain/models/time_block.dart' as model;

/// Overridden in main() with the real instance before runApp.
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) => throw UnimplementedError('override in main'));

/// Persisted after the user completes onboarding; the splash screen routes on it.
const String kOnboardingCompletedKey = 'onboarding_completed';

final blockRepositoryProvider = Provider<BlockRepository>((ref) {
  try {
    return PrefsBlockRepository(ref.watch(sharedPreferencesProvider));
  } catch (_) {
    // Plugin unavailable on this platform/build — run in-memory for the session.
    return MemoryBlockRepository();
  }
});

abstract interface class BlockRepository {
  Stream<List<model.TimeBlock>> watchForDay(DateTime day);
  Stream<void> get changes;
  Future<model.TimeBlock?> getById(String id);
  Future<void> upsert(model.TimeBlock block);
  Future<void> softDelete(String id);
  Future<void> restore(String id);
  List<model.TimeBlock> getAll();
  void seedDemoData();
  Future<void> clearAll();
}

class MemoryBlockRepository implements BlockRepository {
  final Map<String, model.TimeBlock> blocks = {};
  final StreamController<void> _controller = StreamController<void>.broadcast();
  final _uuid = const Uuid();

  @override
  void seedDemoData() {
    if (blocks.isNotEmpty) return;
    final now = DateTime.now();
    final day = DateTime(now.year, now.month, now.day);
    void mk(String title, int sh, int sm, int eh, int em, String cat, {model.BlockStatus status = model.BlockStatus.planned, int tracked = 0}) {
      final start = day.add(Duration(hours: sh, minutes: sm)).toUtc();
      final end = day.add(Duration(hours: eh, minutes: em)).toUtc();
      final b = model.TimeBlock(
        id: _uuid.v4(),
        title: title,
        notes: null,
        startUtc: start,
        endUtc: end,
        timezone: now.timeZoneName,
        categoryId: cat,
        status: status,
        trackedSeconds: tracked,
        priority: 1,
        source: model.BlockSource.seed,
        createdAtUtc: DateTime.now().toUtc(),
        updatedAtUtc: DateTime.now().toUtc(),
      );
      blocks[b.id] = b;
    }

    mk('Morning review', 8, 30, 9, 0, 'admin');
    mk('Thesis draft', 9, 0, 11, 0, 'deep_work', status: model.BlockStatus.done, tracked: 4800);
    mk('Standup', 11, 0, 11, 30, 'meetings');
    mk('Reading: distributed systems', 13, 0, 14, 30, 'study');
    mk('Gym', 15, 0, 15, 45, 'health');
    mk('Email and invoices', 16, 0, 17, 0, 'admin');
    mk('Client call', 16, 30, 17, 15, 'meetings');
    _emit();
  }

  @override
  Future<void> clearAll() async {
    blocks.clear();
    _emit();
  }

  void _emit() => _controller.add(null);

  @override
  Stream<void> get changes => _controller.stream;

  @override
  List<model.TimeBlock> getAll() => blocks.values.where((b) => b.deletedAtUtc == null).toList();

  @override
  Stream<List<model.TimeBlock>> watchForDay(DateTime day) {
    late StreamController<List<model.TimeBlock>> out;
    StreamSubscription? sub;
    out = StreamController<List<model.TimeBlock>>(
      onListen: () {
        out.add(_filterDay(day));
        sub = _controller.stream.listen((_) => out.add(_filterDay(day)));
      },
      onCancel: () => sub?.cancel(),
    );
    return out.stream;
  }

  List<model.TimeBlock> _filterDay(DateTime day) {
    final result = getAll().where((b) {
      final local = b.startUtc.toLocal();
      return local.year == day.year && local.month == day.month && local.day == day.day;
    }).toList()
      ..sort((a, b) => a.startUtc.compareTo(b.startUtc));
    return result;
  }

  @override
  Future<model.TimeBlock?> getById(String id) async => blocks[id];

  @override
  Future<void> upsert(model.TimeBlock block) async {
    blocks[block.id] = block;
    _emit();
  }

  @override
  Future<void> softDelete(String id) async {
    final b = blocks[id];
    if (b != null) {
      blocks[id] = b.copyWith(deletedAtUtc: DateTime.now().toUtc());
      _emit();
    }
  }

  @override
  Future<void> restore(String id) async {
    final b = blocks[id];
    if (b != null) {
      blocks[id] = model.TimeBlock(
        id: b.id,
        title: b.title,
        notes: b.notes,
        startUtc: b.startUtc,
        endUtc: b.endUtc,
        timezone: b.timezone,
        categoryId: b.categoryId,
        status: b.status,
        trackedSeconds: b.trackedSeconds,
        priority: b.priority,
        source: b.source,
        createdAtUtc: b.createdAtUtc,
        updatedAtUtc: DateTime.now().toUtc(),
        deletedAtUtc: null,
        recurrenceRule: b.recurrenceRule,
      );
      _emit();
    }
  }
}

/// Persists every change to SharedPreferences as JSON. Loads synchronously
/// from the cached prefs instance at construction.
class PrefsBlockRepository implements BlockRepository {
  static const _key = 'lt.blocks.v1';

  final SharedPreferences _prefs;
  final MemoryBlockRepository _mem = MemoryBlockRepository();
  bool _loading = true;

  PrefsBlockRepository(this._prefs) {
    final raw = _prefs.getString(_key);
    if (raw != null) {
      try {
        final list = jsonDecode(raw) as List<dynamic>;
        for (final item in list) {
          final b = model.TimeBlock.fromJson(Map<String, dynamic>.from(item as Map));
          _mem.blocks[b.id] = b;
        }
      } catch (_) {
        // Corrupt store: start clean rather than crash.
      }
    }
    _loading = false;
    _mem.changes.listen((_) => _save());
  }

  void _save() {
    if (_loading) return;
    final json = jsonEncode(_mem.blocks.values.map((b) => b.toJson()).toList());
    _prefs.setString(_key, json);
  }

  @override
  Stream<List<model.TimeBlock>> watchForDay(DateTime day) => _mem.watchForDay(day);

  @override
  Stream<void> get changes => _mem.changes;

  @override
  Future<model.TimeBlock?> getById(String id) => _mem.getById(id);

  @override
  Future<void> upsert(model.TimeBlock block) => _mem.upsert(block);

  @override
  Future<void> softDelete(String id) => _mem.softDelete(id);

  @override
  Future<void> restore(String id) => _mem.restore(id);

  @override
  List<model.TimeBlock> getAll() => _mem.getAll();

  @override
  void seedDemoData() => _mem.seedDemoData();

  @override
  Future<void> clearAll() async {
    await _mem.clearAll();
    await _prefs.remove(_key);
  }
}
