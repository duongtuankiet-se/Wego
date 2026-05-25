import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:latlong2/latlong.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/geohash_util.dart';
import '../../core/widgets/wg_chip.dart';
import '../../core/widgets/wg_toast.dart';
import '../../models/place.dart';
import '../../providers/location_provider.dart';
import '../../providers/places_provider.dart';
import '../../providers/recent_destinations_provider.dart';
import '../../providers/selected_destination_provider.dart';
import '_widgets/place_list_item.dart';
import '_widgets/route_input_card.dart';

class PassengerSearchScreen extends ConsumerStatefulWidget {
  const PassengerSearchScreen({super.key});

  @override
  ConsumerState<PassengerSearchScreen> createState() =>
      _PassengerSearchScreenState();
}

class _PassengerSearchScreenState extends ConsumerState<PassengerSearchScreen> {
  final _dropoffCtrl = TextEditingController();
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _dropoffCtrl.dispose();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 200), () {
      if (!mounted) return;
      ref.read(searchQueryProvider.notifier).setQuery(value);
    });
  }

  Future<void> _select(Place place) async {
    await ref.read(recentDestinationsProvider.notifier).add(place);
    ref.read(selectedDestinationProvider.notifier).set(place);
    ref.read(searchQueryProvider.notifier).clear();
    if (!mounted) return;
    context.pop(place);
  }

  @override
  Widget build(BuildContext context) {
    final query = ref.watch(searchQueryProvider);
    final results = ref.watch(filteredPlacesProvider);
    final currentLocAsync = ref.watch(currentLocationProvider);
    final recentAsync = ref.watch(recentDestinationsProvider);
    final origin = currentLocAsync.valueOrNull ?? kDanangFallback;

    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: const Text('Đi đâu?'),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            const Divider(height: 1, color: AppColors.ink100),
            RouteInputCard(
              pickupLabel: 'Vị trí hiện tại',
              dropoffController: _dropoffCtrl,
              onDropoffChanged: _onQueryChanged,
              onPickupTap: () =>
                  WgToast.info(context, 'Đổi điểm đón sẽ có ở phiên bản sau'),
            ),
            const Divider(height: 1, color: AppColors.ink100),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  WgChip(
                    label: 'Chọn trên bản đồ',
                    leadingIcon: Icons.map_outlined,
                    onTap: () => WgToast.info(context, 'Đang phát triển'),
                  ),
                  const SizedBox(width: 12),
                  Opacity(
                    opacity: 0.5,
                    child: WgChip(
                      label: 'Thêm điểm dừng',
                      leadingIcon: Icons.add_location_alt_outlined,
                      onTap: null,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: query.trim().isEmpty
                  ? _EmptyState(
                      recent: recentAsync.valueOrNull ?? const [],
                      onSelect: _select,
                      origin: origin,
                    )
                  : results.isEmpty
                  ? _NoResults(query: query)
                  : _ResultsList(
                      results: results,
                      origin: origin,
                      onSelect: _select,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResultsList extends StatelessWidget {
  const _ResultsList({
    required this.results,
    required this.origin,
    required this.onSelect,
  });

  final List<Place> results;
  final LatLng origin;
  final ValueChanged<Place> onSelect;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.only(top: 4, bottom: 24),
      itemCount: results.length,
      separatorBuilder: (_, _) => const Padding(
        padding: EdgeInsets.only(left: 76),
        child: Divider(height: 1, color: AppColors.ink100),
      ),
      itemBuilder: (context, i) {
        final p = results[i];
        final dist = GeohashUtil.distanceKm(
          origin.latitude,
          origin.longitude,
          p.lat,
          p.lng,
        );
        return _StaggerFadeIn(
          delay: Duration(milliseconds: 30 * i),
          child: PlaceListItem(
            place: p,
            distanceKm: dist,
            onTap: () => onSelect(p),
          ),
        );
      },
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.recent,
    required this.onSelect,
    required this.origin,
  });

  final List<Place> recent;
  final ValueChanged<Place> onSelect;
  final LatLng origin;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
          child: Text(
            'Đã lưu',
            style: AppTypography.bodyLarge.copyWith(color: AppColors.ink900),
          ),
        ),
        _SavedRow(
          icon: Icons.home_outlined,
          title: 'Nhà',
          subtitle: 'Chưa cài đặt',
          actionLabel: 'Thêm',
          onAction: () => _hint(context),
        ),
        _SavedRow(
          icon: Icons.business_outlined,
          title: 'Công ty',
          subtitle: 'Chưa cài đặt',
          actionLabel: 'Thêm',
          onAction: () => _hint(context),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
          child: Text(
            'Gần đây',
            style: AppTypography.bodyLarge.copyWith(color: AppColors.ink900),
          ),
        ),
        if (recent.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Text(
              'Chưa có lịch sử. Đặt chuyến đầu tiên để lưu nhé.',
              style: AppTypography.body.copyWith(color: AppColors.ink500),
            ),
          )
        else
          ...recent.map((p) {
            final dist = GeohashUtil.distanceKm(
              origin.latitude,
              origin.longitude,
              p.lat,
              p.lng,
            );
            return PlaceListItem(
              place: p,
              distanceKm: dist,
              onTap: () => onSelect(p),
            );
          }),
      ],
    );
  }

  void _hint(BuildContext context) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Tính năng đang phát triển'),
        duration: Duration(seconds: 2),
      ),
    );
  }
}

class _SavedRow extends StatelessWidget {
  const _SavedRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    required this.onAction,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.primary50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppColors.primary700, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTypography.body.copyWith(
                    color: AppColors.ink900,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  subtitle,
                  style: AppTypography.caption.copyWith(
                    color: AppColors.ink500,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: onAction,
            child: Text(
              actionLabel,
              style: AppTypography.body.copyWith(
                color: AppColors.primary500,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NoResults extends StatelessWidget {
  const _NoResults({required this.query});
  final String query;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.search_off, color: AppColors.ink300, size: 64),
            const SizedBox(height: 16),
            Text(
              'Không tìm thấy "${query.trim()}"',
              style: AppTypography.body.copyWith(color: AppColors.ink500),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              'Thử từ khóa khác',
              style: AppTypography.caption.copyWith(color: AppColors.ink500),
            ),
          ],
        ),
      ),
    );
  }
}

class _StaggerFadeIn extends StatefulWidget {
  const _StaggerFadeIn({required this.delay, required this.child});
  final Duration delay;
  final Widget child;

  @override
  State<_StaggerFadeIn> createState() => _StaggerFadeInState();
}

class _StaggerFadeInState extends State<_StaggerFadeIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    Future.delayed(widget.delay, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _controller,
      child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero)
            .animate(
              CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
            ),
        child: widget.child,
      ),
    );
  }
}
