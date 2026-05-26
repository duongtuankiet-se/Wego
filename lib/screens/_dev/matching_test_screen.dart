import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mongo_dart/mongo_dart.dart' show ObjectId, where;
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/geohash_util.dart';
import '../../core/widgets/wg_button.dart';
import '../../data/mock_drivers.dart';
import '../../models/place.dart';
import '../../models/trip.dart';
import '../../providers/mongo_provider.dart';
import '../../providers/trip_service_provider.dart';

/// Dev-only screen for poking the matching engine in isolation.
/// Routed at /dev/matching-test (debug builds).
class MatchingTestScreen extends ConsumerStatefulWidget {
  const MatchingTestScreen({super.key});
  @override
  ConsumerState<MatchingTestScreen> createState() => _MatchingTestScreenState();
}

class _MatchingTestScreenState extends ConsumerState<MatchingTestScreen> {
  final _log = <String>[];
  bool _busy = false;
  final _rng = math.Random(42);

  // 5 random driver positions inside Đà Nẵng bounds.
  static const _danangBounds = (
    minLat: 15.95,
    maxLat: 16.12,
    minLng: 108.13,
    maxLng: 108.30,
  );

  // Test pickups.
  static const _pickupCauRong = (lat: 16.0612, lng: 108.2272, name: 'Cầu Rồng');
  static const _pickupSanBay = (lat: 16.0439, lng: 108.1995, name: 'Sân bay');
  static const _dropTranPhu = (lat: 16.0703, lng: 108.2244, name: 'Chợ Hàn');

  void _log_(String line) {
    setState(() => _log.insert(0, '${_ts()} · $line'));
  }

  String _ts() {
    final n = DateTime.now();
    return '${n.minute.toString().padLeft(2, '0')}:${n.second.toString().padLeft(2, '0')}';
  }

