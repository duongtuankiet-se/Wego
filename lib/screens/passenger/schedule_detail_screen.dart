import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_shadows.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/wg_button.dart';
import '../../core/widgets/wg_status_badge.dart';
import '../../core/widgets/wg_toast.dart';
import '../../models/scheduled_trip.dart';
import '../../providers/scheduled_trips_provider.dart';

class ScheduleDetailScreen extends ConsumerStatefulWidget {
  const ScheduleDetailScreen({super.key, required this.tripId});
  final String tripId;

  @override
  ConsumerState<ScheduleDetailScreen> createState() =>
      _ScheduleDetailScreenState();
}

class _ScheduleDetailScreenState extends ConsumerState<ScheduleDetailScreen> {
  Timer? _ticker;
  bool _cancelling = false;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _confirmCancel(ScheduledTrip trip) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dctx) => AlertDialog(
        title: const Text('Huỷ chuyến đi?'),
        content: Text(
          'Chuyến ${trip.tripCode} sẽ bị huỷ. '
          'Nếu chuyến đã được tài xế nhận, có thể áp dụng phí huỷ.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dctx, false),
            child: const Text('Không'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('Huỷ chuyến'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _cancelling = true);
    try {
      final svc = ref.read(scheduledTripServiceProvider);
      final success = await svc.cancelScheduledTrip(
        tripId: trip.id,
        cancelledBy: 'passenger',
        reason: 'Huỷ bởi hành khách',
      );
      if (!mounted) return;
      if (success) {
        ref.invalidate(scheduledTripDetailProvider(trip.id));
        ref.invalidate(upcomingScheduledTripsProvider);
        ref.invalidate(pastScheduledTripsProvider);
        WgToast.success(context, 'Đã huỷ chuyến');
      } else {
        WgToast.error(context, 'Không huỷ được chuyến này');
      }
    } catch (e) {
      if (mounted) WgToast.error(context, 'Lỗi: $e');
    } finally {
      if (mounted) setState(() => _cancelling = false);
    }
  }

  void _copyCode(String code) {
    HapticFeedback.lightImpact();
    Clipboard.setData(ClipboardData(text: code));
    WgToast.success(context, 'Đã sao chép $code');
  }

  @override
  Widget build(BuildContext context) {
    final tripAsync = ref.watch(scheduledTripDetailProvider(widget.tripId));

    return Scaffold(
      backgroundColor: AppColors.offWhite,
      appBar: AppBar(
        backgroundColor: AppColors.offWhite,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(PhosphorIconsRegular.arrowLeft),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Chi tiết chuyến đặt',
          style: AppTypography.h2.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
      body: tripAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Lỗi: $e',
              textAlign: TextAlign.center,
              style: AppTypography.body.copyWith(color: AppColors.ink700),
            ),
          ),
        ),
        data: (trip) {
          if (trip == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Không tìm thấy chuyến đi.',
                  style: AppTypography.body.copyWith(color: AppColors.ink700),
                ),
              ),
            );
          }
          return _Body(
            trip: trip,
            cancelling: _cancelling,
            onCancel: () => _confirmCancel(trip),
            onCopyCode: _copyCode,
          );
        },
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({
    required this.trip,
    required this.cancelling,
    required this.onCancel,
    required this.onCopyCode,
  });
  final ScheduledTrip trip;
  final bool cancelling;
  final VoidCallback onCancel;
  final void Function(String) onCopyCode;

  bool get _canCancel =>
      trip.status == ScheduledTripStatus.pending ||
      trip.status == ScheduledTripStatus.matched ||
      trip.status == ScheduledTripStatus.driverAssigned;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    return Stack(
      children: [
        ListView(
          padding: EdgeInsets.fromLTRB(
            16,
            8,
            16,
            (_canCancel ? 100 : 24) + bottomInset,
          ),
          children: [
            _StatusHeader(trip: trip),
            const SizedBox(height: 12),
            _CodeRow(trip: trip, onCopy: onCopyCode),
            const SizedBox(height: 12),
            _ScheduleStrip(trip: trip),
            const SizedBox(height: 12),
            _RouteBlock(trip: trip),
            const SizedBox(height: 12),
            _DetailsList(trip: trip),
            const SizedBox(height: 12),
            _FareBlock(trip: trip),
            if (trip.status == ScheduledTripStatus.cancelled) ...[
              const SizedBox(height: 12),
              _CancellationBlock(trip: trip),
            ],
          ],
        ),
        if (_canCancel)
          Positioned(
            left: 16,
            right: 16,
            bottom: bottomInset + 12,
            child: WgButton.ghost(
              label: 'Huỷ chuyến đi',
              leadingIcon: PhosphorIconsRegular.xCircle,
              onPressed: cancelling ? null : onCancel,
              isFullWidth: true,
              size: WgButtonSize.lg,
              isLoading: cancelling,
            ),
          ),
      ],
    );
  }
}

