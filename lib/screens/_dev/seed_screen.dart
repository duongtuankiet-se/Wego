import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mongo_dart/mongo_dart.dart' show ObjectId, where;
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/wg_button.dart';
import '../../core/widgets/wg_toast.dart';
import '../../data/mock_drivers.dart';
import '../../providers/mongo_provider.dart';

/// Dev tool to wipe trips/ratings + user-bound drivers and reset the
/// app to a clean demo state. Keeps the 3 seed mock drivers so passenger
/// flow still works on a fresh run.
class SeedScreen extends ConsumerStatefulWidget {
  const SeedScreen({super.key});
  @override
  ConsumerState<SeedScreen> createState() => _SeedScreenState();
}

class _SeedScreenState extends ConsumerState<SeedScreen> {
  final _log = <String>[];
  bool _busy = false;

  void _log_(String line) {
    setState(() => _log.insert(0, line));
  }

  Future<void> _reset() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _log.clear();
    });
    try {
      final mongo = ref.read(mongoServiceProvider);

      // 1. Drop trips + ratings entirely.
      final trips = await mongo.trips();
      final tripsDel = await trips.deleteMany(where.raw(<String, dynamic>{}));
      _log_('✓ Trips: ${tripsDel.nRemoved} doc xoá');

      final ratings = await mongo.ratings();
      final ratingsDel = await ratings.deleteMany(
        where.raw(<String, dynamic>{}),
      );
      _log_('✓ Ratings: ${ratingsDel.nRemoved} doc xoá');

      // 2. Drivers: keep the 3 seed phones, drop everything else.
      final drivers = await mongo.drivers();
      final keepPhones = kMockDrivers.map((d) => d.phone).toList();
      final driverDel = await drivers.deleteMany(
        where.raw(<String, dynamic>{
          'phone': {r'$nin': keepPhones},
        }),
      );
      _log_(
        '✓ Drivers: xoá ${driverDel.nRemoved} '
        '(giữ ${keepPhones.length} mock)',
      );

      // 3. Users: drop everyone (passenger + driver users). Seed mock
      // drivers don't have matching users; user-drivers will re-create
      // on next login.
      final users = await mongo.users();
      final usersDel = await users.deleteMany(where.raw(<String, dynamic>{}));
      _log_('✓ Users: ${usersDel.nRemoved} doc xoá');

      // 4. Re-seed the 3 mock drivers if missing (idempotent — Phase 1B
      // pattern: insertOne if not exists).
      var seeded = 0;
      final now = DateTime.now().toUtc();
      for (final mock in kMockDrivers) {
        final exists = await drivers.findOne(where.eq('phone', mock.phone));
        if (exists != null) continue;
        // Random offset around Đà Nẵng center for the seed position.
        const cLat = 16.0544;
        const cLng = 108.2022;
        final lat = cLat + mock.latOffset * 5;
        final lng = cLng + mock.lngOffset * 5;
        await drivers.insertOne(<String, dynamic>{
          '_id': ObjectId(),
          'user_id': ObjectId(),
          'name': mock.name,
          'phone': mock.phone,
          'vehicle_model': mock.vehicleModel,
          'vehicle_color': mock.vehicleColor,
          'vehicle_plate': mock.vehiclePlate,
          'rating_avg': mock.rating,
          'total_trips': mock.totalTrips,
          'status': 'online',
          'current_lat': lat,
          'current_lng': lng,
          'current_geohash': '',
          'created_at': now,
          'updated_at': now,
        });
        seeded++;
      }
      _log_('✓ Re-seed $seeded/3 mock drivers');

      // 5. Clear shared_preferences (logout).
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      _log_('✓ Đã đăng xuất khỏi thiết bị');

      if (!mounted) return;
      WgToast.success(context, 'Demo data đã reset xong!');
      await Future.delayed(const Duration(milliseconds: 800));
      if (!mounted) return;
      context.go('/role-select');
    } catch (e) {
      _log_('✗ Lỗi: $e');
      if (mounted) WgToast.error(context, 'Reset thất bại');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.offWhite,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: const Text('Seed demo data'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: AppColors.warning.withValues(alpha: 0.4),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    color: AppColors.warning,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Nút này xoá toàn bộ trips + ratings + users, '
                      'giữ 3 mock drivers. Bạn sẽ bị đăng xuất.',
                      style: AppTypography.body.copyWith(
                        color: AppColors.ink900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            WgButton.primary(
              label: 'Reset toàn bộ về initial state',
              size: WgButtonSize.lg,
              isFullWidth: true,
              isLoading: _busy,
              leadingIcon: Icons.restart_alt,
              onPressed: _busy ? null : _reset,
            ),
            const SizedBox(height: 24),
            Text(
              'Log',
              style: AppTypography.bodyLarge.copyWith(
                color: AppColors.ink900,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.ink900,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: SingleChildScrollView(
                  child: _log.isEmpty
                      ? Text(
                          '— Chưa chạy —',
                          style: AppTypography.caption.copyWith(
                            color: AppColors.ink300,
                          ),
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: _log
                              .map(
                                (l) => Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 2,
                                  ),
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
              ),
            ),
          ],
        ),
      ),
    );
  }
}
