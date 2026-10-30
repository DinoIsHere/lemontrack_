import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../../data/repositories/block_repository.dart';
import '../../domain/models/time_block.dart';
import '../../theme/lt_colors.dart';
import '../../theme/lt_text.dart';

class FocusScreen extends ConsumerStatefulWidget {
  final String id;
  const FocusScreen({super.key, required this.id});

  @override
  ConsumerState<FocusScreen> createState() => _FocusScreenState();
}

class _FocusScreenState extends ConsumerState<FocusScreen> {
  static const int _workMin = 25;
  static const int _shortBreakMin = 5;
  static const int _longBreakMin = 15;

  Timer? _timer;
  TimeBlock? _block;
  int _remaining = _workMin * 60;
  int _total = _workMin * 60;
  bool _running = false;
  bool _isBreak = false;
  int _completedSessions = 0;
  int _trackedWorkSeconds = 0;

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable();
    _load();
  }

  void _load() async {
    final repo = ref.read(blockRepositoryProvider);
    final b = await repo.getById(widget.id);
    if (b != null && mounted) setState(() => _block = b);
  }

  void _start() {
    setState(() => _running = true);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      setState(() {
        if (_remaining > 0) {
          _remaining--;
          if (!_isBreak) _trackedWorkSeconds++;
        } else {
          _completePhase();
        }
      });
    });
  }

  void _pause() {
    setState(() => _running = false);
    _timer?.cancel();
  }

  void _completePhase() {
    _timer?.cancel();
    setState(() {
      _running = false;
      if (!_isBreak) {
        _completedSessions++;
        _isBreak = true;
        _total = (_completedSessions % 4 == 0 ? _longBreakMin : _shortBreakMin) * 60;
      } else {
        _isBreak = false;
        _total = _workMin * 60;
      }
      _remaining = _total;
    });
  }

  Future<void> _end() async {
    _timer?.cancel();
    final b = _block;
    if (b != null) {
      final repo = ref.read(blockRepositoryProvider);
      await repo.upsert(b.copyWith(
        trackedSeconds: b.trackedSeconds + _trackedWorkSeconds,
        status: BlockStatus.inProgress,
      ));
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  void dispose() {
    _timer?.cancel();
    WakelockPlus.disable();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final b = _block;
    final progress = _total == 0 ? 0.0 : 1 - (_remaining / _total);
    final mm = (_remaining ~/ 60).toString().padLeft(2, '0');
    final ss = (_remaining % 60).toString().padLeft(2, '0');

    return Scaffold(
      backgroundColor: LTColors.ink,
      appBar: AppBar(
        backgroundColor: LTColors.ink,
        title: Text(_isBreak ? 'Break' : 'Pomodoro'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (b != null)
              Text(b.title, style: Theme.of(context).textTheme.titleLarge, textAlign: TextAlign.center),
            if (b != null)
              Text(
                b.startUtc.toLocal().toString().substring(11, 16) + ' - ' + b.endUtc.toLocal().toString().substring(11, 16),
                style: const TextStyle(color: LTColors.ash, fontSize: 13),
              ),
            const SizedBox(height: 32),
            Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 280,
                  height: 280,
                  child: CustomPaint(
                    painter: _RingPainter(progress: progress.clamp(0.0, 1.0), isBreak: _isBreak),
                  ),
                ),
                Column(
                  children: [
                    Text('$mm:$ss', style: LTText.numericLarge.copyWith(fontSize: 64)),
                    const SizedBox(height: 4),
                    Text(_isBreak ? 'break' : 'focus $_completedSessions/4', style: const TextStyle(color: LTColors.ash)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 48),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (!_running)
                  FilledButton(onPressed: _start, child: Text(_remaining < _total ? 'Resume' : 'Start'))
                else
                  OutlinedButton(onPressed: _pause, child: const Text('Pause')),
                const SizedBox(width: 16),
                OutlinedButton(onPressed: _end, child: const Text('End session')),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Tracked this session: ${(_trackedWorkSeconds / 60).floor()}m ${_trackedWorkSeconds % 60}s',
              style: const TextStyle(color: LTColors.ash, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  final bool isBreak;
  _RingPainter({required this.progress, required this.isBreak});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 12;

    // dashed outer ring
    final dashPaint = Paint()
      ..color = LTColors.wire
      ..strokeWidth = 6
      ..style = PaintingStyle.stroke;
    const dashWidth = 4.0;
    const gap = 6.0;
    final circumference = 2 * 3.141592653589793 * (radius + 10);
    double angle = 0;
    while (angle < 2 * 3.141592653589793) {
      final arcLen = dashWidth;
      final sweep = arcLen / (radius + 10);
      canvas.drawArc(Rect.fromCircle(center: center, radius: radius + 10), angle - 1.5707963, sweep, false, dashPaint);
      angle += (dashWidth + gap) / (radius + 10);
    }
    assert(circumference > 0);

    // track
    final trackPaint = Paint()
      ..color = LTColors.steel
      ..strokeWidth = 10
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(center, radius, trackPaint);

    // progress arc
    final arcPaint = Paint()
      ..color = isBreak ? LTColors.up : LTColors.lemon
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    if (progress > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -1.5707963,
        2 * 3.141592653589793 * progress,
        false,
        arcPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) => old.progress != progress || old.isBreak != isBreak;
}
