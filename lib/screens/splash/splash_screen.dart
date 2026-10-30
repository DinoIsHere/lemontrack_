import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../data/repositories/block_repository.dart';
import '../../theme/lt_colors.dart';
import '../../theme/lt_text.dart';
import '../../widgets/common/lt_logo.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _navigateAfterInit();
  }

  Future<void> _navigateAfterInit() async {
    await Future.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;

    bool completed = false;
    try {
      final prefs = ref.read(sharedPreferencesProvider);
      completed = prefs.getBool(kOnboardingCompletedKey) ?? false;
    } catch (_) {
      // Preferences unavailable — treat as first launch.
      completed = false;
    }

    if (mounted) context.go(completed ? '/today' : '/onboarding');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LTColors.ink,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const LtLogo(size: 100),
            const SizedBox(height: 24),
            Text(
              'LemonTrack',
              style: LTText.textTheme().headlineMedium?.copyWith(
                color: LTColors.lemon,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Plan in blocks. Talk to your time.',
              style: TextStyle(color: LTColors.ash, fontSize: 14),
            ),
            const SizedBox(height: 40),
            const SizedBox(
              height: 28,
              width: 28,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                valueColor: AlwaysStoppedAnimation(LTColors.lemon),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
