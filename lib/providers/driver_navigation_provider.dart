import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'driver_navigation_provider.freezed.dart';
part 'driver_navigation_provider.g.dart';

enum DriverTripPhase { toPickup, arrived, toDropoff, completed }

@freezed
class DriverNavState with _$DriverNavState {
  const factory DriverNavState({
    @Default(DriverTripPhase.toPickup) DriverTripPhase phase,
    @Default(0) int instructionIndex,
    @Default(0.0) double progress, // 0..1 along current leg
  }) = _DriverNavState;
}

@riverpod
class DriverNavigation extends _$DriverNavigation {
  @override
  DriverNavState build() => const DriverNavState();

  void setPhase(DriverTripPhase phase) => state = state.copyWith(phase: phase);

  void setInstruction(int idx) => state = state.copyWith(instructionIndex: idx);

  void setProgress(double p) =>
      state = state.copyWith(progress: p.clamp(0.0, 1.0));

  void reset() => state = const DriverNavState();
}
