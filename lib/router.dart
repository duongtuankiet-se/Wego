import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'models/user.dart';
import 'screens/_dev/matching_test_screen.dart';
import 'screens/_dev/seed_screen.dart';
import 'screens/_dev/showcase_screen.dart';
import 'screens/auth/complete_profile_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/auth/role_select_screen.dart';
import 'screens/auth/splash_screen.dart';
import 'screens/auth/verify_otp_screen.dart';
import 'screens/driver/driver_earnings_screen.dart';
import 'screens/driver/driver_home_screen.dart';
import 'screens/driver/driver_navigation_screen.dart';
import 'screens/driver/driver_performance_screen.dart';
import 'screens/driver/driver_pools_screen.dart';
import 'screens/driver/driver_profile_screen.dart';
import 'screens/driver/driver_shell.dart';
import 'screens/driver/driver_trip_completed_screen.dart';
import 'screens/driver/driver_vehicles_screen.dart';
import 'screens/driver/driver_wallet_screen.dart';
import 'screens/notifications/notification_screen.dart';
import 'screens/passenger/home_screen.dart';
import 'screens/passenger/live_trip_screen.dart';
import 'screens/passenger/map_picker_screen.dart';
import 'screens/passenger/matching_screen.dart';
import 'screens/passenger/passenger_activity_screen.dart';
import 'screens/passenger/passenger_profile_screen.dart';
import 'screens/passenger/passenger_promo_screen.dart';
import 'screens/passenger/passenger_shell.dart';
import 'screens/passenger/passenger_support_screen.dart';
import 'screens/passenger/ride_options_screen.dart';
import 'screens/passenger/schedule_confirmation_screen.dart';
import 'screens/passenger/schedule_detail_screen.dart';
import 'screens/passenger/schedule_ride_screen.dart';
import 'screens/passenger/search_screen.dart';
import 'screens/passenger/trip_summary_screen.dart';

part 'router.g.dart';

final _rootKey = GlobalKey<NavigatorState>();
final _passengerKey = GlobalKey<NavigatorState>();
final _driverKey = GlobalKey<NavigatorState>();

