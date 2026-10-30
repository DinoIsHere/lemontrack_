import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../domain/scheduling/conflict.dart';
import '../../theme/lt_colors.dart';
import '../../theme/lt_text.dart';
import '../../util/time.dart';
import '../today/today_screen.dart' show allBlocksStreamProvider, selectedDayProvider;

class WeekScreen extends ConsumerWidget {
  const WeekScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final blocksAsync = ref.watch(allBlocksStreamProvider);
    final now = DateTime.now();
    final monday = DateTime(now.year, now.month, now.day).subtract(Duration(days: now.weekday - 1));
    final days = List.generate(7, (i) => monday.add(Duration(days: i)));

    final totalPlanned = blocksAsync.valueOrNull
            ?.where((b) => b.startUtc.toLocal().isAfter(monday.subtract(const Duration(days: 1))))
            .where((b) => b.startUtc.toLocal().isBefore(monday.add(const Duration(days: 7))))
            .fold<int>(0, (a, b) => a + b.endUtc.difference(b.startUtc).inMinutes) ??
        0;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: LTColors.ink,
        title: Text('Week of ${formatDate(monday)}', style: Theme.of(context).textTheme.titleLarge),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: Row(
              children: [
                Text('PLANNED THIS WEEK', style: Theme.of(context).textTheme.labelSmall),
                const Spacer(),
                Text(formatDuration(Duration(minutes: totalPlanned)), style: LTText.ticker.copyWith(color: LTColors.lemon)),
              ],
            ),
          ),
          const Divider(color: LTColors.wireSoft, height: 1),
          Expanded(
            child: blocksAsync.when(
              loading: () => const Center(child: CircularProgressIndicator(color: LTColors.lemon)),
              error: (e, _) => Center(child: Text('$e')),
              data: (all) => ListView(
                padding: const EdgeInsets.all(12),
                children: days.map((day) {
                  final bs = all.where((b) {
                    final l = b.startUtc.toLocal();
                    return l.year == day.year && l.month == day.month && l.day == day.day;
                  }).toList()
                    ..sort((a, b) => a.startUtc.compareTo(b.startUtc));
                  final isToday = day.day == now.day && day.month == now.month;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        GestureDetector(
                          onTap: () {
                            ref.read(selectedDayProvider.notifier).state = day;
                            context.go('/today');
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              children: [
                                Text(
                                  '${_wd(day)} ${day.day}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.8,
                                    color: isToday ? LTColors.lemon : LTColors.ash,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(child: Container(height: 1, color: LTColors.wireSoft)),
                              ],
                            ),
                          ),
                        ),
                        if (bs.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Text('Free day', style: TextStyle(fontSize: 12, color: LTColors.ash.withValues(alpha: 0.6))),
                          ),
                        ...bs.map((b) {
                          final conf = findConflicts(b, bs);
                          final color = LTColors.categoryColors[b.categoryId] ?? LTColors.lemon;
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: GestureDetector(
                              onTap: () => context.push('/block/${b.id}'),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                decoration: BoxDecoration(
                                  color: LTColors.graphite,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: conf.isNotEmpty ? LTColors.coral : LTColors.wire),
                                ),
                                child: Row(
                                  children: [
                                    Container(width: 3, height: 16, color: color),
                                    const SizedBox(width: 8),
                                    Expanded(child: Text(b.title, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis)),
                                    Text('${formatTime(b.startUtc.toLocal())}', style: LTText.ticker.copyWith(fontSize: 10, color: LTColors.ash)),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static const _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  String _wd(DateTime d) => _days[d.weekday - 1];
}
