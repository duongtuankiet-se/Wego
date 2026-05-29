import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../models/driver.dart';
import 'auth_provider.dart';
import 'driver_service_provider.dart';

part 'driver_provider.g.dart';

/// Current logged-in user's Driver doc. Returns null if the user isn't
/// a driver or doesn't have a stub record yet.
@Riverpod(keepAlive: true)
Future<Driver?> currentDriver(Ref ref) async {
  final user = await ref.watch(authStateProvider.future);
  if (user == null) return null;
  return ref.watch(driverServiceProvider).getDriverForUser(user.id);
}

/// Phase 5R: look up any driver by id. Used by the passenger waiting
/// screen once a scheduled trip has been assigned, to surface the
/// driver's name + vehicle plate + rating without dragging in the
/// full ActiveDriver/CurrentTrip plumbing.
@riverpod
Future<Driver?> driverById(Ref ref, String driverId) =>
    ref.watch(driverServiceProvider).getById(driverId);
