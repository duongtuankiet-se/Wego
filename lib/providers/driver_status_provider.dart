import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../models/driver.dart';
import 'driver_provider.dart';
import 'driver_service_provider.dart';
import 'wallet_provider.dart';

part 'driver_status_provider.g.dart';

/// Phase 5Q: thrown when a driver tries to flip online without enough
/// wallet float. Caught by the UI to surface a topup-prompt toast
/// instead of the generic "Lỗi cập nhật trạng thái".
class WalletGateException implements Exception {
  WalletGateException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Runtime dispatch status. Initialized from the Driver doc; mutations
/// write through to Mongo via [DriverService.setStatus].
@Riverpod(keepAlive: true)
class CurrentDriverStatus extends _$CurrentDriverStatus {
  @override
  Future<DriverStatus> build() async {
    final driver = await ref.watch(currentDriverProvider.future);
    return driver?.status ?? DriverStatus.offline;
  }

  Future<void> toggle({double? lat, double? lng}) async {
    final current = state.valueOrNull ?? DriverStatus.offline;
    final next = current == DriverStatus.online
        ? DriverStatus.offline
        : DriverStatus.online;
    await setStatus(next, lat: lat, lng: lng);
  }

  Future<void> setStatus(DriverStatus next, {double? lat, double? lng}) async {
    // Phase 5Q: wallet gate — driver must hold ≥ minBalanceRequired
    // (50k) before going online. Cheap and bails out before we mutate
    // any state / DB row.
    if (next == DriverStatus.online) {
      final wallet = await ref.read(currentUserWalletProvider.future);
      if (wallet != null && !wallet.canAcceptTrips) {
        throw WalletGateException(
          'Cần nạp tối thiểu ${wallet.minBalanceRequired ~/ 1000}.000đ '
          'vào ví để bắt đầu nhận chuyến',
        );
      }
    }

    final previous = state.valueOrNull ?? DriverStatus.offline;
    state = AsyncData(next);
    try {
      final driver = await ref.read(currentDriverProvider.future);
      if (driver == null) return;
      await ref
          .read(driverServiceProvider)
          .setStatus(driverId: driver.id, status: next, lat: lat, lng: lng);
      ref.invalidate(currentDriverProvider);
    } catch (e) {
      // Rollback UI state on failure to whatever it was before this call.
      state = AsyncData(previous);
      rethrow;
    }
  }
}
