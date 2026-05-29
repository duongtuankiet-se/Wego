import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mongo_dart/mongo_dart.dart' show ObjectId, where;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_shadows.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/wg_badge.dart';
import '../../core/widgets/wg_empty_state.dart';
import '../../core/widgets/wg_error_state.dart';
import '../../core/widgets/wg_status_badge.dart';
import '../../models/scheduled_trip.dart';
import '../../providers/auth_provider.dart';
import '../../providers/mongo_provider.dart';
import '../../providers/scheduled_trips_provider.dart';

part 'passenger_activity_screen.g.dart';

// ─────────────────────────────────────────────────────────────────────
// Instant trip row (Phase 1B trips collection)
// ─────────────────────────────────────────────────────────────────────

class _ActivityTrip {
  final String id;
  final String type; // shared / private
  final String status;
  final String pickupAddress;
  final String dropoffAddress;
  final int price;
  final DateTime createdAt;
  _ActivityTrip({
    required this.id,
    required this.type,
    required this.status,
    required this.pickupAddress,
    required this.dropoffAddress,
    required this.price,
    required this.createdAt,
  });
}

@riverpod
// ignore: library_private_types_in_public_api
Future<List<_ActivityTrip>> passengerTrips(Ref ref) async {
  final user = await ref.watch(authStateProvider.future);
  if (user == null) return const [];
  final trips = await ref.read(mongoServiceProvider).trips();
  final cursor = trips.find(
    where
        .eq('passenger_id', ObjectId.fromHexString(user.id))
        .sortBy('created_at', descending: true)
        .limit(50),
  );
  final rows = <_ActivityTrip>[];
  await for (final doc in cursor) {
    rows.add(
      _ActivityTrip(
        id: (doc['_id'] as ObjectId).oid,
        type: doc['type'] as String? ?? 'private',
        status: doc['status'] as String? ?? 'pending',
        pickupAddress: doc['pickup_address'] as String? ?? '',
        dropoffAddress: doc['dropoff_address'] as String? ?? '',
        price: (doc['price'] as num?)?.toInt() ?? 0,
        createdAt: (doc['created_at'] as DateTime).toLocal(),
      ),
    );
  }
  return rows;
}

// ─────────────────────────────────────────────────────────────────────
// Screen
// ─────────────────────────────────────────────────────────────────────

class PassengerActivityScreen extends ConsumerWidget {
  const PassengerActivityScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppColors.offWhite,
        appBar: AppBar(
          title: const Text('Hoạt động'),
          backgroundColor: AppColors.offWhite,
          elevation: 0,
          scrolledUnderElevation: 0,
          bottom: const TabBar(
            indicatorColor: AppColors.primary500,
            indicatorWeight: 3,
            labelColor: AppColors.primary600,
            unselectedLabelColor: AppColors.ink500,
            labelStyle: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
            unselectedLabelStyle:
                TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            tabs: [
              Tab(text: 'Sắp tới'),
              Tab(text: 'Đã đi'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [_UpcomingTab(), _PastTab()],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Tab 1: upcoming scheduled trips
// ─────────────────────────────────────────────────────────────────────

class _UpcomingTab extends ConsumerWidget {
  const _UpcomingTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final upcomingAsync = ref.watch(upcomingScheduledTripsProvider);
    return upcomingAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => WgErrorState(
        title: 'Không tải được chuyến sắp tới',
        onRetry: () => ref.invalidate(upcomingScheduledTripsProvider),
      ),
      data: (trips) {
        if (trips.isEmpty) {
          return WgEmptyState(
            icon: PhosphorIconsRegular.calendarPlus,
            title: 'Chưa có chuyến nào sắp tới',
            subtitle: 'Đặt trước để hệ thống tự ghép tài xế đúng giờ.',
            ctaLabel: 'Đặt trước ngay',
            onCta: () => context.push('/passenger/schedule'),
          );
        }
        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(upcomingScheduledTripsProvider),
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            itemCount: trips.length,
            itemBuilder: (_, i) => _ScheduledTripCard(trip: trips[i]),
          ),
        );
      },
    );
  }
}

class _ScheduledTripCard extends StatelessWidget {
  const _ScheduledTripCard({required this.trip});
  final ScheduledTrip trip;

