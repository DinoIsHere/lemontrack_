import 'dart:convert';
import 'package:uuid/uuid.dart';
import '../models/time_block.dart';
import '../../data/repositories/block_repository.dart';
import '../scheduling/conflict.dart';
import '../scheduling/free_slot.dart';

class ChangeRow {
  final String label;
  final String before;
  final String after;
  const ChangeRow(this.label, this.before, this.after);
}

class ToolResult {
  final bool ok;
  final String tool;
  final String reply;
  final List<ChangeRow> changes;
  final List<String> conflicts;
  final String? actionLogId;
  final Object? data;

  const ToolResult({
    required this.ok,
    required this.tool,
    required this.reply,
    this.changes = const [],
    this.conflicts = const [],
    this.actionLogId,
    this.data,
  });

  factory ToolResult.error(String tool, String code, String message) =>
      ToolResult(ok: false, tool: tool, reply: '$code: $message');
}

class _UndoEntry {
  final String id;
  final Map<String, TimeBlock> snapshots;
  final List<String> createdIds;
  final List<String> restoredIds;
  _UndoEntry(this.id, this.snapshots, {List<String>? createdIds, List<String>? restoredIds})
      : createdIds = createdIds ?? const [],
        restoredIds = restoredIds ?? const [];
}

/// Executes typed intents against the BlockRepository. Same path used by chat,
/// the LLM tool layer, and (eventually) the UI.
class ToolExecutor {
  final BlockRepository repo;
  final _uuid = const Uuid();
  final List<_UndoEntry> _undoLog = [];

  ToolExecutor(this.repo);

  static String _hhmm(DateTime d) {
    final l = d.toLocal();
    return '${l.hour.toString().padLeft(2, '0')}:${l.minute.toString().padLeft(2, '0')}';
  }

  static String _dur(int minutes) {
    final h = minutes ~/ 60, m = minutes % 60;
    return h > 0 ? '${h}h ${m}m' : '${m}m';
  }

  List<TimeBlock> _dayBlocks([DateTime? day]) {
    day ??= DateTime.now();
    return repo.getAll().where((b) {
      final l = b.startUtc.toLocal();
      return l.year == day!.year && l.month == day.month && l.day == day.day;
    }).toList()..sort((a, b) => a.startUtc.compareTo(b.startUtc));
  }

  TimeBlock? _find(String query, [DateTime? day]) {
    final q = query.toLowerCase();
    final blocks = _dayBlocks(day);
    for (final b in blocks) {
      if (b.title.toLowerCase().contains(q)) return b;
    }
    for (final b in blocks) {
      final cat = b.categoryId.replaceAll('_', ' ');
      if (cat.contains(q)) return b;
    }
    return null;
  }

  DateTime _resolveDate(String? word) {
    final now = DateTime.now();
    if (word == null) return now;
    if (word.contains('tomorrow')) return now.add(const Duration(days: 1));
    return now;
  }

  Future<ToolResult> createBlock({
    required String title,
    required String time,
    int durationMinutes = 30,
    String category = 'deep_work',
    int priority = 1,
    String? notes,
    String? dayWord,
    DateTime? onDay,
  }) async {
    final day = onDay ?? _resolveDate(dayWord);
    final parts = time.split(':');
    if (parts.length != 2) return ToolResult.error('create_block', 'VALIDATION_FAILED', 'bad time $time');
    final start = DateTime(day.year, day.month, day.day, int.parse(parts[0]), int.parse(parts[1]));
    final now = DateTime.now().toUtc();
    final b = TimeBlock(
      id: _uuid.v4(),
      title: title,
      startUtc: start.toUtc(),
      endUtc: start.add(Duration(minutes: durationMinutes)).toUtc(),
      timezone: now.timeZoneName,
      categoryId: category,
      status: BlockStatus.planned,
      trackedSeconds: 0,
      priority: 1,
      source: BlockSource.user,
      createdAtUtc: now,
      updatedAtUtc: now,
    );
    await repo.upsert(b);
    final conf = findConflicts(b, _dayBlocks(start)).map((c) => c.blockB.title).toList();
    final entry = _UndoEntry(_uuid.v4(), {}, createdIds: [b.id]);
    _push(entry);
    return ToolResult(
      ok: true,
      tool: 'create_block',
      reply: 'Created ${b.title} at ${_hhmm(b.startUtc)} for ${_dur(durationMinutes)}${conf.isNotEmpty ? ' — ${conf.length} conflict(s)' : ''}.',
      changes: [ChangeRow('Created', '-', '${b.title} ${_hhmm(b.startUtc)}-${_hhmm(b.endUtc)}')],
      conflicts: conf,
      actionLogId: entry.id,
    );
  }