class _StatusHeader extends StatelessWidget {
  const _StatusHeader({required this.trip});
  final ScheduledTrip trip;

  WgStatusTone get _tone => switch (trip.status) {
    ScheduledTripStatus.pending => WgStatusTone.warning,
    ScheduledTripStatus.matched ||
    ScheduledTripStatus.driverAssigned ||
    ScheduledTripStatus.started => WgStatusTone.info,
    ScheduledTripStatus.completed => WgStatusTone.success,
    ScheduledTripStatus.cancelled ||
    ScheduledTripStatus.expired => WgStatusTone.danger,
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: AppRadius.card,
        boxShadow: AppShadows.xs,
      ),
      child: Row(
        children: [
          WgStatusBadge(label: trip.statusLabel, tone: _tone),
          const Spacer(),
          if (trip.status == ScheduledTripStatus.pending ||
              trip.status == ScheduledTripStatus.matched ||
              trip.status == ScheduledTripStatus.driverAssigned)
            Text(
              trip.countdownText,
              style: AppTypography.caption.copyWith(
                color: AppColors.ink700,
                fontWeight: FontWeight.w700,
              ),
            ),
        ],
      ),
    );
  }
}

class _CodeRow extends StatelessWidget {
  const _CodeRow({required this.trip, required this.onCopy});
  final ScheduledTrip trip;
  final void Function(String) onCopy;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: AppRadius.card,
        boxShadow: AppShadows.xs,
      ),
      child: Row(
        children: [
          const Icon(
            PhosphorIconsFill.ticket,
            color: AppColors.primary500,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              trip.tripCode,
              style: AppTypography.body.copyWith(
                fontWeight: FontWeight.w800,
                fontFamily: 'monospace',
                letterSpacing: 1.4,
                color: AppColors.ink900,
              ),
            ),
          ),
          TextButton.icon(
            onPressed: () => onCopy(trip.tripCode),
            icon: const Icon(PhosphorIconsRegular.copy, size: 16),
            label: const Text('Sao chép'),
            style: TextButton.styleFrom(foregroundColor: AppColors.primary500),
          ),
        ],
      ),
    );
  }
}

class _ScheduleStrip extends StatelessWidget {
  const _ScheduleStrip({required this.trip});
  final ScheduledTrip trip;

