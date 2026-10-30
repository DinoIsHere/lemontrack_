import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/time_block.dart';
import '../../theme/lt_colors.dart';
import '../../theme/lt_text.dart';
import '../../util/time.dart';
import '../today/today_screen.dart' show allBlocksStreamProvider;

class SummaryScreen extends ConsumerWidget {
  const SummaryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final blocksAsync = ref.watch(allBlocksStreamProvider);
    final all = blocksAsync.valueOrNull ?? <TimeBlock>[];
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    List<TimeBlock> onDay(DateTime d) => all.where((b) {
          final l = b.startUtc.toLocal();
          return l.year == d.year && l.month == d.month && l.day == d.day;
        }).toList();

    final bs = onDay(today);
    final planned = bs.fold<int>(0, (a, b) => a + b.endUtc.difference(b.startUtc).inMinutes);
    final tracked = bs.fold<int>(0, (a, b) => a + b.trackedSeconds ~/ 60);
    final done = bs.where((b) => b.status == BlockStatus.done).length;
    final rate = bs.isEmpty ? 0 : (done / bs.length * 100).round();

    // Streak: consecutive days (ending today or yesterday) with tracked > 0.
    var streak = 0;
    for (var i = 0; i < 365; i++) {
      final d = today.subtract(Duration(days: i));
      final hasTracked = onDay(d).any((b) => b.trackedSeconds > 0);
      if (hasTracked) {
        streak++;
      } else if (i > 0) {
        break;
      }
    }

    // Category breakdown for today.
    final byCat = <String, int>{};
    for (final b in bs) {
      byCat[b.categoryId] = (byCat[b.categoryId] ?? 0) + b.endUtc.difference(b.startUtc).inMinutes;
    }

    final days14 = List.generate(14, (i) => today.subtract(Duration(days: 13 - i)));

    return Scaffold(
      appBar: AppBar(
        backgroundColor: LTColors.ink,
        title: Text('Summary · ${formatDate(today)}', style: Theme.of(context).textTheme.titleLarge),
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          _StatCard(
            label: 'TRACKED TODAY',
            value: formatDuration(Duration(minutes: tracked)),
            delta: tracked - planned,
            deltaLabel: 'vs ${formatDuration(Duration(minutes: planned))} planned',
            gradient: true,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _StatCard(label: 'COMPLETION', value: '$rate%', deltaLabel: '$done/${bs.length} blocks')),
              const SizedBox(width: 8),
              Expanded(child: _StatCard(label: 'STREAK', value: '$streak d', deltaLabel: streak > 0 ? 'keep it alive' : 'track a block', flame: streak > 0)),
            ],
          ),
          const SizedBox(height: 24),
          Text('LAST 14 DAYS · PLANNED VS TRACKED', style: Theme.of(context).textTheme.labelSmall),
          const SizedBox(height: 8),
          SizedBox(
            height: 140,
            child: CustomPaint(
              painter: _CandlePainter(
                days: days14,
                plannedByDay: days14.map((d) => onDay(d).fold<int>(0, (a, b) => a + b.endUtc.difference(b.startUtc).inMinutes)).toList(),
                trackedByDay: days14.map((d) => onDay(d).fold<int>(0, (a, b) => a + b.trackedSeconds ~/ 60)).toList(),
                todayIndex: 13,
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text('TODAY BY CATEGORY', style: Theme.of(context).textTheme.labelSmall),
          const SizedBox(height: 8),
          if (byCat.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text('Nothing planned today.', style: TextStyle(color: LTColors.ash, fontSize: 13)),
            ),
          ...byCat.entries.map((e) {
            final color = LTColors.categoryColors[e.key] ?? LTColors.lemon;
            final pct = planned == 0 ? 0.0 : e.value / planned;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                children: [
                  SizedBox(width: 90, child: Text(e.key.replaceAll('_', ' '), style: const TextStyle(fontSize: 12, color: LTColors.ash))),
                  Expanded(
                    child: Container(
                      height: 8,
                      decoration: BoxDecoration(color: LTColors.steel, borderRadius: BorderRadius.circular(4)),
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: pct.clamp(0.0, 1.0),
                        child: Container(decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4))),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(width: 50, child: Text(formatDuration(Duration(minutes: e.value)), style: LTText.ticker.copyWith(fontSize: 10, color: LTColors.ash), textAlign: TextAlign.right)),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final String deltaLabel;
  final int? delta;
  final bool gradient;
  final bool flame;

  const _StatCard({required this.label, required this.value, this.deltaLabel = '', this.delta, this.gradient = false, this.flame = false});

  @override
  Widget build(BuildContext context) {
    final deltaColor = delta == null ? LTColors.ash : (delta! >= 0 ? LTColors.up : LTColors.coral);
    final deltaIcon = delta == null ? null : (delta! >= 0 ? Icons.arrow_upward : Icons.arrow_downward);

    Widget card = Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: LTColors.graphite,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: gradient ? LTColors.lemon : LTColors.wire),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelSmall),
          const SizedBox(height: 6),
          Row(
            children: [
              Text(value, style: LTText.numericMedium.copyWith(color: flame ? LTColors.ember : LTColors.lemon)),
              if (deltaIcon != null) ...[
                const Spacer(),
                Icon(deltaIcon, size: 14, color: deltaColor),
                if (delta != null) Text('${delta!.abs()}m', style: TextStyle(fontSize: 11, color: deltaColor)),
              ],
            ],
          ),
          if (deltaLabel.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(deltaLabel, style: const TextStyle(fontSize: 11, color: LTColors.ash)),
          ],
        ],
      ),
    );
    if (gradient) {
      card = Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [LTColors.neonGradientStart, LTColors.neonGradientEnd]),
        ),
        padding: const EdgeInsets.all(1.5),
        child: card,
      );
    }
    return card;
  }
}