  Future<ToolResult> moveBlock(String query, String time, {String? dayWord}) async {
    final b = _find(query, _resolveDate(dayWord));
    if (b == null) return ToolResult.error('move_block', 'BLOCK_NOT_FOUND', 'No block matching "$query".');
    final parts = time.split(':');
    final dur = b.endUtc.difference(b.startUtc);
    final local = b.startUtc.toLocal();
    final newStart = DateTime(local.year, local.month, local.day, int.parse(parts[0]), int.parse(parts[1]));
    final before = b;
    final moved = b.copyWith(startUtc: newStart.toUtc(), endUtc: newStart.add(dur).toUtc());
    await repo.upsert(moved);
    final conf = findConflicts(moved, _dayBlocks(newStart)).map((c) => c.blockB.title).toList();
    final entry = _UndoEntry(_uuid.v4(), {b.id: before});
    _push(entry);
    return ToolResult(
      ok: true,
      tool: 'move_block',
      reply: 'Moved ${b.title} to ${_hhmm(moved.startUtc)}${conf.isNotEmpty ? ' — conflicts with ${conf.join(", ")}' : ''}.',
      changes: [ChangeRow('Moved', '${_hhmm(before.startUtc)}-${_hhmm(before.endUtc)}', '${_hhmm(moved.startUtc)}-${_hhmm(moved.endUtc)}')],
      conflicts: conf,
      actionLogId: entry.id,
    );
  }

  Future<ToolResult> shiftAfter(String time, int deltaMinutes, {String? excludeCategory}) async {
    final now = DateTime.now();
    final parts = time.split(':');
    final from = DateTime(now.year, now.month, now.day, int.parse(parts[0]), int.parse(parts[1]));
    final affected = _dayBlocks().where((b) => !b.startUtc.toLocal().isBefore(from)).where((b) => excludeCategory == null || b.categoryId != excludeCategory).toList();
    if (affected.isEmpty) return ToolResult.error('shift_following', 'VALIDATION_FAILED', 'No blocks at or after $time.');
    final snaps = {for (final b in affected) b.id: b};
    for (final b in affected) {
      await repo.upsert(b.copyWith(
        startUtc: b.startUtc.add(Duration(minutes: deltaMinutes)),
        endUtc: b.endUtc.add(Duration(minutes: deltaMinutes)),
      ));
    }
    final entry = _UndoEntry(_uuid.v4(), snaps);
    _push(entry);
    return ToolResult(
      ok: true,
      tool: 'shift_following',
      reply: 'Shifted ${affected.length} blocks by $deltaMinutes min.',
      changes: affected.map((b) => ChangeRow(b.title, _hhmm(b.startUtc), _hhmm(b.startUtc.add(Duration(minutes: deltaMinutes))))).toList(),
      actionLogId: entry.id,
    );
  }

  Future<ToolResult> completeBlock(String query) async {
    final b = _find(query);
    if (b == null) return ToolResult.error('complete_block', 'BLOCK_NOT_FOUND', 'No block matching "$query".');
    await repo.upsert(b.copyWith(status: BlockStatus.done, trackedSeconds: b.trackedSeconds > 0 ? b.trackedSeconds : b.plannedSeconds));
    final entry = _UndoEntry(_uuid.v4(), {b.id: b});
    _push(entry);
    return ToolResult(
      ok: true,
      tool: 'complete_block',
      reply: 'Marked ${b.title} done.',
      changes: [ChangeRow(b.title, 'planned', 'done')],
      actionLogId: entry.id,
    );
  }

