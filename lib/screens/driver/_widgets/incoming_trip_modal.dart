import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/format.dart';
import '../../../core/widgets/wg_avatar.dart';
import '../../../core/widgets/wg_badge.dart';
import '../../../core/widgets/wg_button.dart';
import '../../../core/widgets/wg_countdown_ring.dart';
import '../../../models/trip.dart';
import '../../../providers/incoming_trip_provider.dart';

/// Returns true if accepted, false if declined or timed out.
Future<bool> showIncomingTripDialog(
  BuildContext context, {
  required IncomingTripOffer offer,
  required Future<bool> Function() onAccept,
}) async {
  HapticFeedback.mediumImpact();
  final result = await showGeneralDialog<bool>(
    context: context,
    barrierDismissible: false,
    barrierLabel: 'incoming',
    barrierColor: Colors.black.withValues(alpha: 0.55),
    transitionDuration: const Duration(milliseconds: 280),
    pageBuilder: (ctx, _, _) =>
        _IncomingDialog(offer: offer, onAccept: onAccept),
    transitionBuilder: (_, anim, _, child) {
      final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutBack);
      return FadeTransition(
        opacity: anim,
        child: ScaleTransition(
          scale: Tween(begin: 0.92, end: 1.0).animate(curved),
          child: child,
        ),
      );
    },
  );
  return result ?? false;
}

class _IncomingDialog extends StatefulWidget {
  const _IncomingDialog({required this.offer, required this.onAccept});
  final IncomingTripOffer offer;
  final Future<bool> Function() onAccept;
  @override
  State<_IncomingDialog> createState() => _IncomingDialogState();
}

class _IncomingDialogState extends State<_IncomingDialog> {
  static const _total = 15;
  late int _left;
  Timer? _timer;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _left = _total;
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() => _left--);
      if (_left <= 0) {
        t.cancel();
        _close(false);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _close(bool accepted) {
    if (!mounted) return;
    Navigator.of(context).pop(accepted);
  }

  Future<void> _accept() async {
    if (_busy) return;
    setState(() => _busy = true);
    _timer?.cancel();
    final ok = await widget.onAccept();
    if (!mounted) return;
    if (ok) {
      _close(true);
    } else {
      setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final o = widget.offer;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Material(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(28),
            elevation: 24,
            shadowColor: AppColors.ink900.withValues(alpha: 0.3),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      WgBadge(
                        label: o.type == TripType.shared
                            ? 'XE GHÉP'
                            : 'XE RIÊNG',
                        variant: o.type == TripType.shared
                            ? WgBadgeVariant.shared
                            : WgBadgeVariant.info,
                      ),
                      WgCountdownRing(
                        secondsLeft: _left.clamp(0, _total),
                        totalSeconds: _total,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      WgAvatar(
                        name: o.passengerName,
                        size: 44,
                        rating: o.passengerRating,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              o.passengerName,
                              style: AppTypography.bodyLarge.copyWith(
                                color: AppColors.ink900,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                const Icon(
                                  Icons.star_rounded,
                                  color: AppColors.warning,
                                  size: 14,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${o.passengerRating.toStringAsFixed(2)} · ${o.passengerTripCount} chuyến',
                                  style: AppTypography.caption.copyWith(
                                    color: AppColors.ink500,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _RouteBlock(
                    pickupAddress: o.pickup.name,
                    dropoffAddress: o.dropoff.name,
                    fromDriverKm: o.distanceFromDriverKm,
                    tripKm: o.tripDistanceKm,
                  ),
                  const SizedBox(height: 12),
                  const Divider(height: 1, color: AppColors.ink100),
                  const SizedBox(height: 12),
                  _MetricsRow(
                    distanceKm: o.tripDistanceKm,
                    durationMin: o.tripDurationMin,
                    price: o.price,
                  ),
                  if (o.type == TripType.shared) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.sharedAccent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.groups,
                            color: AppColors.sharedAccent,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Có thể ghép thêm 1 khách dọc tuyến',
                              style: AppTypography.caption.copyWith(
                                color: AppColors.sharedAccent,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  WgButton.primary(
                    label: 'Nhận chuyến',
                    size: WgButtonSize.lg,
                    isFullWidth: true,
                    isLoading: _busy,
                    onPressed: _busy ? null : _accept,
                  ),
                  const SizedBox(height: 6),
                  TextButton(
                    onPressed: _busy ? null : () => _close(false),
                    style: TextButton.styleFrom(
                      minimumSize: const Size.fromHeight(44),
                    ),
                    child: Text(
                      'Từ chối',
                      style: AppTypography.body.copyWith(
                        color: AppColors.ink500,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RouteBlock extends StatelessWidget {
  const _RouteBlock({
    required this.pickupAddress,
    required this.dropoffAddress,
    required this.fromDriverKm,
    required this.tripKm,
  });
  final String pickupAddress;
  final String dropoffAddress;
  final double fromDriverKm;
  final double tripKm;

  @override
  Widget build(BuildContext context) {
    return Row(
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
              Container(width: 1.5, height: 30, color: AppColors.ink300),
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
                'Đón',
                style: AppTypography.micro.copyWith(color: AppColors.ink500),
              ),
              Text(
                pickupAddress,
                style: AppTypography.body.copyWith(
                  color: AppColors.ink900,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                'cách bạn ${fromDriverKm.toStringAsFixed(1)} km',
                style: AppTypography.caption.copyWith(
                  color: AppColors.sharedAccent,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Đến',
                style: AppTypography.micro.copyWith(color: AppColors.ink500),
              ),
              Text(
                dropoffAddress,
                style: AppTypography.body.copyWith(
                  color: AppColors.ink900,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                '${tripKm.toStringAsFixed(1)} km nữa',
                style: AppTypography.caption.copyWith(color: AppColors.ink500),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MetricsRow extends StatelessWidget {
  const _MetricsRow({
    required this.distanceKm,
    required this.durationMin,
    required this.price,
  });
  final double distanceKm;
  final int durationMin;
  final int price;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _metric(
          Icons.straighten,
          '${distanceKm.toStringAsFixed(1)} km',
          AppColors.ink900,
        ),
        _vDivider(),
        _metric(Icons.access_time, '$durationMin phút', AppColors.ink900),
        _vDivider(),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              'Tổng cộng',
              style: AppTypography.micro.copyWith(color: AppColors.ink500),
            ),
            Text(
              formatVnd(price),
              style: AppTypography.bodyLarge.copyWith(
                color: AppColors.primary500,
                fontWeight: FontWeight.w800,
                fontFamily: 'monospace',
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _metric(IconData icon, String label, Color color) {
    return Column(
      children: [
        Icon(icon, color: AppColors.ink500, size: 16),
        const SizedBox(height: 2),
        Text(
          label,
          style: AppTypography.caption.copyWith(
            color: color,
            fontWeight: FontWeight.w700,
            fontFamily: 'monospace',
          ),
        ),
      ],
    );
  }

  Widget _vDivider() =>
      Container(width: 0.5, height: 32, color: AppColors.ink300);
}
