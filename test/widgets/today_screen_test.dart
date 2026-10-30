import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lemontrack_/screens/today/today_screen.dart';
import 'package:lemontrack_/data/repositories/block_repository.dart';
import 'package:lemontrack_/domain/models/time_block.dart';

Iterable<String> allText(WidgetTester tester) sync* {
  for (final w in tester.allWidgets) {
    if (w is Text) yield w.data ?? '';
  }
}

void main() {
  testWidgets('created block shows up on today screen', (WidgetTester tester) async {
    final repo = MemoryBlockRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          blockRepositoryProvider.overrideWithValue(repo),
        ],
        child: const MaterialApp(home: TodayScreen()),
      ),
    );

    await tester.pumpAndSettle(const Duration(seconds: 2));
    debugPrint('INITIAL TEXT: ${allText(tester).toList()}');
    expect(find.textContaining('Nothing planned'), findsOneWidget);

    final now = DateTime.now();
    await repo.upsert(TimeBlock(
      id: 'test-block-1',
      title: 'Gym session',
      notes: null,
      startUtc: DateTime(now.year, now.month, now.day, 9, 0).toUtc(),
      endUtc: DateTime(now.year, now.month, now.day, 9, 30).toUtc(),
      timezone: now.timeZoneName,
      categoryId: 'health',
      status: BlockStatus.planned,
      trackedSeconds: 0,
      priority: 1,
      source: BlockSource.user,
      createdAtUtc: DateTime.now().toUtc(),
      updatedAtUtc: DateTime.now().toUtc(),
    ));
    await tester.pumpAndSettle(const Duration(seconds: 2));

    debugPrint('AFTER INSERT TEXT: ${allText(tester).toList()}');
    expect(find.textContaining('Nothing planned'), findsNothing);
    expect(find.text('Gym session'), findsOneWidget);
  });
}
