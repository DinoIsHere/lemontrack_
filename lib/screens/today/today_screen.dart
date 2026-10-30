import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../data/repositories/block_repository.dart';
import '../../theme/lt_colors.dart';
import '../../widgets/crypto/ticker_strip.dart';
import '../../widgets/crypto/day_timeline.dart';
import '../../domain/models/time_block.dart';

class TodayScreen extends ConsumerWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    // Stable day key — DateTime.now() with microseconds would spawn a new
    // provider on every rebuild and keep the screen stuck in loading.
    final today = DateTime(now.year, now.month, now.day);
    final blocksAsync = ref.watch(blocksForDayProvider(today));

    return Scaffold(
      appBar: AppBar(
        backgroundColor: LTColors.ink,
        title: Text('${_weekday(today)} ${today.day}', style: Theme.of(context).textTheme.headlineMedium),
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
                          const Text('Nothing planned. Ask the chat or tap + to add a block.', style: TextStyle(color: LTColors.ash)),
                          const SizedBox(height: 16),
                          FilledButton(
                            onPressed: () => context.go('/chat'),
                            child: const Text('Open Chat'),
                          ),
                        ],
                      ),
                    )
                  : DayTimeline(
                      blocks: blocks,
                      day: today,
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
