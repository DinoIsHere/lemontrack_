import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../../data/repositories/block_repository.dart';
import '../../domain/models/time_block.dart';
import '../../theme/lt_colors.dart';

class BlockEditorScreen extends ConsumerStatefulWidget {
  final String? id;
  const BlockEditorScreen({super.key, this.id});

  @override
  ConsumerState<BlockEditorScreen> createState() => _BlockEditorScreenState();
}

class _BlockEditorScreenState extends ConsumerState<BlockEditorScreen> {
  final _titleCtrl = TextEditingController();
  final _startCtrl = TextEditingController(text: '09:00');
  final _durCtrl = TextEditingController(text: '30');
  String _category = 'deep_work';
  TimeBlock? _existing;

  @override
  void initState() {
    super.initState();
    if (widget.id != null) {
      _loadBlock();
    }
  }

  void _loadBlock() async {
    final repo = ref.read(blockRepositoryProvider);
    final block = await repo.getById(widget.id!);
    if (block != null) {
      setState(() {
        _existing = block;
        _titleCtrl.text = block.title;
        final local = block.startUtc.toLocal();
        _startCtrl.text = '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
        _durCtrl.text = block.endUtc.difference(block.startUtc).inMinutes.toString();
        _category = block.categoryId;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cats = ['deep_work', 'meetings', 'study', 'health', 'admin', 'personal'];
    return Scaffold(
      appBar: AppBar(backgroundColor: LTColors.ink, title: Text(widget.id == null ? 'New block' : 'Edit block')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(controller: _titleCtrl, decoration: const InputDecoration(labelText: 'Title')),
            const SizedBox(height: 16),
            TextField(controller: _startCtrl, decoration: const InputDecoration(labelText: 'Start (HH:MM)')),
            const SizedBox(height: 16),
            TextField(controller: _durCtrl, decoration: const InputDecoration(labelText: 'Duration (min)'), keyboardType: TextInputType.number),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              children: cats.map((c) {
                final selected = _category == c;
                return ChoiceChip(
                  label: Text(c.replaceAll('_', ' ')),
                  selected: selected,
                  onSelected: (_) => setState(() => _category = c),
                  selectedColor: LTColors.lemonDeep,
                );
              }).toList(),
            ),
            const Spacer(),
            if (_existing != null)
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.timer, size: 16),
                  label: const Text('Start focus'),
                  onPressed: () => context.push('/focus/${_existing!.id}'),
                ),
              ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (_existing != null)
                  OutlinedButton(
                    onPressed: () async {
                      final repo = ref.read(blockRepositoryProvider);
                      await repo.softDelete(_existing!.id);
                      if (mounted) Navigator.pop(context);
                    },
                    child: const Text('Delete'),
                  ),
                const SizedBox(width: 8),
                OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                const SizedBox(width: 8),
                FilledButton(onPressed: _save, child: const Text('Save')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _save() async {
    final repo = ref.read(blockRepositoryProvider);
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) return;
    final parts = _startCtrl.text.split(':');
    final hour = int.parse(parts[0]);
    final min = int.parse(parts[1]);
    final dur = int.parse(_durCtrl.text);
    final now = DateTime.now();
    final startLocal = DateTime(now.year, now.month, now.day, hour, min);
    final startUtc = startLocal.toUtc();
    final endUtc = startUtc.add(Duration(minutes: dur));
    
    if (_existing != null) {
      final updated = _existing!.copyWith(title: title, startUtc: startUtc, endUtc: endUtc, categoryId: _category);
      await repo.upsert(updated);
    } else {
      final block = TimeBlock(
        id: const Uuid().v4(),
        title: title,
        notes: null,
        startUtc: startUtc,
        endUtc: endUtc,
        timezone: now.timeZoneName,
        categoryId: _category,
        status: BlockStatus.planned,
        trackedSeconds: 0,
        priority: 1,
        source: BlockSource.user,
        createdAtUtc: DateTime.now().toUtc(),
        updatedAtUtc: DateTime.now().toUtc(),
      );
      await repo.upsert(block);
    }
    if (mounted) Navigator.pop(context);
  }
}
