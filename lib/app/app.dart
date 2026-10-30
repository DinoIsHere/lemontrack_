import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/lt_theme.dart';
import 'router.dart';

class LemonTrackApp extends ConsumerWidget {
  const LemonTrackApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'LemonTrack',
      theme: ltDarkTheme(),
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
