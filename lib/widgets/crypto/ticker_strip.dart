import 'package:flutter/material.dart';
import '../../theme/lt_colors.dart';
import '../../theme/lt_text.dart';

class TickerStrip extends StatelessWidget {
  final int plannedMinutes;
  final int trackedMinutes;
  final int streak;
  final int focusPercent;

  const TickerStrip({
    super.key,
    required this.plannedMinutes,
    required this.trackedMinutes,
    required this.streak,
    required this.focusPercent,
  });

  String _fmt(int m) {
    final h = m ~/ 60;
    final mm = m % 60;
    return h > 0 ? '${h}h ${mm}m' : '${mm}m';
  }

  @override
  Widget build(BuildContext context) {
    final items = [
      _Item(label: 'PLANNED', value: _fmt(plannedMinutes)),
      _Item(label: 'TRACKED', value: _fmt(trackedMinutes)),
      _Item(label: 'STREAK', value: '${streak}d'),
      _Item(label: 'FOCUS', value: '$focusPercent%'),
    ];
    return Container(
      color: LTColors.tickerBg,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      child: Row(
        children: [for (final it in items) Expanded(child: Center(child: FittedBox(fit: BoxFit.scaleDown, child: it)))],
      ),
    );
  }
}

class _Item extends StatelessWidget {
  final String label;
  final String value;
  const _Item({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
        const SizedBox(height: 2),
        Text(value, style: LTText.ticker, maxLines: 1),
      ],
    );
  }
}
