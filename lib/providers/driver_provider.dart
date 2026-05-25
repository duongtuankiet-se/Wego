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
