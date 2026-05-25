import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'models/user.dart';
import 'screens/_dev/showcase_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/role_select_screen.dart';
import 'screens/auth/splash_screen.dart';
import 'screens/driver/driver_earnings_screen.dart';
import 'screens/driver/driver_home_screen.dart';
import 'screens/driver/driver_navigation_screen.dart';
import 'screens/driver/driver_performance_screen.dart';
import 'screens/driver/driver_trip_completed_screen.dart';
import 'screens/driver/driver_wallet_screen.dart';
import 'screens/passenger/home_screen.dart';
import 'screens/passenger/live_trip_screen.dart';
import 'screens/passenger/matching_screen.dart';
import 'screens/passenger/ride_options_screen.dart';
import 'screens/passenger/search_screen.dart';
import 'screens/passenger/trip_summary_screen.dart';

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
        path: '/passenger/ride-options',
        pageBuilder: (context, state) =>
            _slideUpPage(state: state, child: const RideOptionsScreen()),
      ),
      GoRoute(
        path: '/passenger/matching',
        pageBuilder: (context, state) {
          final extra =
              (state.extra as Map?)?.cast<String, Object>() ??
              <String, Object>{};
          return _fadeScalePage(
            state: state,
            child: MatchingScreen(extra: extra),
          );
        },
      ),
      GoRoute(
        path: '/passenger/live-trip/:tripId',
        pageBuilder: (context, state) => _fadeScalePage(
          state: state,
          child: LiveTripScreen(tripId: state.pathParameters['tripId']!),
        ),
      ),
      GoRoute(
        path: '/passenger/trip-summary/:tripId',
        pageBuilder: (context, state) => _slideUpPage(
          state: state,
          child: TripSummaryScreen(tripId: state.pathParameters['tripId']!),
        ),
      ),
      GoRoute(
        path: '/driver/home',
        pageBuilder: (context, state) =>
            _fadeScalePage(state: state, child: const DriverHomeScreen()),
      ),
      GoRoute(
        path: '/driver/navigation/:tripId',
        pageBuilder: (context, state) => _fadeScalePage(
          state: state,
          child: DriverNavigationScreen(
            tripId: state.pathParameters['tripId']!,
          ),
        ),
      ),
      GoRoute(
        path: '/driver/trip-completed/:tripId',
        pageBuilder: (context, state) => _slideUpPage(
          state: state,
          child: DriverTripCompletedScreen(
            tripId: state.pathParameters['tripId']!,
          ),
        ),
      ),
      GoRoute(
        path: '/driver/earnings',
        pageBuilder: (context, state) =>
            _slideUpPage(state: state, child: const DriverEarningsScreen()),
      ),
      GoRoute(
        path: '/driver/wallet',
        pageBuilder: (context, state) =>
            _slideUpPage(state: state, child: const DriverWalletScreen()),
      ),
      GoRoute(
        path: '/driver/performance',
        pageBuilder: (context, state) =>
            _slideUpPage(state: state, child: const DriverPerformanceScreen()),
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