  Future<ToolResult> deleteBlock(String query) async {
    final b = _find(query);
    if (b == null) return ToolResult.error('delete_block', 'BLOCK_NOT_FOUND', 'No block matching "$query".');
    await repo.softDelete(b.id);
    final entry = _UndoEntry(_uuid.v4(), {}, restoredIds: [b.id]);
    _push(entry);
    return ToolResult(
      ok: true,
      tool: 'delete_block',
      reply: 'Deleted ${b.title}.',
      changes: [ChangeRow(b.title, '${_hhmm(b.startUtc)}-${_hhmm(b.endUtc)}', 'deleted')],
      actionLogId: entry.id,
    );
  }

  Future<ToolResult> findFreeSlot(int minutes, {String? dayWord, String? earliest}) async {
    final day = _resolveDate(dayWord);
    final slots = findFreeSlots(repo.getAll(), day);
    final eh = earliest != null ? int.tryParse(earliest.split(':').first) : null;
    FreeSlot? found;
    for (final s in slots) {
      if (s.durationMinutes < minutes) continue;
      if (eh != null && s.start.hour < eh) continue;
      found = s;
      break;
    }
    if (found == null) {
      return ToolResult(
        ok: true,
        tool: 'find_free_slot',
        reply: 'No free ${minutes}m window${dayWord == 'tomorrow' ? ' tomorrow' : ' today'} inside workday hours.',
      );
    }
    return ToolResult(
      ok: true,
      tool: 'find_free_slot',
      reply: 'Free slot: ${_hhmm(found.start)}-${_hhmm(found.end)} (${found.durationMinutes >= 60 ? _dur(found.durationMinutes) : '${found.durationMinutes}m'} available).',
      data: {'start': _hhmm(found.start), 'minutes': found.durationMinutes, 'dayWord': dayWord},
    );
  }

  ToolResult listToday() {
    final bs = _dayBlocks();
    if (bs.isEmpty) return ToolResult(ok: true, tool: 'get_day', reply: 'Nothing planned today.');
    final now = DateTime.now();
    final lines = bs.map((b) {
      final left = b.status == BlockStatus.done ? '✓' : (b.endUtc.isBefore(now.toUtc()) ? '·' : '');
      return '${_hhmm(b.startUtc)} ${b.title} (${_dur(b.endUtc.difference(b.startUtc).inMinutes)}) $left';
    }).join('\n');
    return ToolResult(ok: true, tool: 'get_day', reply: lines);
  }

  ToolResult summarizeDay() {
    final bs = _dayBlocks();
    final planned = bs.fold<int>(0, (a, b) => a + b.endUtc.difference(b.startUtc).inMinutes);
    final tracked = bs.fold<int>(0, (a, b) => a + b.trackedSeconds ~/ 60);
    final done = bs.where((b) => b.status == BlockStatus.done).length;
    final conflicts = bs.expand((b) => findConflicts(b, bs)).length ~/ 2;
    return ToolResult(
      ok: true,
      tool: 'summarize_day',
      reply: 'Blocks: ${bs.length} | Planned ${_dur(planned)} | Tracked ${_dur(tracked)} | Done $done/${bs.length}'
          '${conflicts > 0 ? ' | $conflicts conflict pair(s)' : ''}',
    );
  }

  void _push(_UndoEntry e) {
    _undoLog.insert(0, e);
    if (_undoLog.length > 50) _undoLog.removeLast();
  }

  Future<ToolResult> undo(String actionLogId) async {
    final idx = _undoLog.indexWhere((e) => e.id == actionLogId);
    if (idx < 0) return ToolResult.error('undo', 'VALIDATION_FAILED', 'Nothing to undo.');
    final e = _undoLog.removeAt(idx);
    for (final snap in e.snapshots.values) {
      await repo.upsert(snap);
    }
    for (final id in e.createdIds) {
      await repo.softDelete(id);
    }
    for (final id in e.restoredIds) {
      await repo.restore(id);
    }
    return ToolResult(ok: true, tool: 'undo', reply: 'Undone.');
  }