  @override
  Widget build(BuildContext context) {
    final flex = trip.flexibleWindowMin == 0
        ? 'Đúng giờ'
        : '± ${trip.flexibleWindowMin} phút';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFEF3C7), Color(0xFFFDE68A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: AppRadius.card,
      ),
      child: Row(
        children: [
          const Icon(
            PhosphorIconsFill.calendarCheck,
            color: Color(0xFFB45309),
            size: 28,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  trip.scheduledAtVN,
                  style: AppTypography.h3.copyWith(
                    color: const Color(0xFF78350F),
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Khoảng đón: $flex',
                  style: AppTypography.caption.copyWith(
                    color: const Color(0xFF92400E),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RouteBlock extends StatelessWidget {
  const _RouteBlock({required this.trip});
  final ScheduledTrip trip;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: AppRadius.card,
        boxShadow: AppShadows.xs,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Column(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: const BoxDecoration(
                    color: AppColors.success,
                    shape: BoxShape.circle,
                  ),
                ),
                Container(width: 2, height: 28, color: AppColors.ink200),
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: AppColors.danger,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  trip.pickup.name,
                  style: AppTypography.body.copyWith(
                    color: AppColors.ink900,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  trip.pickup.address,
                  style: AppTypography.caption.copyWith(
                    color: AppColors.ink500,
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 18),
                Text(
                  trip.dropoff.name,
                  style: AppTypography.body.copyWith(
                    color: AppColors.ink900,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  trip.dropoff.address,
                  style: AppTypography.caption.copyWith(
                    color: AppColors.ink500,
                  ),
                  maxLines: 2,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailsList extends StatelessWidget {
  const _DetailsList({required this.trip});
  final ScheduledTrip trip;

  String _luggage() => switch (trip.luggage) {
    LuggageType.none => 'Không có',
    LuggageType.small => 'Hành lý nhỏ',
    LuggageType.large => 'Hành lý lớn',
  };

  String _recurrence() => switch (trip.recurrence) {
    RecurrenceType.once => '1 lần',
    RecurrenceType.daily => 'Hàng ngày',
    RecurrenceType.weekly => 'Hàng tuần',
  };

  String _payment() => switch (trip.paymentMethod) {
    SchedulePaymentMethod.cash => 'Tiền mặt',
    SchedulePaymentMethod.vnpay => 'VNPay',
    SchedulePaymentMethod.momo => 'MoMo',
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: AppRadius.card,
        boxShadow: AppShadows.xs,
      ),
      child: Column(
        children: [
          _row(
            PhosphorIconsFill.car,
            'Loại xe',
            trip.rideType == 'shared' ? 'Xe ghép thông minh' : 'Xe riêng',
          ),
          _row(
            PhosphorIconsFill.user,
            'Hành khách',
            '${trip.passengerCount} người',
          ),
          _row(PhosphorIconsFill.suitcase, 'Hành lý', _luggage()),
          _row(PhosphorIconsFill.repeat, 'Lặp lại', _recurrence()),
          _row(PhosphorIconsFill.wallet, 'Thanh toán', _payment()),
          if (trip.promoCode != null && trip.promoCode!.isNotEmpty)
            _row(PhosphorIconsFill.tag, 'Mã giảm giá', trip.promoCode!),
          if (trip.note != null && trip.note!.isNotEmpty)
            _row(PhosphorIconsFill.note, 'Ghi chú', trip.note!),
        ],
      ),
    );
  }

  Widget _row(IconData icon, String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: AppColors.ink500),
        const SizedBox(width: 8),
        Text(
          label,
          style: AppTypography.caption.copyWith(color: AppColors.ink500),
        ),
        const Spacer(),
        Flexible(
          child: Text(
            value,
            style: AppTypography.body.copyWith(
              color: AppColors.ink900,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.right,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    ),
  );
}

class _FareBlock extends StatelessWidget {
  const _FareBlock({required this.trip});
  final ScheduledTrip trip;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary50, AppColors.primary100],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: AppRadius.card,
        border: Border.all(color: AppColors.primary200),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${trip.estimatedDistanceKm.toStringAsFixed(1)} km · ${trip.estimatedDurationMin} phút',
                style: AppTypography.caption.copyWith(
                  color: AppColors.ink700,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                formatVnd(trip.baseFare),
                style: AppTypography.body.copyWith(
                  color: AppColors.ink700,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
          if (trip.discount > 0) ...[
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Giảm giá',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.success,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '- ${formatVnd(trip.discount)}',
                  style: AppTypography.body.copyWith(
                    color: AppColors.success,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ],
          const Divider(height: 18, color: AppColors.primary200),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Tổng',
                style: AppTypography.bodyLarge.copyWith(
                  color: AppColors.ink900,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                formatVnd(trip.estimatedFare),
                style: AppTypography.h2.copyWith(
                  color: AppColors.primary600,
                  fontWeight: FontWeight.w800,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CancellationBlock extends StatelessWidget {
  const _CancellationBlock({required this.trip});
  final ScheduledTrip trip;

  @override
  Widget build(BuildContext context) {
    final by = switch (trip.cancelledBy) {
      'passenger' => 'Hành khách',
      'driver' => 'Tài xế',
      'system' => 'Hệ thống',
      _ => '—',
    };
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.danger.withValues(alpha: 0.06),
        borderRadius: AppRadius.card,
        border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                PhosphorIconsFill.xCircle,
                color: AppColors.danger,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                'Chuyến đã huỷ',
                style: AppTypography.body.copyWith(
                  color: AppColors.danger,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Bởi: $by',
            style: AppTypography.caption.copyWith(color: AppColors.ink700),
          ),
          if (trip.cancelReason != null && trip.cancelReason!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                'Lý do: ${trip.cancelReason}',
                style: AppTypography.caption.copyWith(color: AppColors.ink700),
              ),
            ),
        ],
      ),
    );
  }
}
