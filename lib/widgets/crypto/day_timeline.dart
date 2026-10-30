import 'package:flutter/material.dart';
import '../../domain/models/time_block.dart';
import '../../domain/scheduling/conflict.dart';
import '../../theme/lt_colors.dart';
import '../../util/time.dart';

class DayTimeline extends StatelessWidget {
  final List<TimeBlock> blocks;
  final DateTime day;
  final Function(TimeBlock)? onBlockTap;
  final Function(TimeBlock)? onBlockLongPress;

  const DayTimeline({
    super.key,
    required this.blocks,
    required this.day,
    this.onBlockTap,
    this.onBlockLongPress,
  });

  @override
  Widget build(BuildContext context) {
    const startHour = 6;
    const endHour = 22;
    const hourHeight = 60.0;
    final totalHeight = (endHour - startHour + 1) * hourHeight;
    final conflictIds = <String>{};
    for (final b in blocks) {
      if (findConflicts(b, blocks).isNotEmpty) conflictIds.add(b.id);
    }

    return SingleChildScrollView(
      child: SizedBox(
        height: totalHeight,
        child: Stack(
          children: [
            // Hour grid
            for (int h = startHour; h <= endHour; h++)
              Positioned(
                top: (h - startHour) * hourHeight,
                left: 0,
                right: 0,
                child: Container(
                  height: hourHeight,
                  decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: LTColors.wireSoft.withValues(alpha: 0.5))),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(4.0),
                    child: Text('${h.toString().padLeft(2, '0')}:00', style: const TextStyle(fontSize: 10, color: LTColors.ash)),
                  ),
                ),
              ),
            // Blocks
            ...blocks.where((b) => b.deletedAtUtc == null).map((block) {
              final startLocal = block.startUtc.toLocal();
              final endLocal = block.endUtc.toLocal();
              if (startLocal.day != day.day) return const SizedBox.shrink();
              final top = (startLocal.hour + startLocal.minute / 60 - startHour) * hourHeight;
              final height = (endLocal.difference(startLocal).inMinutes / 60) * hourHeight;
              final color = LTColors.categoryColors[block.categoryId] ?? LTColors.lemon;
              final isConflict = conflictIds.contains(block.id);
              final isInProgress = block.status == BlockStatus.inProgress;

              return Positioned(
                top: top,
                left: 52,
                right: 8,
                height: height.clamp(24, hourHeight * 4),
                child: GestureDetector(
                  onTap: () => onBlockTap?.call(block),
                  onLongPress: () => onBlockLongPress?.call(block),
                  child: Container(
                    decoration: BoxDecoration(
                      color: LTColors.graphite,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isConflict ? LTColors.coral : (isInProgress ? LTColors.lemon : LTColors.wire),
                      ),
                      boxShadow: isInProgress ? [const BoxShadow(color: LTColors.glow, blurRadius: 12)] : null,
                    ),
                    child: Opacity(
                      opacity: block.status == BlockStatus.done ? 0.6 : 1.0,
                      child: Row(
                        children: [
                          Container(width: 3, decoration: BoxDecoration(color: color, borderRadius: const BorderRadius.horizontal(left: Radius.circular(12)))),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(child: Text(block.title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)),
                                      if (block.status == BlockStatus.done)
                                        const Icon(Icons.check_circle, size: 14, color: LTColors.up),
                                      if (isConflict)
                                        const Icon(Icons.error_outline, size: 14, color: LTColors.coral),
                                    ],
                                  ),
                                  Text('${formatTime(startLocal)}-${formatTime(endLocal)}', style: const TextStyle(fontSize: 10, color: LTColors.ash)),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),
            // Now line
            _buildNowLine(startHour, hourHeight),
          ],
        ),
      ),
    );
  }

  Widget _buildNowLine(int startHour, double hourHeight) {
    final now = DateTime.now();
    if (now.day != day.day) return const SizedBox.shrink();
    final top = (now.hour + now.minute / 60 - startHour) * hourHeight;
    if (top < 0 || top > hourHeight * 16) return const SizedBox.shrink();
    return Positioned(
      top: top,
      left: 48,
      right: 0,
      child: Row(
        children: [
          Container(width: 8, height: 8, decoration: const BoxDecoration(color: LTColors.lemon, shape: BoxShape.circle)),
          Expanded(child: Container(height: 2, color: LTColors.lemon)),
        ],
      ),
    );
  }
}
