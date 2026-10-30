import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../data/repositories/block_repository.dart';
import '../../theme/lt_colors.dart';
import '../../widgets/crypto/ticker_strip.dart';
import '../../widgets/crypto/day_timeline.dart';
import '../../domain/models/time_block.dart';

/// Day currently shown on the Today screen.
final selectedDayProvider = StateProvider<DateTime>((ref) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
});

class TodayScreen extends ConsumerWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final selected = ref.watch(selectedDayProvider);
    final blocksAsync = ref.watch(blocksForDayProvider(selected));
    final isToday = selected.year == today.year && selected.month == today.month && selected.day == today.day;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: LTColors.ink,
        titleSpacing: 0,
        title: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left, color: LTColors.ash),
              tooltip: 'Previous day',
              onPressed: () => ref.read(selectedDayProvider.notifier).state = selected.subtract(const Duration(days: 1)),
            ),
            GestureDetector(
              onTap: () => ref.read(selectedDayProvider.notifier).state = today,
              child: Text(
                isToday ? '${_weekday(selected)} ${selected.day}' : '${_weekday(selected)} ${selected.day}/${selected.month}',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
            ),
            if (!isToday)
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: TextButton(
                  onPressed: () => ref.read(selectedDayProvider.notifier).state = today,
                  child: const Text('TODAY', style: TextStyle(fontSize: 10, letterSpacing: 0.8, color: LTColors.lemon)),
                ),
              ),
            IconButton(
              icon: const Icon(Icons.chevron_right, color: LTColors.ash),
              tooltip: 'Next day',
              onPressed: () => ref.read(selectedDayProvider.notifier).state = selected.add(const Duration(days: 1)),
            ),
          ],
        ),
        actions: [
          IconButton(icon: const Icon(Icons.settings), onPressed: () => context.push('/settings')),
        ],
      ),
      body: Column(
        children: [
          blocksAsync.when(
            data: (blocks) {
              final planned = blocks.fold<int>(0, (sum, b) => sum + b.endUtc.difference(b.startUtc).inMinutes);
              final tracked = blocks.fold<int>(0, (sum, b) => sum + b.trackedSeconds ~/ 60);
              final done = blocks.where((b) => b.status == BlockStatus.done).length;
              final focus = planned > 0 ? ((tracked / planned) * 100).round() : 0;
              return TickerStrip(plannedMinutes: planned, trackedMinutes: tracked, streak: done, focusPercent: focus);
            },
            loading: () => const TickerStrip(plannedMinutes: 0, trackedMinutes: 0, streak: 0, focusPercent: 0),
            error: (_, __) => const TickerStrip(plannedMinutes: 0, trackedMinutes: 0, streak: 0, focusPercent: 0),
          ),
          Expanded(
            child: blocksAsync.when(
              data: (blocks) => blocks.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.grid_on, size: 64, color: LTColors.ash),
                          const SizedBox(height: 16),
                          Text(
                            isToday
                                ? 'Nothing planned. Ask the chat or tap + to add a block.'
                                : 'Nothing on ${_weekday(selected)} ${selected.day}/${selected.month}.',
                            style: const TextStyle(color: LTColors.ash),
                          ),
                          const SizedBox(height: 16),
                          Wrap(
                            spacing: 8,
                            alignment: WrapAlignment.center,
                            children: [
                              if (!isToday)
                                OutlinedButton(
                                  onPressed: () => ref.read(selectedDayProvider.notifier).state = today,
                                  child: const Text('Back to today'),
                                ),
                              FilledButton(
                                onPressed: () => context.go('/chat'),
                                child: const Text('Open Chat'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    )
                  : DayTimeline(
                      blocks: blocks,
                      day: selected,
                      onBlockTap: (block) => context.push('/block/${block.id}'),
                      onBlockLongPress: (block) => context.push('/focus/${block.id}'),
                    ),
              loading: () => const Center(child: CircularProgressIndicator(color: LTColors.lemon)),
              error: (e, _) => Center(child: Text('Error: $e')),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/block/new'),
        backgroundColor: LTColors.lemon,
        foregroundColor: LTColors.ink,
        icon: const Icon(Icons.add),
        label: const Text('Add block'),
      ),
    );
  }

  String _weekday(DateTime d) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days[d.weekday - 1];
  }
}

final blocksForDayProvider = StreamProvider.family<List<TimeBlock>, DateTime>((ref, day) {
  final repo = ref.watch(blockRepositoryProvider);
  return repo.watchForDay(day);
});

final allBlocksStreamProvider = StreamProvider<List<TimeBlock>>((ref) async* {
  final repo = ref.watch(blockRepositoryProvider);
  yield repo.getAll();
  yield* repo.changes.map((_) => repo.getAll());
});