@Riverpod(keepAlive: true)
GoRouter router(Ref ref) {
  return GoRouter(
    navigatorKey: _rootKey,
    initialLocation: '/',
    debugLogDiagnostics: kDebugMode,
    routes: [
      GoRoute(path: '/', builder: (context, state) => const SplashScreen()),
      GoRoute(
        path: '/role-select',
        builder: (context, state) => const RoleSelectScreen(),
      ),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(
        path: '/register',
        builder: (context, state) {
          final roleParam = state.uri.queryParameters['role'] ?? 'passenger';
          final role = roleParam == 'driver'
              ? UserRole.driver
              : UserRole.passenger;
          return RegisterScreen(initialRole: role);
        },
      ),
      GoRoute(
        path: '/verify-otp',
        builder: (context, state) {
          final extra =
              (state.extra as Map?)?.cast<String, Object>() ??
              <String, Object>{};
          return VerifyOtpScreen(
            phone: extra['phone'] as String,
            isRegister: extra['isRegister'] as bool? ?? false,
            name: extra['name'] as String?,
            role: extra['role'] as UserRole?,
          );
        },
      ),
      GoRoute(
        path: '/complete-profile',
        builder: (context, state) => const CompleteProfileScreen(),
      ),

      // ── Passenger shell — 5 tabs ──────────────────────────────────
      StatefulShellRoute.indexedStack(
        parentNavigatorKey: _rootKey,
        builder: (context, state, shell) =>
            PassengerShell(navigationShell: shell),
        branches: [
          StatefulShellBranch(
            navigatorKey: _passengerKey,
            routes: [
              GoRoute(
                path: '/passenger/home',
                pageBuilder: (context, state) => _noTransition(
                  state: state,
                  child: const PassengerHomeScreen(),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/passenger/activity',
                pageBuilder: (context, state) => _noTransition(
                  state: state,
                  child: const PassengerActivityScreen(),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/passenger/promo',
                pageBuilder: (context, state) => _noTransition(
                  state: state,
                  child: const PassengerPromoScreen(),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/passenger/support',
                pageBuilder: (context, state) => _noTransition(
                  state: state,
                  child: const PassengerSupportScreen(),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/passenger/profile',
                pageBuilder: (context, state) => _noTransition(
                  state: state,
                  child: const PassengerProfileScreen(),
                ),
              ),
            ],
          ),
        ],
      ),

      // ── Driver shell — 5 tabs ─────────────────────────────────────
      StatefulShellRoute.indexedStack(
        parentNavigatorKey: _rootKey,
        builder: (context, state, shell) => DriverShell(navigationShell: shell),
        branches: [
          StatefulShellBranch(
            navigatorKey: _driverKey,
            routes: [
              GoRoute(
                path: '/driver/home',
                pageBuilder: (context, state) => _noTransition(
                  state: state,
                  child: const DriverHomeScreen(),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/driver/earnings',
                pageBuilder: (context, state) => _noTransition(
                  state: state,
                  child: const DriverEarningsScreen(),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/driver/wallet',
                pageBuilder: (context, state) => _noTransition(
                  state: state,
                  child: const DriverWalletScreen(),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/driver/performance',
                pageBuilder: (context, state) => _noTransition(
                  state: state,
                  child: const DriverPerformanceScreen(),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/driver/profile',
                pageBuilder: (context, state) => _noTransition(
                  state: state,
                  child: const DriverProfileScreen(),
                ),
              ),
            ],
          ),
        ],
      ),

      // ── Modal routes (NO bottom tab) ─────────────────────────────
      GoRoute(
        parentNavigatorKey: _rootKey,
        path: '/passenger/search',
        pageBuilder: (context, state) =>
            _slideUpPage(state: state, child: const PassengerSearchScreen()),
      ),
      GoRoute(
        parentNavigatorKey: _rootKey,
        path: '/passenger/map-picker',
        pageBuilder: (context, state) {
          final mode = state.uri.queryParameters['mode'] == 'pickup'
              ? MapPickerMode.pickup
              : MapPickerMode.dropoff;
          return _slideUpPage(
            state: state,
            child: MapPickerScreen(mode: mode),
          );
        },
      ),
      GoRoute(
        parentNavigatorKey: _rootKey,
        path: '/passenger/ride-options',
        pageBuilder: (context, state) =>
            _slideUpPage(state: state, child: const RideOptionsScreen()),
      ),
      GoRoute(
        parentNavigatorKey: _rootKey,
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
        parentNavigatorKey: _rootKey,
        path: '/passenger/live-trip/:tripId',
        pageBuilder: (context, state) => _fadeScalePage(
          state: state,
          child: LiveTripScreen(tripId: state.pathParameters['tripId']!),
        ),
      ),
      GoRoute(
        parentNavigatorKey: _rootKey,
        path: '/passenger/trip-summary/:tripId',
        pageBuilder: (context, state) => _slideUpPage(
          state: state,
          child: TripSummaryScreen(tripId: state.pathParameters['tripId']!),
        ),
      ),
      GoRoute(
        parentNavigatorKey: _rootKey,
        path: '/notifications',
        pageBuilder: (context, state) =>
            _slideUpPage(state: state, child: const NotificationScreen()),
      ),
      GoRoute(
        parentNavigatorKey: _rootKey,
        path: '/passenger/schedule',
        pageBuilder: (context, state) =>
            _slideUpPage(state: state, child: const ScheduleRideScreen()),
      ),
      GoRoute(
        parentNavigatorKey: _rootKey,
        path: '/passenger/schedule-confirm/:tripId',
        pageBuilder: (context, state) => _fadeScalePage(
          state: state,
          child: ScheduleConfirmationScreen(
            tripId: state.pathParameters['tripId']!,
          ),
        ),
      ),
      GoRoute(
        parentNavigatorKey: _rootKey,
        path: '/passenger/schedule-detail/:tripId',
        pageBuilder: (context, state) => _slideUpPage(
          state: state,
          child: ScheduleDetailScreen(
            tripId: state.pathParameters['tripId']!,
          ),
        ),
      ),
      GoRoute(
        parentNavigatorKey: _rootKey,
        path: '/driver/navigation/:tripId',
        pageBuilder: (context, state) => _fadeScalePage(
          state: state,
          child: DriverNavigationScreen(
            tripId: state.pathParameters['tripId']!,
          ),
        ),
      ),
      GoRoute(
        parentNavigatorKey: _rootKey,
        path: '/driver/trip-completed/:tripId',
        pageBuilder: (context, state) => _slideUpPage(
          state: state,
          child: DriverTripCompletedScreen(
            tripId: state.pathParameters['tripId']!,
          ),
        ),
      ),
      GoRoute(
        parentNavigatorKey: _rootKey,
        path: '/driver/vehicles',
        pageBuilder: (context, state) =>
            _slideUpPage(state: state, child: const DriverVehiclesScreen()),
      ),
      GoRoute(
        parentNavigatorKey: _rootKey,
        path: '/driver/pools',
        pageBuilder: (context, state) =>
            _slideUpPage(state: state, child: const DriverPoolsScreen()),
      ),

      if (kDebugMode) ...[
        GoRoute(
          parentNavigatorKey: _rootKey,
          path: '/showcase',
          builder: (context, state) => const ShowcaseScreen(),
        ),
        GoRoute(
          parentNavigatorKey: _rootKey,
          path: '/dev/matching-test',
          pageBuilder: (context, state) =>
              _slideUpPage(state: state, child: const MatchingTestScreen()),
        ),
        GoRoute(
          parentNavigatorKey: _rootKey,
          path: '/dev/seed',
          pageBuilder: (context, state) =>
              _slideUpPage(state: state, child: const SeedScreen()),
        ),
      ],
    ],
    errorBuilder: (context, state) => Scaffold(
      appBar: AppBar(title: const Text('Không tìm thấy')),
      body: Center(child: Text('Route không tồn tại: ${state.uri}')),
    ),
  );
}

/// No transition — used for shell tab branches so switching tabs is instant.
CustomTransitionPage<T> _noTransition<T>({
  required GoRouterState state,
  required Widget child,
}) {
  return CustomTransitionPage<T>(
    key: state.pageKey,
    child: child,
    transitionDuration: Duration.zero,
    reverseTransitionDuration: Duration.zero,
    transitionsBuilder: (_, _, _, child) => child,
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
