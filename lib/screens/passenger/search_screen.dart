import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/geohash_util.dart';
import '../../core/utils/vietnamese_text_controller.dart';
import '../../core/widgets/wg_toast.dart';
import '../../data/default_saved_places.dart';
import '../../models/place.dart';
import '../../providers/location_provider.dart';
import '../../providers/places_provider.dart';
import '../../providers/recent_destinations_provider.dart';
import '../../providers/selected_destination_provider.dart';
import '../../services/places_service.dart';
import '_widgets/place_list_item.dart';
import '_widgets/route_input_card.dart';

class PassengerSearchScreen extends ConsumerStatefulWidget {
  const PassengerSearchScreen({super.key});

  @override
  ConsumerState<PassengerSearchScreen> createState() =>
      _PassengerSearchScreenState();
}

class _PassengerSearchScreenState extends ConsumerState<PassengerSearchScreen> {
  final _dropoffCtrl = VietnameseTextController();
  Timer? _debounce;
  List<PlaceSuggestion> _apiSuggestions = const [];
  bool _apiLoading = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _dropoffCtrl.dispose();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    // 600ms (vs 300ms before) gives Vietnamese IMEs enough time to
    // finalize composing diacritics before we read the controller text.
    _debounce = Timer(const Duration(milliseconds: 600), () async {
      if (!mounted) return;
      final query = _dropoffCtrl.committedText.trim();
      ref.read(searchQueryProvider.notifier).setQuery(query);
      if (query.length < 2) {
        setState(() => _apiSuggestions = const []);
        return;
      }
      setState(() => _apiLoading = true);
      final list = await PlacesService.autocomplete(query);
      if (!mounted) return;
      setState(() {
        _apiSuggestions = list;
        _apiLoading = false;
      });
    });
  }

  Future<void> _select(Place place) async {
    await ref.read(recentDestinationsProvider.notifier).add(place);
    ref.read(selectedDestinationProvider.notifier).set(place);
    ref.read(searchQueryProvider.notifier).clear();
    if (!mounted) return;
    context.pop(place);
  }

  Future<void> _openMapPicker() async {
    final picked = await context.push<Place>('/passenger/map-picker');
    if (picked == null || !mounted) return;
    await _select(picked);
  }

  Future<void> _selectSuggestion(PlaceSuggestion s) async {
    setState(() => _apiLoading = true);
    final details = await PlacesService.getDetails(s.placeId);
    if (!mounted) return;
    setState(() => _apiLoading = false);
    if (details == null) {
      WgToast.error(context, 'Không lấy được thông tin địa điểm');
      return;
    }
    final place = Place(
      id: details.placeId,
      name: s.mainText.isNotEmpty ? s.mainText : details.name,
      address: details.address,
      lat: details.lat,
      lng: details.lng,
    );
    await _select(place);
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
          icon: const Icon(PhosphorIconsRegular.arrowLeft),
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
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Flexible(
                    child: _ActionChip(
                      icon: PhosphorIconsRegular.mapTrifold,
                      label: 'Chọn trên bản đồ',
                      color: AppColors.primary500,
                      onTap: _openMapPicker,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: _ActionChip(
                      icon: PhosphorIconsRegular.mapPinPlus,
                      label: 'Điểm dừng',
                      color: AppColors.ink500,
                      disabled: true,
                      onTap: () => WgToast.info(context, 'Đang phát triển'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Expanded(
              child: query.trim().isEmpty
                  ? _EmptyState(
                      recent: recentAsync.valueOrNull ?? const [],
                      onSelect: _select,
                      origin: origin,
                    )
                  : _CombinedResults(
                      query: query,
                      localResults: results,
                      apiSuggestions: _apiSuggestions,
                      apiLoading: _apiLoading,
                      origin: origin,
                      onLocalSelect: _select,
                      onApiSelect: _selectSuggestion,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ignore: unused_element
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
        const _SectionHeader(
          icon: PhosphorIconsFill.bookmarkSimple,
          iconColor: AppColors.primary500,
          title: 'Đã lưu',
        ),
        ...kDefaultSavedPlaces.map(
          (sp) => _SavedPlaceRow(savedPlace: sp, onSelect: onSelect),
        ),
        const SizedBox(height: 8),
        const _SectionHeader(
          icon: PhosphorIconsFill.clockCounterClockwise,
          iconColor: AppColors.ink500,
          title: 'Gần đây',
        ),
        if (recent.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.icon,
    required this.iconColor,
    required this.title,
  });

  final IconData icon;
  final Color iconColor;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: iconColor),
          const SizedBox(width: 6),
          Text(
            title,
            style: AppTypography.h3.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  const _ActionChip({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.disabled = false,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: disabled ? 0.5 : 1.0,
      child: Material(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.ink200, width: 1),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 16, color: color),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    label,
                    style: AppTypography.caption.copyWith(
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SavedPlaceRow extends ConsumerWidget {
  const _SavedPlaceRow({required this.savedPlace, required this.onSelect});

  final SavedPlace savedPlace;
  final ValueChanged<Place> onSelect;

  Color get _tint {
    switch (savedPlace.kind) {
      case SavedPlaceKind.home:
        return AppColors.primary500;
      case SavedPlaceKind.work:
        return AppColors.warning;
      case SavedPlaceKind.airport:
        return AppColors.sharedAccent;
      case SavedPlaceKind.city:
        return const Color(0xFF8B5CF6);
    }
  }

  IconData get _icon {
    switch (savedPlace.kind) {
      case SavedPlaceKind.home:
        return PhosphorIconsFill.house;
      case SavedPlaceKind.work:
        return PhosphorIconsFill.briefcase;
      case SavedPlaceKind.airport:
        return PhosphorIconsFill.airplane;
      case SavedPlaceKind.city:
        return PhosphorIconsFill.buildings;
    }
  }

  Future<void> _setupPersonal(BuildContext context) async {
    final picked = await context.push<Place>('/passenger/map-picker');
    if (picked == null || !context.mounted) return;
    // Phase 5C: persistence (saving Home/Work) is intentionally out of
    // scope — show a toast + treat the picked place as the dropoff so
    // the booking flow can continue.
    WgToast.success(context, 'Đã chọn ${savedPlace.label}: ${picked.name}');
    onSelect(picked);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final place = savedPlace.place;
    final hasPlace = place != null;
    return InkWell(
      onTap: hasPlace ? () => onSelect(place) : () => _setupPersonal(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _tint.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(_icon, color: _tint, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    savedPlace.label,
                    style: AppTypography.body.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.ink900,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    hasPlace ? place.address : 'Nhấn để cài đặt',
                    style: AppTypography.caption.copyWith(
                      color: hasPlace ? AppColors.ink500 : AppColors.primary500,
                      fontWeight: hasPlace ? FontWeight.w400 : FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              PhosphorIconsRegular.caretRight,
              size: 14,
              color: AppColors.ink400,
            ),
          ],
        ),
      ),
    );
  }
}

class _CombinedResults extends StatelessWidget {
  const _CombinedResults({
    required this.query,
    required this.localResults,
    required this.apiSuggestions,
    required this.apiLoading,
    required this.origin,
    required this.onLocalSelect,
    required this.onApiSelect,
  });

  final String query;
  final List<Place> localResults;
  final List<PlaceSuggestion> apiSuggestions;
  final bool apiLoading;
  final LatLng origin;
  final ValueChanged<Place> onLocalSelect;
  final ValueChanged<PlaceSuggestion> onApiSelect;

  @override
  Widget build(BuildContext context) {
    if (localResults.isEmpty && apiSuggestions.isEmpty && !apiLoading) {
      return _NoResults(query: query);
    }
    return ListView(
      padding: const EdgeInsets.only(top: 4, bottom: 24),
      children: [
        if (localResults.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
            child: Text(
              'Gợi ý nhanh',
              style: AppTypography.caption.copyWith(
                color: AppColors.ink500,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          ...localResults.map((p) {
            final dist = GeohashUtil.distanceKm(
              origin.latitude,
              origin.longitude,
              p.lat,
              p.lng,
            );
            return PlaceListItem(
              place: p,
              distanceKm: dist,
              onTap: () => onLocalSelect(p),
            );
          }),
        ],
        if (apiLoading || apiSuggestions.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Row(
              children: [
                Text(
                  'Tìm trên Google Maps',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.ink500,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (apiLoading) ...[
                  const SizedBox(width: 8),
                  const SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(strokeWidth: 1.5),
                  ),
                ],
              ],
            ),
          ),
        ...apiSuggestions.map(
          (s) => _ApiSuggestionRow(suggestion: s, onTap: () => onApiSelect(s)),
        ),
      ],
    );
  }
}

class _ApiSuggestionRow extends StatelessWidget {
  const _ApiSuggestionRow({required this.suggestion, required this.onTap});

  final PlaceSuggestion suggestion;
  final VoidCallback onTap;

  String _formatDistance(int meters) {
    if (meters < 1000) return '$meters m';
    return '${(meters / 1000).toStringAsFixed(1)} km';
  }

  @override
  Widget build(BuildContext context) {
    final tint = suggestion.displayIconColor;
    final distance = suggestion.distanceMeters;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: tint.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(suggestion.displayIcon, color: tint, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    suggestion.mainText,
                    style: AppTypography.body.copyWith(
                      color: AppColors.ink900,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (suggestion.secondaryText.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      suggestion.secondaryText,
                      style: AppTypography.caption.copyWith(
                        color: AppColors.ink500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            if (distance != null) ...[
              const SizedBox(width: 8),
              Text(
                _formatDistance(distance),
                style: AppTypography.caption.copyWith(
                  color: AppColors.ink500,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ],
        ),
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
            const Icon(
              PhosphorIconsRegular.magnifyingGlassMinus,
              color: AppColors.ink300,
              size: 64,
            ),
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