  Future<void> _wrap(Future<void> Function() job, String label) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await job();
    } catch (e) {
      _log_('✗ $label: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _seedDrivers() async {
    final mongo = ref.read(mongoServiceProvider);
    final drivers = await mongo.drivers();
    final names = const [
      'Nguyễn Văn 5A',
      'Lê Văn 5B',
      'Trần Thị 5C',
      'Phạm Minh 5D',
      'Hoàng Đức 5E',
    ];
    final now = DateTime.now().toUtc();
    var inserted = 0;
    for (var i = 0; i < 5; i++) {
      final lat =
          _danangBounds.minLat +
          _rng.nextDouble() * (_danangBounds.maxLat - _danangBounds.minLat);
      final lng =
          _danangBounds.minLng +
          _rng.nextDouble() * (_danangBounds.maxLng - _danangBounds.minLng);
      final phone = '+8490666${1000 + i}';
      final existing = await drivers.findOne(where.eq('phone', phone));
      if (existing != null) continue;
      await drivers.insertOne(<String, dynamic>{
        '_id': ObjectId(),
        'user_id': ObjectId(),
        'name': names[i],
        'phone': phone,
        'vehicle_model': 'Demo Car',
        'vehicle_color': 'Trắng',
        'vehicle_plate': '43D-${100 + i}.${10 + i}',
        'rating_avg': 4.5 + _rng.nextDouble() * 0.5,
        'total_trips': _rng.nextInt(500),
        'status': 'online',
        'current_lat': lat,
        'current_lng': lng,
        'current_geohash': GeohashUtil.encode(lat, lng),
        'created_at': now,
        'updated_at': now,
      });
      inserted++;
    }
    _log_('✓ Seeded $inserted/5 demo drivers (existing ones kept)');
  }

  Future<void> _testNearest() async {
    final svc = ref.read(tripServiceProvider);
    final result = await svc.findNearestDriver(
      pickupLat: _pickupCauRong.lat,
      pickupLng: _pickupCauRong.lng,
    );
    if (result == null) {
      _log_('✗ No driver found for ${_pickupCauRong.name}');
      return;
    }
    final dist = GeohashUtil.distanceKm(
      _pickupCauRong.lat,
      _pickupCauRong.lng,
      (result['current_lat'] as num).toDouble(),
      (result['current_lng'] as num).toDouble(),
    );
    _log_(
      '✓ Nearest to ${_pickupCauRong.name}: ${result['name']} '
      '(${dist.toStringAsFixed(2)} km)',
    );
  }

  Future<void> _createPendingTrip() async {
    final svc = ref.read(tripServiceProvider);
    // Use one of the mock-driver user_ids if available, else fabricate.
    final mongo = ref.read(mongoServiceProvider);
    final drivers = await mongo.drivers();
    final firstDriver = await drivers.findOne(
      where.eq('phone', kMockDrivers.first.phone),
    );
    final pseudoPassenger =
        (firstDriver?['user_id'] as ObjectId?)?.oid ?? ObjectId().oid;
    final tripId = await svc.insertPendingTrip(
      passengerId: pseudoPassenger,
      pickup: Place(
        id: 'dev_pk',
        name: _pickupSanBay.name,
        address: _pickupSanBay.name,
        lat: _pickupSanBay.lat,
        lng: _pickupSanBay.lng,
      ),
      dropoff: Place(
        id: 'dev_dr',
        name: _dropTranPhu.name,
        address: _dropTranPhu.name,
        lat: _dropTranPhu.lat,
        lng: _dropTranPhu.lng,
      ),
      type: TripType.shared,
      price: 78000,
      distanceKm: 8.4,
      durationMin: 22,
    );
    _log_(
      '✓ Pending trip ${tripId.substring(tripId.length - 6)} '
      'inserted (Sân bay → Chợ Hàn, shared)',
    );
  }

  Future<void> _testCarpool() async {
    final svc = ref.read(tripServiceProvider);
    // Find pending shared trips near Sân bay heading downtown.
    final result = await svc.findCarpoolMatch(
      pickupLat: _pickupSanBay.lat + 0.001,
      pickupLng: _pickupSanBay.lng + 0.001,
      dropoffLat: _dropTranPhu.lat + 0.002,
      dropoffLng: _dropTranPhu.lng + 0.002,
      currentPassengerId: ObjectId().oid,
    );
    if (result == null) {
      _log_('· No carpool match (try Create Pending first)');
      return;
    }
    _log_(
      '✓ Matched trip ${(result['_id'] as ObjectId).oid.substring(20)} '
      '(${result['pickup_address']} → ${result['dropoff_address']})',
    );
  }

  Future<void> _resetMatchingData() async {
    final mongo = ref.read(mongoServiceProvider);
    final trips = await mongo.trips();
    final pendingDel = await trips.deleteMany(
      where.oneFrom('status', ['pending', 'matching']),
    );
    final drivers = await mongo.drivers();
    // Remove demo+ drivers (keep 3 mock + user-driver records).
    final demoDel = await drivers.deleteMany(
      where.raw({
        'phone': {r'$regex': r'^\+8490666'},
      }),
    );
    _log_(
      '✓ Cleared ${pendingDel.nRemoved} pending trips, '
      '${demoDel.nRemoved} demo drivers',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.offWhite,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(PhosphorIconsRegular.arrowLeft),
          onPressed: () => context.pop(),
        ),
        title: const Text('Matching Engine Test'),
        actions: [
          IconButton(
            tooltip: 'Xoá log',
            onPressed: () => setState(_log.clear),
            icon: const Icon(PhosphorIconsRegular.broom),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Các nút sau gọi trực tiếp matching engine trên MongoDB Atlas. '
            'Kết quả hiện ngay dưới.',
            style: AppTypography.body.copyWith(color: AppColors.ink500),
          ),
          const SizedBox(height: 16),
          _btn(
            '1. Seed 5 drivers online ngẫu nhiên ở Đà Nẵng',
            PhosphorIconsRegular.mapPinPlus,
            () => _wrap(_seedDrivers, 'seedDrivers'),
          ),
          _btn(
            '2. Tìm driver gần Cầu Rồng nhất',
            PhosphorIconsFill.navigationArrow,
            () => _wrap(_testNearest, 'findNearestDriver'),
          ),
          _btn(
            '3. Tạo 1 trip pending (Sân bay → Chợ Hàn, shared)',
            PhosphorIconsRegular.notePencil,
            () => _wrap(_createPendingTrip, 'insertPendingTrip'),
          ),
          _btn(
            '4. Tìm carpool match cho pickup gần Sân bay',
            PhosphorIconsFill.usersThree,
            () => _wrap(_testCarpool, 'findCarpoolMatch'),
          ),
          _btn(
            '5. Reset: xoá pending trips + 5 demo drivers',
            PhosphorIconsRegular.arrowsClockwise,
            () => _wrap(_resetMatchingData, 'reset'),
            warning: true,
          ),
          const SizedBox(height: 20),
          Text(
            'Log',
            style: AppTypography.bodyLarge.copyWith(
              color: AppColors.ink900,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.ink900,
              borderRadius: BorderRadius.circular(14),
            ),
            child: _log.isEmpty
                ? Text(
                    '— Chưa có log —',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.ink300,
                    ),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: _log
                        .map(
                          (l) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Text(
                              l,
                              style: AppTypography.caption.copyWith(
                                color: AppColors.white,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _btn(
    String label,
    IconData icon,
    VoidCallback onTap, {
    bool warning = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: warning
          ? WgButton.secondary(
              label: label,
              isFullWidth: true,
              isLoading: _busy,
              leadingIcon: icon,
              onPressed: _busy ? null : onTap,
            )
          : WgButton.primary(
              label: label,
              isFullWidth: true,
              isLoading: _busy,
              leadingIcon: icon,
              onPressed: _busy ? null : onTap,
            ),
    );
  }
}
