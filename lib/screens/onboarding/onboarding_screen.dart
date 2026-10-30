import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../data/repositories/block_repository.dart';
import '../../theme/lt_colors.dart';
import '../../widgets/common/lt_logo.dart';

class OnboardingScreen extends ConsumerWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const LtLogo(size: 64),
            const SizedBox(height: 16),
            const Text('Plan in blocks. Talk to your time.', style: TextStyle(color: LTColors.ash)),
            const SizedBox(height: 32),
            FilledButton(
              onPressed: () async {
                try {
                  await ref.read(sharedPreferencesProvider).setBool(kOnboardingCompletedKey, true);
                } catch (_) {
                  // Preferences unavailable — proceed anyway.
                }
                if (context.mounted) context.go('/today');
              },
              child: const Text('Get Started'),
            ),
          ],
        ),
      ),
    );
  }
}