  /// Rule-based natural language fallback. Returns null when no intent matched.
  Future<ToolResult?> handleNaturalLanguage(String raw) async {
    final m = raw.toLowerCase().trim();

    var match = RegExp(r'^create (.+?) at (\d{1,2}:\d{2})(?: for (\d+) ?m(?:in)?)?(?: (?:as|in) (\w+))?( tomorrow)?$').firstMatch(m);
    match ??= RegExp(r'^(?:add|schedule) (.+?) at (\d{1,2}:\d{2})(?: for (\d+) ?m(?:in)?)?(?: (?:as|in) (\w+))?( tomorrow)?$').firstMatch(m);
    if (match != null) {
      final time = _normalizeTime(match.group(2)!);
      final dur = match.group(3) != null ? int.parse(match.group(3)!) : 30;
      final cat = _categoryFrom(match.group(4) ?? match.group(1));
      return createBlock(title: _titleCase(match.group(1)!), time: time, durationMinutes: dur, category: cat, dayWord: match.group(5));
    }

    match = RegExp(r'^(?:create|add|schedule) (?:a |an |some )?(.+?) (\d{1,2}:\d{2})[–-](\d{1,2}:\d{2})(?: (.+))?').firstMatch(m);
    if (match != null) {
      final start = _normalizeTime(match.group(2)!);
      final end = _normalizeTime(match.group(3)!);
      final mins = _mins(end) - _mins(start);
      if (mins <= 0) return ToolResult.error('create_block', 'VALIDATION_FAILED', 'end before start');
      final cat = _categoryFrom(match.group(4));
      return createBlock(title: _titleCase(match.group(1)!), time: start, durationMinutes: mins, category: cat);
    }

    match = RegExp(r'^move (.+?) to (\d{1,2}:\d{2})$').firstMatch(m);
    if (match != null) {
      return moveBlock(match.group(1)!, _normalizeTime(match.group(2)!));
    }

    match = RegExp(r'(?:move|shift|push) (?:my |the )?(?:afternoon|evening|morning|\d{1,2}:\d{2})? ?(?:back|later|by) (\d+) ?m?i?n?').firstMatch(m);
    if (match != null && (m.contains('afternoon') || m.contains('evening') || m.contains('morning') || RegExp(r'\d{1,2}:\d{2}').hasMatch(m))) {
      final delta = int.parse(match.group(1)!);
      final timeMatch = RegExp(r'(\d{1,2}:\d{2})').firstMatch(m);
      final from = timeMatch?.group(1) ?? (m.contains('morning') ? '09:00' : (m.contains('evening') ? '17:00' : '12:00'));
      final sign = (m.contains('earlier') || m.contains('back') && m.contains('forward')) ? -1 : 1;
      return shiftAfter(_normalizeTime(from), sign * delta);
    }
    match = RegExp(r'(?:move|shift|push) (?:my |the )?(afternoon|everything|blocks?) (?:from (\d{1,2}:\d{2}) )?(earlier|forward|up) (\d+) ?m?i?n?').firstMatch(m);
    if (match != null) {
      final from = match.group(2) ?? '12:00';
      return shiftAfter(_normalizeTime(from), -int.parse(match.group(4)!));
    }

    match = RegExp(r'^(?:complete|done|finish|mark) (.+?)(?: as done| done)?$').firstMatch(m);
    if (match != null) return completeBlock(match.group(1)!);

    match = RegExp(r'^(?:delete|remove|cancel) (.+)$').firstMatch(m);
    if (match != null) return deleteBlock(match.group(1)!);

    match = RegExp(r'find (?:me )?(\d+) ?m(?:in)?(?: (?:tomorrow|slot|time))?').firstMatch(m);
    if (match != null) {
      final day = m.contains('tomorrow') ? 'tomorrow' : null;
      return findFreeSlot(int.parse(match.group(1)!), dayWord: day);
    }

    if (RegExp(r"(what'?s left|what.*left|list (my )?(blocks|day|today)|show.*(today|day))").hasMatch(m)) {
      return listToday();
    }
    if (RegExp(r'(summar|how did|review my day)').hasMatch(m)) {
      return summarizeDay();
    }
    return null;
  }

  static int _mins(String hhmm) {
    final p = hhmm.split(':');
    return int.parse(p[0]) * 60 + int.parse(p[1]);
  }

