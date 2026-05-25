import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'core/theme/app_colors.dart';
import 'core/theme/app_typography.dart';
import 'models/user.dart';
import 'screens/_dev/showcase_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/role_select_screen.dart';
import 'screens/auth/splash_screen.dart';
import 'screens/passenger/home_screen.dart';
import 'screens/passenger/search_screen.dart';

part 'router.g.dart';

@Riverpod(keepAlive: true)
GoRouter router(Ref ref) {
  return GoRouter(
    initialLocation: '/',
    debugLogDiagnostics: kDebugMode,
    routes: [
      GoRoute(path: '/', builder: (context, state) => const SplashScreen()),
      GoRoute(
        path: '/role-select',
        builder: (context, state) => const RoleSelectScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) {
          final roleParam = state.uri.queryParameters['role'] ?? 'passenger';
          final role = roleParam == 'driver'
              ? UserRole.driver
              : UserRole.passenger;
          return LoginScreen(role: role);
        },
      ),
      GoRoute(
        path: '/passenger/home',
        pageBuilder: (context, state) =>
            _fadeScalePage(state: state, child: const PassengerHomeScreen()),
      ),
      GoRoute(
        path: '/passenger/search',
        pageBuilder: (context, state) =>
            _slideUpPage(state: state, child: const PassengerSearchScreen()),
      ),
      GoRoute(
        path: '/driver/home',
        builder: (context, state) =>
            const _PlaceholderHome(role: 'driver', title: 'Trang chủ Tài xế'),
      ),
      if (kDebugMode)
        GoRoute(
          path: '/showcase',
          builder: (context, state) => const ShowcaseScreen(),
        ),
    ],
    errorBuilder: (context, state) => Scaffold(
      appBar: AppBar(title: const Text('Không tìm thấy')),
      body: Center(child: Text('Route không tồn tại: ${state.uri}')),
    ),
  );
}

CustomTransitionPage<T> _fadeScalePage<T>({
  required GoRouterState state,
  required Widget child,
}) {
  return CustomTransitionPage<T>(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 350),
    transitionsBuilder: (context, animation, _, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
      );
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.98, end: 1.0).animate(curved),
          child: child,
        ),
      );
    },
  );
}

CustomTransitionPage<T> _slideUpPage<T>({
  required GoRouterState state,
  required Widget child,
}) {
  return CustomTransitionPage<T>(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 400),
    transitionsBuilder: (context, animation, _, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
      );
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.08),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        ),
      );
    },
  );
}

class _PlaceholderHome extends StatelessWidget {
  const _PlaceholderHome({required this.role, required this.title});
  final String role;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              role == 'driver' ? Icons.directions_car : Icons.person,
              size: 80,
              color: AppColors.primary500,
            ),
            const SizedBox(height: 16),
            Text('Phase 0 placeholder', style: AppTypography.h2),
            const SizedBox(height: 8),
            Text('role = $role', style: AppTypography.body),
            if (kDebugMode) ...[
              const SizedBox(height: 24),
              TextButton.icon(
                onPressed: () => context.push('/showcase'),
                icon: const Icon(Icons.palette),
                label: const Text('Mở Showcase (debug)'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