  WgStatusTone get _tone => switch (trip.status) {
    ScheduledTripStatus.pending => WgStatusTone.warning,
    ScheduledTripStatus.offered ||
    ScheduledTripStatus.matched ||
    ScheduledTripStatus.driverAssigned ||
    ScheduledTripStatus.started => WgStatusTone.info,
    ScheduledTripStatus.completed => WgStatusTone.success,
    ScheduledTripStatus.cancelled ||
    ScheduledTripStatus.expired ||
    ScheduledTripStatus.noDriverFound => WgStatusTone.danger,
  };

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: AppColors.white,
        borderRadius: AppRadius.card,
        child: InkWell(
          borderRadius: AppRadius.card,
          onTap: () =>
              context.push('/passenger/schedule-detail/${trip.id}'),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: AppRadius.card,
              boxShadow: AppShadows.xs,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Hotfix v3: previous Flexible wraps weren't enough —
                // WgStatusBadge's inner Text has no maxLines/ellipsis,
                // so it kept blowing past Flexible's loose-fit cap. Move
                // tripCode out of the top row entirely (lives next to
                // the fare now) and let the status badge consume all
                // remaining width via FittedBox(scaleDown) so long
                // labels like "Không tìm được tài xế" shrink to fit
                // instead of overflowing 40+ px off-card.
                Row(
                  children: [
                    WgBadge(
                      label: trip.rideType == 'shared'
                          ? 'XE GHÉP'
                          : 'XE RIÊNG',
                      variant: trip.rideType == 'shared'
                          ? WgBadgeVariant.shared
                          : WgBadgeVariant.info,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: WgStatusBadge(
                          label: trip.statusLabel,
                          tone: _tone,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primary50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        PhosphorIconsFill.clock,
                        size: 16,
                        color: AppColors.primary700,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          trip.scheduledAtVN,
                          style: AppTypography.caption.copyWith(
                            color: AppColors.primary700,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Text(
                        trip.countdownText,
                        style: AppTypography.caption.copyWith(
                          color: AppColors.primary600,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Column(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: AppColors.success,
                              shape: BoxShape.circle,
                            ),
                          ),
                          Container(
                            width: 1.5,
                            height: 22,
                            color: AppColors.ink300,
                          ),
                          Container(
                            width: 8,
                            height: 8,
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
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            trip.dropoff.name,
                            style: AppTypography.body.copyWith(
                              color: AppColors.ink900,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                const Divider(height: 1, color: AppColors.ink100),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Icon(
                      PhosphorIconsRegular.user,
                      size: 14,
                      color: AppColors.ink500,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${trip.passengerCount}',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.ink500,
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Hotfix v3: tripCode relocated from top row down
                    // here, ellipsis-aware so even WG-2026... can't
                    // overflow.
                    Flexible(
                      child: Text(
                        trip.tripCode,
                        style: AppTypography.micro.copyWith(
                          color: AppColors.ink500,
                          fontFamily: 'monospace',
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      formatVnd(trip.estimatedFare),
                      style: AppTypography.bodyLarge.copyWith(
                        color: AppColors.primary500,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Tab 2: past (instant trips + completed/cancelled scheduled)
// ─────────────────────────────────────────────────────────────────────

class _PastTab extends ConsumerWidget {
  const _PastTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tripsAsync = ref.watch(passengerTripsProvider);
    final pastScheduledAsync = ref.watch(pastScheduledTripsProvider);

    if (tripsAsync.isLoading || pastScheduledAsync.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (tripsAsync.hasError || pastScheduledAsync.hasError) {
      return WgErrorState(
        title: 'Không tải được lịch sử',
        onRetry: () {
          ref.invalidate(passengerTripsProvider);
          ref.invalidate(pastScheduledTripsProvider);
        },
      );
    }

    final instant = tripsAsync.value ?? const [];
    final pastSched = pastScheduledAsync.value ?? const [];

    if (instant.isEmpty && pastSched.isEmpty) {
      return WgEmptyState(
        icon: PhosphorIconsRegular.car,
        title: 'Chưa có chuyến đi nào',
        subtitle: 'Đặt chuyến đầu tiên để bắt đầu hành trình.',
        ctaLabel: 'Đặt xe ngay',
        onCta: () => context.go('/passenger/home'),
      );
    }

    // Merge by recency: instant uses createdAt, scheduled uses scheduledAt.
    final entries = <_HistoryEntry>[
      ...instant.map((t) => _HistoryEntry.instant(t)),
      ...pastSched.map((s) => _HistoryEntry.scheduled(s)),
    ]..sort((a, b) => b.sortDate.compareTo(a.sortDate));

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(passengerTripsProvider);
        ref.invalidate(pastScheduledTripsProvider);
      },
      child: _GroupedHistoryList(entries: entries),
    );
  }
}

class _HistoryEntry {
  final _ActivityTrip? instant;
  final ScheduledTrip? scheduled;

  _HistoryEntry.instant(this.instant) : scheduled = null;
  _HistoryEntry.scheduled(this.scheduled) : instant = null;

  DateTime get sortDate =>
      instant?.createdAt ?? scheduled!.scheduledAt;
}

class _GroupedHistoryList extends StatelessWidget {
  const _GroupedHistoryList({required this.entries});
  final List<_HistoryEntry> entries;

  Map<String, List<_HistoryEntry>> _groupByDate() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final out = <String, List<_HistoryEntry>>{};
    for (final e in entries) {
      final dt = e.sortDate;
      final d = DateTime(dt.year, dt.month, dt.day);
      final key = d == today
          ? 'Hôm nay'
          : d == yesterday
              ? 'Hôm qua'
              : '${d.day.toString().padLeft(2, '0')}/'
                  '${d.month.toString().padLeft(2, '0')}/${d.year}';
      out.putIfAbsent(key, () => []).add(e);
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final groups = _groupByDate();
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      children: groups.entries.expand((g) {
        return [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 14, 8, 8),
            child: Text(
              g.key,
              style: AppTypography.caption.copyWith(
                color: AppColors.ink500,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          ...g.value.map((e) {
            if (e.instant != null) return _InstantTripCard(trip: e.instant!);
            return _PastScheduledCard(trip: e.scheduled!);
          }),
        ];
      }).toList(),
    );
  }
}

class _InstantTripCard extends StatelessWidget {
  const _InstantTripCard({required this.trip});
  final _ActivityTrip trip;

  String _hhmm(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final isCompleted = trip.status == 'completed';
    final isCancelled = trip.status == 'cancelled';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: AppRadius.card,
        boxShadow: AppShadows.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Hotfix: when both the type badge AND the "ĐÃ HUỶ" badge
          // were rendered the row could overflow ~30px. Allow the
          // cancelled-badge to flex first since it's the secondary one.
          Row(
            children: [
              WgBadge(
                label: trip.type == 'shared' ? 'XE GHÉP' : 'XE RIÊNG',
                variant: trip.type == 'shared'
                    ? WgBadgeVariant.shared
                    : WgBadgeVariant.info,
              ),
              const SizedBox(width: 8),
              if (isCancelled)
                const Flexible(
                  child: WgBadge(
                    label: 'ĐÃ HUỶ',
                    variant: WgBadgeVariant.surge,
                  ),
                ),
              const Spacer(),
              Text(
                _hhmm(trip.createdAt),
                style: AppTypography.caption.copyWith(
                  color: AppColors.ink500,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Column(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: AppColors.success,
                        shape: BoxShape.circle,
                      ),
                    ),
                    Container(
                      width: 1.5,
                      height: 24,
                      color: AppColors.ink300,
                    ),
                    Container(
                      width: 8,
                      height: 8,
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
                      trip.pickupAddress,
                      style: AppTypography.body.copyWith(
                        color: AppColors.ink900,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 14),
                    Text(
                      trip.dropoffAddress,
                      style: AppTypography.body.copyWith(
                        color: AppColors.ink900,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: AppColors.ink100),
          const SizedBox(height: 10),
          Row(
            children: [
              WgStatusBadge(
                label: isCompleted
                    ? 'Hoàn thành'
                    : (isCancelled ? 'Đã hủy' : 'Đang xử lý'),
                tone: isCompleted
                    ? WgStatusTone.success
                    : (isCancelled
                        ? WgStatusTone.danger
                        : WgStatusTone.warning),
              ),
              const Spacer(),
              Text(
                formatVnd(trip.price),
                style: AppTypography.bodyLarge.copyWith(
                  color: AppColors.primary500,
                  fontWeight: FontWeight.w700,
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

class _PastScheduledCard extends StatelessWidget {
  const _PastScheduledCard({required this.trip});
  final ScheduledTrip trip;

  WgStatusTone get _tone => switch (trip.status) {
    ScheduledTripStatus.completed => WgStatusTone.success,
    ScheduledTripStatus.cancelled ||
    ScheduledTripStatus.expired => WgStatusTone.danger,
    _ => WgStatusTone.info,
  };

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => context.push('/passenger/schedule-detail/${trip.id}'),
      borderRadius: AppRadius.card,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: AppRadius.card,
          boxShadow: AppShadows.sm,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Hotfix: status labels like "Không tìm được tài xế" pushed
            // the row 50px past the card edge even after the previous
            // pass wrapped status + date in Flexible — the leading
            // "ĐẶT TRƯỚC" badge was still intrinsic-width. Wrapping it
            // too lets the three children share the available width.
            Row(
              children: [
                const Flexible(
                  child: WgBadge(
                    label: 'ĐẶT TRƯỚC',
                    variant: WgBadgeVariant.shared,
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: WgStatusBadge(label: trip.statusLabel, tone: _tone),
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Text(
                      trip.scheduledAtVN,
                      style: AppTypography.micro.copyWith(
                        color: AppColors.ink500,
                      ),
                      maxLines: 1,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              '${trip.pickup.name} → ${trip.dropoff.name}',
              style: AppTypography.body.copyWith(
                color: AppColors.ink900,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 10),
            const Divider(height: 1, color: AppColors.ink100),
            const SizedBox(height: 10),
            Row(
              children: [
                Text(
                  trip.tripCode,
                  style: AppTypography.caption.copyWith(
                    color: AppColors.ink500,
                    fontFamily: 'monospace',
                  ),
                ),
                const Spacer(),
                Text(
                  formatVnd(trip.estimatedFare),
                  style: AppTypography.bodyLarge.copyWith(
                    color: AppColors.primary500,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