  static (DateTime day, String hhmm) _splitIso(String iso) {
    final l = DateTime.parse(iso).toLocal();
    return (DateTime(l.year, l.month, l.day), '${l.hour.toString().padLeft(2, '0')}:${l.minute.toString().padLeft(2, '0')}');
  }

  Map<String, dynamic> _blockJson(TimeBlock b) => {
        'id': b.id,
        'title': b.title,
        'start': b.startUtc.toLocal().toIso8601String(),
        'end': b.endUtc.toLocal().toIso8601String(),
        'category': b.categoryId,
        'status': b.status.name,
        'tracked_seconds': b.trackedSeconds,
      };

  Future<ToolResult> moveById(String blockId, String newStartIso) async {
    final b = await repo.getById(blockId);
    if (b == null) return ToolResult.error('move_block', 'BLOCK_NOT_FOUND', 'No block with id $blockId.');
    final (day, hhmm) = _splitIso(newStartIso);
    final dur = b.endUtc.difference(b.startUtc);
    final p = hhmm.split(':');
    final newStart = DateTime(day.year, day.month, day.day, int.parse(p[0]), int.parse(p[1]));
    final moved = b.copyWith(startUtc: newStart.toUtc(), endUtc: newStart.toUtc().add(dur));
    await repo.upsert(moved);
    final conf = findConflicts(moved, repo.getAll()).map((c) => c.blockB.title).toList();
    final entry = _UndoEntry(_uuid.v4(), {b.id: b});
    _push(entry);
    return ToolResult(
      ok: true,
      tool: 'move_block',
      reply: 'Moved ${b.title} to $hhmm.',
      changes: [ChangeRow(b.title, _hhmm(b.startUtc), _hhmm(moved.startUtc))],
      conflicts: conf,
      actionLogId: entry.id,
    );
  }

  Future<ToolResult> updateById(String blockId, {String? title, String? startIso, int? durationMinutes, String? category, int? priority, String? notes}) async {
    final b = await repo.getById(blockId);
    if (b == null) return ToolResult.error('update_block', 'BLOCK_NOT_FOUND', 'No block with id $blockId.');
    var nb = b;
    if (title != null && title.trim().isNotEmpty) nb = nb.copyWith(title: title.trim());
    if (category != null) nb = nb.copyWith(categoryId: category);
    if (priority != null) nb = nb.copyWith(priority: priority);
    if (notes != null) nb = nb.copyWith(notes: notes);
    if (startIso != null) {
      final (day, hhmm) = _splitIso(startIso);
      final p = hhmm.split(':');
      final start = DateTime(day.year, day.month, day.day, int.parse(p[0]), int.parse(p[1])).toUtc();
      final dur = durationMinutes != null ? Duration(minutes: durationMinutes) : nb.duration;
      nb = nb.copyWith(startUtc: start, endUtc: start.add(dur));
    } else if (durationMinutes != null) {
      nb = nb.copyWith(endUtc: nb.startUtc.add(Duration(minutes: durationMinutes)));
    }
    await repo.upsert(nb);
    final entry = _UndoEntry(_uuid.v4(), {b.id: b});
    _push(entry);
    return ToolResult(
      ok: true,
      tool: 'update_block',
      reply: 'Updated ${nb.title}.',
      changes: [ChangeRow(nb.title, '${_hhmm(b.startUtc)}-${_hhmm(b.endUtc)}', '${_hhmm(nb.startUtc)}-${_hhmm(nb.endUtc)}')],
      actionLogId: entry.id,
    );
  }

  Future<ToolResult> completeById(String blockId, {int? trackedMinutes}) async {
    final b = await repo.getById(blockId);
    if (b == null) return ToolResult.error('complete_block', 'BLOCK_NOT_FOUND', 'No block with id $blockId.');
    await repo.upsert(b.copyWith(
      status: BlockStatus.done,
      trackedSeconds: trackedMinutes != null ? trackedMinutes * 60 : (b.trackedSeconds > 0 ? b.trackedSeconds : b.plannedSeconds),
    ));
    final entry = _UndoEntry(_uuid.v4(), {b.id: b});
    _push(entry);
    return ToolResult(ok: true, tool: 'complete_block', reply: 'Marked ${b.title} done.', changes: [ChangeRow(b.title, b.status.name, 'done')], actionLogId: entry.id);
  }

