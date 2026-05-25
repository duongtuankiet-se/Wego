import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../services/driver_service.dart';
import 'driver_provider.dart';
import 'driver_service_provider.dart';

part 'earnings_provider.g.dart';

@riverpod
Future<DriverDailyStats> driverTodayStats(Ref ref) async {
  final driver = await ref.watch(currentDriverProvider.future);
  if (driver == null) return DriverDailyStats.empty;
  return ref.watch(driverServiceProvider).getTodayStats(driver.id);
}

@riverpod
Future<List<CompletedTripRow>> driverRecentTrips(Ref ref) async {
  final driver = await ref.watch(currentDriverProvider.future);
  if (driver == null) return const [];
  return ref.watch(driverServiceProvider).recentCompleted(driver.id);
}

@riverpod
Future<List<int>> driverWeeklyCounts(Ref ref) async {
  final driver = await ref.watch(currentDriverProvider.future);
  if (driver == null) return const [0, 0, 0, 0, 0, 0, 0];
  return ref.watch(driverServiceProvider).weeklyTripCounts(driver.id);
}