class _CandlePainter extends CustomPainter {
  final List<DateTime> days;
  final List<int> plannedByDay;
  final List<int> trackedByDay;
  final int todayIndex;

  _CandlePainter({required this.days, required this.plannedByDay, required this.trackedByDay, required this.todayIndex});

  @override
  void paint(Canvas canvas, Size size) {
    const maxMinutes = 600.0;
    final n = days.length;
    final slot = size.width / n;
    final barW = slot * 0.55;

    // grid lines
    final grid = Paint()..color = LTColors.gridLine..strokeWidth = 1;
    for (var g = 1; g <= 3; g++) {
      final y = size.height - (size.height * (g / 4));
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }

    for (var i = 0; i < n; i++) {
      final p = plannedByDay[i].toDouble();
      final t = trackedByDay[i].toDouble();
      final cx = slot * i + slot / 2;

      final plannedH = (p / maxMinutes * size.height).clamp(2.0, size.height);
      final trackedH = (t / maxMinutes * size.height).clamp(0.0, size.height);

      // planned bar (background)
      final plannedPaint = Paint()
        ..color = i == todayIndex ? LTColors.steel : LTColors.steel.withValues(alpha: 0.55);
      final plannedRect = Rect.fromLTWH(cx - barW / 2, size.height - plannedH, barW, plannedH);
      canvas.drawRRect(RRect.fromRectAndRadius(plannedRect, const Radius.circular(3)), plannedPaint);

      // wick = planned range marker at top
      if (p > 0) {
        final wick = Paint()
          ..color = LTColors.wire
          ..strokeWidth = 1.5;
        canvas.drawLine(Offset(cx, size.height - plannedH - 4), Offset(cx, size.height - plannedH), wick);
      }

      // tracked bar (overlay, green up / red short / lemon planned-not-started)
      if (trackedH > 0) {
        final color = (t >= p && p > 0) ? LTColors.up : LTColors.coral;
        final trackedPaint = Paint()..color = color;
        final trackedRect = Rect.fromLTWH(cx - barW / 2 + 2, size.height - trackedH, barW - 4, trackedH);
        canvas.drawRRect(RRect.fromRectAndRadius(trackedRect, const Radius.circular(2)), trackedPaint);
      } else if (p > 0) {
        final outline = Paint()
          ..color = LTColors.lemon
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1;
        canvas.drawRRect(RRect.fromRectAndRadius(plannedRect, const Radius.circular(3)), outline);
      }

      // day label
      final tp = TextPainter(
        text: TextSpan(text: '${days[i].day}', style: const TextStyle(color: LTColors.ash, fontSize: 8)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(cx - tp.width / 2, size.height + 2));
    }
  }

  @override
  bool shouldRepaint(covariant _CandlePainter old) =>
      old.trackedByDay != trackedByDay || old.plannedByDay != plannedByDay;
}