  Future<ToolResult> deleteById(String blockId) async {
    final b = await repo.getById(blockId);
    if (b == null) return ToolResult.error('delete_block', 'BLOCK_NOT_FOUND', 'No block with id $blockId.');
    await repo.softDelete(b.id);
    final entry = _UndoEntry(_uuid.v4(), {}, restoredIds: [b.id]);
    _push(entry);
    return ToolResult(ok: true, tool: 'delete_block', reply: 'Deleted ${b.title}.', changes: [ChangeRow(b.title, '${_hhmm(b.startUtc)}-${_hhmm(b.endUtc)}', 'deleted')], actionLogId: entry.id);
  }

  Future<ToolResult> shiftFromIso(String fromIso, int deltaMinutes, {String? excludeCategory}) async {
    final from = DateTime.parse(fromIso).toLocal();
    final affected = repo.getAll().where((b) {
      final l = b.startUtc.toLocal();
      return l.year == from.year && l.month == from.month && l.day == from.day && !l.isBefore(from);
    }).where((b) => excludeCategory == null || b.categoryId != excludeCategory).toList();
    if (affected.isEmpty) return ToolResult.error('shift_following', 'VALIDATION_FAILED', 'No blocks at or after $fromIso.');
    final snaps = {for (final b in affected) b.id: b};
    for (final b in affected) {
      await repo.upsert(b.copyWith(
        startUtc: b.startUtc.add(Duration(minutes: deltaMinutes)),
        endUtc: b.endUtc.add(Duration(minutes: deltaMinutes)),
      ));
    }
    final entry = _UndoEntry(_uuid.v4(), snaps);
    _push(entry);
    return ToolResult(
      ok: true,
      tool: 'shift_following',
      reply: 'Shifted ${affected.length} blocks by $deltaMinutes min.',
      changes: affected.map((b) => ChangeRow(b.title, _hhmm(b.startUtc), _hhmm(b.startUtc.add(Duration(minutes: deltaMinutes))))).toList(),
      actionLogId: entry.id,
    );
  }

