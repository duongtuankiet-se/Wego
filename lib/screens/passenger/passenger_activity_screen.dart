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
import '../../providers/auth_provider.dart';
import '../../providers/mongo_provider.dart';

part 'passenger_activity_screen.g.dart';

class _ActivityTrip {
  final String id;
  final String type; // shared/private
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

class PassengerActivityScreen extends ConsumerStatefulWidget {
  const PassengerActivityScreen({super.key});
  @override
  ConsumerState<PassengerActivityScreen> createState() =>
      _PassengerActivityScreenState();
}

class _PassengerActivityScreenState
    extends ConsumerState<PassengerActivityScreen> {
  String _filter = 'all'; // all / completed / cancelled

  @override
  Widget build(BuildContext context) {
    final tripsAsync = ref.watch(passengerTripsProvider);

    return Scaffold(
      backgroundColor: AppColors.offWhite,
      appBar: AppBar(title: const Text('Hoạt động')),
      body: Column(
        children: [
          _FilterChips(
            current: _filter,
            onChange: (v) => setState(() => _filter = v),
          ),
          Expanded(
            child: tripsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, _) => WgErrorState(
                title: 'Không tải được lịch sử',
                onRetry: () => ref.invalidate(passengerTripsProvider),
              ),
              data: (all) {
                final list = all.where((t) {
                  if (_filter == 'all') return true;
                  return t.status == _filter;
                }).toList();
                if (list.isEmpty) {
                  return WgEmptyState(
                    icon: PhosphorIconsRegular.car,
                    title: 'Chưa có chuyến đi nào',
                    subtitle: 'Đặt chuyến đầu tiên để bắt đầu hành trình.',
                    ctaLabel: 'Đặt xe ngay',
                    onCta: () => context.go('/passenger/home'),
                  );
                }
                return _TripList(items: list);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChips extends StatelessWidget {
  const _FilterChips({required this.current, required this.onChange});
  final String current;
  final ValueChanged<String> onChange;

  static const _options = [
    ('all', 'Tất cả'),
    ('completed', 'Hoàn thành'),
    ('cancelled', 'Đã huỷ'),
  ];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        children: _options.map((o) {
          final active = o.$1 == current;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(o.$2),
              selected: active,
              onSelected: (_) => onChange(o.$1),
              selectedColor: AppColors.primary500,
              backgroundColor: AppColors.white,
              labelStyle: TextStyle(
                color: active ? Colors.white : AppColors.ink700,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(999)),
                side: BorderSide(color: AppColors.ink200),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _TripList extends StatelessWidget {
  const _TripList({required this.items});
  final List<_ActivityTrip> items;

  Map<String, List<_ActivityTrip>> _groupByDate() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final out = <String, List<_ActivityTrip>>{};
    for (final t in items) {
      final d = DateTime(t.createdAt.year, t.createdAt.month, t.createdAt.day);
      final key = d == today
          ? 'Hôm nay'
          : d == yesterday
          ? 'Hôm qua'
          : '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
      out.putIfAbsent(key, () => []).add(t);
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final groups = _groupByDate();
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      children: groups.entries.expand((e) {
        return [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 14, 8, 8),
            child: Text(
              e.key,
              style: AppTypography.caption.copyWith(
                color: AppColors.ink500,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          ...e.value.map((t) => _TripCard(trip: t)),
        ];
      }).toList(),
    );
  }
}

class _TripCard extends StatelessWidget {
  const _TripCard({required this.trip});
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
                const WgBadge(label: 'ĐÃ HUỶ', variant: WgBadgeVariant.surge),
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
                    Container(width: 1.5, height: 24, color: AppColors.ink300),
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
              Text(
                isCompleted
                    ? 'Đã hoàn thành'
                    : (isCancelled ? 'Đã huỷ' : 'Đang xử lý'),
                style: AppTypography.caption.copyWith(color: AppColors.ink500),
              ),
              const Spacer(),
              Text(
                formatVnd(trip.price),
                style: AppTypography.bodyLarge.copyWith(
                  color: AppColors.primary500,
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
