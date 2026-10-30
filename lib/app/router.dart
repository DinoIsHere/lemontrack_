import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../screens/today/today_screen.dart';
import '../screens/week/week_screen.dart';
import '../screens/chat/chat_screen.dart';
import '../screens/summary/summary_screen.dart';
import '../screens/onboarding/onboarding_screen.dart';
import '../screens/splash/splash_screen.dart';
import '../screens/block_editor/block_editor_screen.dart';
import '../screens/focus/focus_screen.dart';
import '../screens/settings/settings_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/splash',
    routes: [
      ShellRoute(
        builder: (context, state, child) {
          return Scaffold(
            body: child,
            bottomNavigationBar: NavigationBar(
              selectedIndex: _getIndex(state.uri.path),
              onDestinationSelected: (index) => _onTap(context, index),
              destinations: const [
                NavigationDestination(icon: Icon(Icons.today), label: 'Today'),
                NavigationDestination(icon: Icon(Icons.calendar_view_week), label: 'Week'),
                NavigationDestination(icon: Icon(Icons.auto_awesome), label: 'Chat'),
                NavigationDestination(icon: Icon(Icons.bar_chart), label: 'Summary'),
              ],
            ),
          );
        },
        routes: [
          GoRoute(path: '/today', builder: (context, state) => const TodayScreen()),
          GoRoute(path: '/week', builder: (context, state) => const WeekScreen()),
          GoRoute(path: '/chat', builder: (context, state) => const ChatScreen()),
          GoRoute(path: '/summary', builder: (context, state) => const SummaryScreen()),
        ],
      ),
      GoRoute(path: '/onboarding', builder: (context, state) => const OnboardingScreen()),
      GoRoute(path: '/block/new', builder: (context, state) => const BlockEditorScreen()),
      GoRoute(path: '/block/:id', builder: (context, state) => BlockEditorScreen(id: state.pathParameters['id'])),
      GoRoute(path: '/focus/:id', builder: (context, state) => FocusScreen(id: state.pathParameters['id']!)),
      GoRoute(path: '/settings', builder: (context, state) => const SettingsScreen()),
      GoRoute(path: '/splash', builder: (context, state) => const SplashScreen()),
    ],
  );
});

int _getIndex(String path) {
  if (path.startsWith('/week')) return 1;
  if (path.startsWith('/chat')) return 2;
  if (path.startsWith('/summary')) return 3;
  return 0;
}

void _onTap(BuildContext context, int index) {
  switch (index) {
    case 0:
      context.go('/today');
      break;
    case 1:
      context.go('/week');
      break;
    case 2:
      context.go('/chat');
      break;
    case 3:
      context.go('/summary');
      break;
  }
}