  /// Executes a typed tool call from the LLM. Never touches the DB directly.
  Future<ToolResult> executeTool(String name, Map<String, dynamic> args) async {
    try {
      switch (name) {
        case 'get_day':
          final d = DateTime.parse('${args['date']}T12:00:00');
          final bs = _dayBlocks(d);
          return ToolResult(ok: true, tool: name, reply: jsonEncode(bs.map(_blockJson).toList()), data: bs.map(_blockJson).toList());
        case 'get_range':
          final s = DateTime.parse(args['start'] as String);
          final e = DateTime.parse(args['end'] as String);
          final bs = repo.getAll().where((b) => b.startUtc.isBefore(e.toUtc()) && s.toUtc().isBefore(b.endUtc)).toList();
          return ToolResult(ok: true, tool: name, reply: jsonEncode(bs.map(_blockJson).toList()), data: bs.map(_blockJson).toList());
        case 'find_free_slot':
          final day = DateTime.parse('${args['date']}T12:00:00');
          final need = (args['duration_minutes'] as num).toInt();
          final earliest = args['earliest'] as String?;
          final ignoreWorkday = args['ignore_workday'] == true;
          final slots = findFreeSlots(repo.getAll(), day, workStart: ignoreWorkday ? 0 : 9, workEnd: ignoreWorkday ? 23 : 18);
          final eh = earliest != null ? int.tryParse(earliest.split(':').first) : null;
          FreeSlot? found;
          for (final s in slots) {
            if (s.durationMinutes < need) continue;
            if (eh != null && s.start.hour < eh) continue;
            found = s;
            break;
          }
          if (found == null) {
            return ToolResult(ok: false, tool: name, reply: jsonEncode({'error': {'code': 'NO_FREE_SLOT', 'message': 'No free window of $need min.'}}));
          }
          return ToolResult(
            ok: true,
            tool: name,
            reply: jsonEncode({'start': found.start.toIso8601String(), 'end': found.end.toIso8601String()}),
            data: {'start': found.start.toIso8601String(), 'end': found.end.toIso8601String()},
          );
        case 'create_block':
          final (day, hhmm) = _splitIso(args['start'] as String);
          return createBlock(
            title: args['title'] as String,
            time: hhmm,
            durationMinutes: (args['duration_minutes'] as num?)?.toInt() ?? 30,
            category: (args['category'] as String?) ?? 'deep_work',
            priority: (args['priority'] as num?)?.toInt() ?? 1,
            notes: args['notes'] as String?,
            onDay: day,
          );
        case 'update_block':
          return updateById(
            args['block_id'] as String,
            title: args['title'] as String?,
            startIso: args['start'] as String?,
            durationMinutes: (args['duration_minutes'] as num?)?.toInt(),
            category: args['category'] as String?,
            priority: (args['priority'] as num?)?.toInt(),
            notes: args['notes'] as String?,
          );
        case 'move_block':
          return moveById(args['block_id'] as String, args['new_start'] as String);
        case 'shift_following':
          return shiftFromIso(
            args['from'] as String,
            (args['delta_minutes'] as num).toInt(),
            excludeCategory: args['exclude_category'] as String?,
          );
        case 'complete_block':
          return completeById(
            args['block_id'] as String,
            trackedMinutes: (args['tracked_minutes'] as num?)?.toInt(),
          );
        case 'delete_block':
          return deleteById(args['block_id'] as String);
        case 'summarize_day':
          final d = DateTime.parse('${args['date']}T12:00:00');
          final bs = _dayBlocks(d);
          final planned = bs.fold<int>(0, (a, b) => a + b.endUtc.difference(b.startUtc).inMinutes);
          final tracked = bs.fold<int>(0, (a, b) => a + b.trackedSeconds ~/ 60);
          final done = bs.where((b) => b.status == BlockStatus.done).length;
          final byCat = <String, int>{};
          for (final b in bs) {
            byCat[b.categoryId] = (byCat[b.categoryId] ?? 0) + b.endUtc.difference(b.startUtc).inMinutes;
          }
          final conflictSet = bs
              .expand((b) => findConflicts(b, bs).map((c) => {'block_a': c.blockA.id, 'block_b': c.blockB.id, 'overlap_minutes': c.overlapMinutes}).toSet())
              .toList();
          return ToolResult(
            ok: true,
            tool: name,
            reply: jsonEncode({
              'planned_minutes': planned,
              'tracked_minutes': tracked,
              'done': done,
              'total': bs.length,
              'by_category': byCat,
              'conflicts': conflictSet,
            }),
          );
        default:
          return ToolResult.error(name, 'VALIDATION_FAILED', 'Unknown tool "$name".');
      }
    } catch (e) {
      return ToolResult.error(name, 'INTERNAL', '$e');
    }
  }

  static String _normalizeTime(String t) {
    final p = t.split(':');
    return '${int.parse(p[0]).toString().padLeft(2, '0')}:${p[1]}';
  }

  static const _cats = ['deep_work', 'meetings', 'study', 'health', 'admin', 'personal'];

  static String _categoryFrom(String? raw) {
    if (raw == null) return 'deep_work';
    final r = raw.trim().toLowerCase();
    for (final c in _cats) {
      if (c == r || c.replaceAll('_', ' ') == r || r.contains(c.replaceAll('_', ''))) return c;
    }
    if (r.contains('meeting') || r.contains('call')) return 'meetings';
    if (r.contains('study') || r.contains('read')) return 'study';
    if (r.contains('gym') || r.contains('health') || r.contains('run')) return 'health';
    if (r.contains('admin') || r.contains('email') || r.contains('invoice')) return 'admin';
    if (r.contains('personal') || r.contains('friend') || r.contains('family')) return 'personal';
    if (r.contains('deep') || r.contains('work') || r.contains('thesis')) return 'deep_work';
    return 'deep_work';
  }

  static String _titleCase(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1);
  }

  static Map<String, dynamic> envelope(ToolResult r) => {
        'ok': r.ok,
        'tool': r.tool,
        if (!r.ok) 'error': r.reply,
        'changes': r.changes.map((c) => {'label': c.label, 'before': c.before, 'after': c.after}).toList(),
        'conflicts': r.conflicts,
        'action_log_id': r.actionLogId,
      };
}
