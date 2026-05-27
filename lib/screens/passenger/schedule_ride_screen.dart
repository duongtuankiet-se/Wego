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
import '../../core/widgets/wg_toast.dart';
import '../../models/place.dart';
import '../../models/scheduled_trip.dart';
import '../../providers/auth_provider.dart';
import '../../providers/scheduled_trips_provider.dart';
import '../../providers/selected_destination_provider.dart';

class ScheduleRideScreen extends ConsumerStatefulWidget {
  const ScheduleRideScreen({super.key});

  @override
  ConsumerState<ScheduleRideScreen> createState() => _ScheduleRideScreenState();
}

class _ScheduleRideScreenState extends ConsumerState<ScheduleRideScreen> {
  final _noteCtrl = TextEditingController();
  final _promoCtrl = TextEditingController();
  bool _booking = false;

  @override
  void initState() {
    super.initState();
    // Reset the form on each fresh entry so we never resurrect stale
    // values from a previously-cancelled booking attempt.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(scheduleRideFormProvider.notifier).reset();
      _noteCtrl.clear();
      _promoCtrl.clear();
    });
  }

  @override
  void dispose() {
    _noteCtrl.dispose();
    _promoCtrl.dispose();
    super.dispose();
  }

  ScheduledTripLocation _placeToLocation(Place p) => ScheduledTripLocation(
    name: p.name,
    address: p.address,
    lat: p.lat,
    lng: p.lng,
  );

  Future<void> _pickPickup() async {
    final picked = await context.push<Place>(
      '/passenger/map-picker?mode=pickup',
    );
    if (picked == null) return;
    ref
        .read(scheduleRideFormProvider.notifier)
        .setPickup(_placeToLocation(picked));
  }

  Future<void> _pickDropoff() async {
    final picked = await context.push<Place>('/passenger/search');
    if (picked == null) return;
    // Search screen sets [selectedDestinationProvider] as a side-effect;
    // clear it so it doesn't leak into a later "Đặt ngay" flow.
    ref.read(selectedDestinationProvider.notifier).clear();
    ref
        .read(scheduleRideFormProvider.notifier)
        .setDropoff(_placeToLocation(picked));
  }

  Future<void> _showDateTimePicker() async {
    final form = ref.read(scheduleRideFormProvider);
    final now = DateTime.now();
    final initial = form.scheduledAt ?? now.add(const Duration(hours: 1));

    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: now,
      lastDate: now.add(const Duration(days: 7)),
      locale: const Locale('vi'),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
            primary: AppColors.primary500,
            onPrimary: AppColors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(primary: AppColors.primary500),
        ),
        child: MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: child!,
        ),
      ),
    );
    if (time == null || !mounted) return;

    final dt = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    if (dt.difference(DateTime.now()).inMinutes < 30) {
      WgToast.error(context, 'Thời gian đón phải sau ít nhất 30 phút');
      return;
    }
    ref.read(scheduleRideFormProvider.notifier).setScheduledAt(dt);
  }

  Future<void> _showPassengerPicker() async {
    final form = ref.read(scheduleRideFormProvider);
    var count = form.passengerCount;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (sheetCtx, setSt) => Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              12,
              20,
              MediaQuery.of(sheetCtx).viewInsets.bottom + 20,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.ink300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                Text('Số hành khách', style: AppTypography.h2),
                const SizedBox(height: 4),
                Text(
                  'Tối đa 4 người mỗi chuyến',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.ink500,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _StepperButton(
                      icon: PhosphorIconsBold.minus,
                      onTap: count > 1 ? () => setSt(() => count--) : null,
                    ),
                    const SizedBox(width: 32),
                    Container(
                      width: 96,
                      height: 96,
                      decoration: const BoxDecoration(
                        color: AppColors.primary100,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          '$count',
                          style: const TextStyle(
                            fontSize: 44,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primary600,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 32),
                    _StepperButton(
                      icon: PhosphorIconsBold.plus,
                      onTap: count < 4 ? () => setSt(() => count++) : null,
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                if (count >= 3)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.sharedAccent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          PhosphorIconsFill.sparkle,
                          size: 18,
                          color: AppColors.sharedAccent,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Nhóm 3+ người: tự động giảm thêm 15%',
                            style: AppTypography.caption.copyWith(
                              color: AppColors.ink700,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 16),
                WgButton.primary(
                  label: 'Xác nhận',
                  onPressed: () {
                    ref
                        .read(scheduleRideFormProvider.notifier)
                        .setPassengerCount(count);
                    Navigator.pop(sheetCtx);
                  },
                  isFullWidth: true,
                  size: WgButtonSize.lg,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _applyPromo() {
    final code = _promoCtrl.text.trim();
    if (code.isEmpty) {
      ref.read(scheduleRideFormProvider.notifier).clearPromo();
      return;
    }
    final svc = ref.read(scheduledTripServiceProvider);
    final form = ref.read(scheduleRideFormProvider);
    final baseFare = form.baseFare > 0
        ? form.baseFare
        : svc.calcBaseFare(
            distanceKm: form.estimatedDistanceKm,
            rideType: form.rideType,
          );
    final result = svc.validatePromo(code: code, baseFare: baseFare);
    ref.read(scheduleRideFormProvider.notifier).setPromoResult(
          code: code.toUpperCase(),
          isValid: result.isValid,
          message: result.message,
          discount: result.discount,
        );
    if (result.isValid) {
      WgToast.success(context, result.message);
    } else {
      WgToast.error(context, result.message);
    }
  }

  Future<void> _book() async {
    final form = ref.read(scheduleRideFormProvider);

    if (form.pickup == null) {
      WgToast.error(context, 'Vui lòng chọn điểm đón');
      return;
    }
    if (form.dropoff == null) {
      WgToast.error(context, 'Vui lòng chọn điểm đến');
      return;
    }
    if (form.scheduledAt == null) {
      WgToast.error(context, 'Vui lòng chọn thời gian đón');
      return;
    }
    if (form.estimatedFare == 0) {
      WgToast.info(context, 'Đang tính giá, vui lòng đợi…');
      return;
    }

    final user = ref.read(authStateProvider).valueOrNull;
    if (user == null) {
      WgToast.error(context, 'Bạn cần đăng nhập để đặt chuyến');
      return;
    }

    setState(() => _booking = true);
    try {
      final svc = ref.read(scheduledTripServiceProvider);
      // Read note straight from the controller so we don't have to fire
      // a state update on every keystroke (see _buildNoteCard).
      final note = _noteCtrl.text.trim();
      final trip = await svc.createScheduledTrip(
        passengerId: user.id,
        pickup: form.pickup!,
        dropoff: form.dropoff!,
        scheduledAt: form.scheduledAt!,
        flexibleWindowMin: form.flexibleWindowMin,
        passengerCount: form.passengerCount,
        luggage: form.luggage,
        note: note.isEmpty ? null : note,
        rideType: form.rideType,
        allowPooling: form.allowPooling,
        recurrence: form.recurrence,
        paymentMethod: form.paymentMethod,
        promoCode: form.promoIsValid ? form.promoCode : null,
        estimatedDistanceKm: form.estimatedDistanceKm,
        estimatedDurationMin: form.estimatedDurationMin,
      );
      ref.invalidate(upcomingScheduledTripsProvider);
      if (!mounted) return;
      context.pushReplacement('/passenger/schedule-confirm/${trip.id}');
    } catch (e) {
      if (mounted) WgToast.error(context, 'Không tạo được chuyến: $e');
    } finally {
      if (mounted) setState(() => _booking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final form = ref.watch(scheduleRideFormProvider);

    return Scaffold(
      backgroundColor: AppColors.offWhite,
      appBar: AppBar(
        title: Text(
          'Đặt trước chuyến đi',
          style: AppTypography.h2.copyWith(fontWeight: FontWeight.w700),
        ),
        backgroundColor: AppColors.offWhite,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(PhosphorIconsRegular.arrowLeft),
          onPressed: () => context.pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          _buildLocationsCard(form),
          const SizedBox(height: 12),
          _buildDateTimeCard(form),
          const SizedBox(height: 12),
          _buildRideConfigCard(form),
          const SizedBox(height: 12),
          _buildPassengerLuggageRow(form),
          const SizedBox(height: 12),
          _buildNoteCard(form),
          const SizedBox(height: 12),
          _buildRecurrenceCard(form),
          const SizedBox(height: 12),
          _buildPaymentPromoCard(form),
          const SizedBox(height: 12),
          _buildFarePreviewCard(form),
        ],
      ),
      bottomNavigationBar: _buildBottomCta(form),
    );
  }

  // ── Sections ──────────────────────────────────────────────────────

  Widget _buildLocationsCard(ScheduleRideFormState form) {
    return _CardShell(
      child: Column(
        children: [
          _LocationRow(
            icon: PhosphorIconsFill.circle,
            iconColor: AppColors.success,
            label: 'Điểm đón',
            value: form.pickup?.name ?? 'Chọn điểm đón',
            address: form.pickup?.address,
            placeholder: form.pickup == null,
            onTap: _pickPickup,
          ),
          const Divider(height: 1, indent: 56, color: AppColors.ink100),
          _LocationRow(
            icon: PhosphorIconsFill.mapPin,
            iconColor: AppColors.danger,
            label: 'Điểm đến',
            value: form.dropoff?.name ?? 'Chọn điểm đến',
            address: form.dropoff?.address,
            placeholder: form.dropoff == null,
            onTap: _pickDropoff,
          ),
        ],
      ),
    );
  }

  Widget _buildDateTimeCard(ScheduleRideFormState form) {
    return _CardShell(
      title: 'Thời gian đón',
      icon: PhosphorIconsFill.clock,
      iconColor: AppColors.primary500,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _quickTimeChips(form),
          ),
          const SizedBox(height: 12),
          InkWell(
            onTap: _showDateTimePicker,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.ink50,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.ink200),
              ),
              child: Row(
                children: [
                  const Icon(
                    PhosphorIconsRegular.calendar,
                    size: 20,
                    color: AppColors.ink600,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      form.scheduledAt != null
                          ? _formatScheduledAt(form.scheduledAt!)
                          : 'Chọn ngày & giờ tùy chỉnh',
                      style: AppTypography.body.copyWith(
                        color: form.scheduledAt != null
                            ? AppColors.ink900
                            : AppColors.ink500,
                        fontWeight: form.scheduledAt != null
                            ? FontWeight.w600
                            : FontWeight.w400,
                      ),
                    ),
                  ),
                  const Icon(
                    PhosphorIconsRegular.caretRight,
                    size: 16,
                    color: AppColors.ink400,
                  ),
                ],
              ),
            ),
          ),
          if (form.scheduledAt != null) ...[
            const SizedBox(height: 16),
            Text(
              'Cho phép sớm/trễ:',
              style: AppTypography.caption.copyWith(color: AppColors.ink600),
            ),
            const SizedBox(height: 8),
            Row(
              children: [0, 15, 30].map((m) {
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: _SelectorPill(
                      label: m == 0 ? 'Đúng giờ' : '± $m phút',
                      selected: form.flexibleWindowMin == m,
                      onTap: () => ref
                          .read(scheduleRideFormProvider.notifier)
                          .setFlexibleWindow(m),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  List<Widget> _quickTimeChips(ScheduleRideFormState form) {
    final now = DateTime.now();
    final chips = <(String, DateTime)>[
      ('Sau 30 phút', now.add(const Duration(minutes: 30))),
      ('Sau 1 giờ', now.add(const Duration(hours: 1))),
      ('8h sáng mai', DateTime(now.year, now.month, now.day + 1, 8, 0)),
      ('12h trưa mai', DateTime(now.year, now.month, now.day + 1, 12, 0)),
    ];
    return chips.map((c) {
      final selected = form.scheduledAt != null &&
          form.scheduledAt!.difference(c.$2).inMinutes.abs() < 5;
      return _ChipPill(
        label: c.$1,
        selected: selected,
        onTap: () => ref
            .read(scheduleRideFormProvider.notifier)
            .setScheduledAt(c.$2),
      );
    }).toList(growable: false);
  }

  Widget _buildRideConfigCard(ScheduleRideFormState form) {
    return _CardShell(
      title: 'Loại xe',
      icon: PhosphorIconsFill.carProfile,
      iconColor: AppColors.primary500,
      child: Column(
        children: [
          _RideTypeOption(
            title: 'Xe ghép thông minh',
            subtitle: 'Tiết kiệm 38%, có thể đi cùng người khác',
            icon: PhosphorIconsFill.usersThree,
            iconColor: AppColors.sharedAccent,
            selected: form.rideType == 'shared',
            onTap: () => ref
                .read(scheduleRideFormProvider.notifier)
                .setRideType('shared'),
          ),
          const SizedBox(height: 8),
          _RideTypeOption(
            title: 'Xe riêng',
            subtitle: 'Đi thẳng tới nơi, không ghép khách',
            icon: PhosphorIconsFill.car,
            iconColor: AppColors.primary500,
            selected: form.rideType == 'private',
            onTap: () => ref
                .read(scheduleRideFormProvider.notifier)
                .setRideType('private'),
          ),
          if (form.rideType == 'shared') ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.sharedAccent.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(
                    PhosphorIconsFill.handshake,
                    size: 18,
                    color: AppColors.sharedAccent,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Cho phép ghép với hành khách khác',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.ink700,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Switch(
                    value: form.allowPooling,
                    onChanged: (v) => ref
                        .read(scheduleRideFormProvider.notifier)
                        .setAllowPooling(v),
                    activeTrackColor: AppColors.sharedAccent,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPassengerLuggageRow(ScheduleRideFormState form) {
    // IntrinsicHeight is required because ListView gives this Row
    // unbounded vertical space — without it, CrossAxisAlignment.stretch
    // assigns infinite height to the Expanded cards, which crashes the
    // Wrap inside the Luggage card with "RenderBox no size".
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: InkWell(
              onTap: _showPassengerPicker,
              borderRadius: AppRadius.card,
              child: _CardShell(
                title: 'Hành khách',
                icon: PhosphorIconsFill.user,
                iconColor: AppColors.primary500,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${form.passengerCount} người',
                      style: AppTypography.h3.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink900,
                      ),
                    ),
                    const Icon(
                      PhosphorIconsRegular.caretRight,
                      size: 16,
                      color: AppColors.ink400,
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _CardShell(
              title: 'Hành lý',
              icon: PhosphorIconsFill.suitcase,
              iconColor: AppColors.primary500,
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: LuggageType.values.map((l) {
                  return _SmallPill(
                    label: _luggageLabel(l),
                    selected: form.luggage == l,
                    onTap: () => ref
                        .read(scheduleRideFormProvider.notifier)
                        .setLuggage(l),
                  );
                }).toList(growable: false),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoteCard(ScheduleRideFormState form) {
    return _CardShell(
      title: 'Ghi chú cho tài xế',
      subtitle: 'Tùy chọn',
      icon: PhosphorIconsFill.note,
      iconColor: AppColors.primary500,
      child: TextField(
        controller: _noteCtrl,
        maxLines: 3,
        maxLength: 200,
        // VN IME hardening (Phase 5L): see WgInput for rationale.
        autocorrect: false,
        enableSuggestions: false,
        smartDashesType: SmartDashesType.disabled,
        smartQuotesType: SmartQuotesType.disabled,
        decoration: InputDecoration(
          hintText: 'VD: Trước cổng số 5, có 1 vali lớn',
          counterText: '',
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.ink200),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.ink200),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.primary500),
          ),
        ),
        // Note: no per-keystroke setNote call — the controller text is
        // read directly inside _book(). Was the dominant source of lag,
        // since every keystroke rebuilt the whole ListView of 9 cards.
      ),
    );
  }

  Widget _buildRecurrenceCard(ScheduleRideFormState form) {
    return _CardShell(
      title: 'Lặp lại',
      subtitle: 'Đi đều đặn theo lịch',
      icon: PhosphorIconsFill.repeat,
      iconColor: AppColors.primary500,
      child: Row(
        children: RecurrenceType.values.map((r) {
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: _SelectorPill(
                label: _recurrenceLabel(r),
                selected: form.recurrence == r,
                onTap: () => ref
                    .read(scheduleRideFormProvider.notifier)
                    .setRecurrence(r),
              ),
            ),
          );
        }).toList(growable: false),
      ),
    );
  }

  Widget _buildPaymentPromoCard(ScheduleRideFormState form) {
    return _CardShell(
      title: 'Thanh toán & khuyến mãi',
      icon: PhosphorIconsFill.wallet,
      iconColor: AppColors.primary500,
      child: Column(
        children: [
          ...SchedulePaymentMethod.values.map((m) => RadioListTile<SchedulePaymentMethod>(
                value: m,
                groupValue: form.paymentMethod,
                onChanged: (v) {
                  if (v == null) return;
                  ref
                      .read(scheduleRideFormProvider.notifier)
                      .setPaymentMethod(v);
                },
                title: Row(
                  children: [
                    Icon(_paymentIcon(m), size: 20, color: _paymentColor(m)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _paymentLabel(m),
                        style: AppTypography.body.copyWith(
                          color: AppColors.ink900,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                contentPadding: EdgeInsets.zero,
                activeColor: AppColors.primary500,
                dense: true,
              )),
          const Divider(height: 16, color: AppColors.ink100),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _promoCtrl,
                  textCapitalization: TextCapitalization.characters,
                  autocorrect: false,
                  enableSuggestions: false,
                  smartDashesType: SmartDashesType.disabled,
                  smartQuotesType: SmartQuotesType.disabled,
                  decoration: InputDecoration(
                    hintText: 'Nhập mã giảm giá',
                    isDense: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.ink200),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.ink200),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.primary500),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              WgButton.secondary(
                label: form.promoIsValid ? 'Đã áp dụng' : 'Áp dụng',
                onPressed: _applyPromo,
                size: WgButtonSize.md,
              ),
            ],
          ),
          if (form.promoMessage != null) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                form.promoMessage!,
                style: AppTypography.caption.copyWith(
                  color: form.promoIsValid
                      ? AppColors.success
                      : AppColors.danger,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFarePreviewCard(ScheduleRideFormState form) {
    if (form.estimatedDistanceKm == 0 && !form.isCalculating) {
      return const SizedBox.shrink();
    }
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                PhosphorIconsFill.receipt,
                size: 20,
                color: AppColors.primary700,
              ),
              const SizedBox(width: 8),
              Text(
                'Ước tính chuyến đi',
                style: AppTypography.h3.copyWith(
                  color: AppColors.primary700,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              if (form.isCalculating)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      AppColors.primary500,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          _FareRow(
            label: 'Quãng đường',
            value: '${form.estimatedDistanceKm.toStringAsFixed(1)} km',
          ),
          _FareRow(
            label: 'Thời gian dự kiến',
            value: '${form.estimatedDurationMin} phút',
          ),
          _FareRow(
            label: 'Giá gốc',
            value: formatVnd(form.baseFare),
          ),
          if (form.discount > 0)
            _FareRow(
              label: 'Giảm giá',
              value: '- ${formatVnd(form.discount)}',
              valueColor: AppColors.success,
            ),
          const Divider(height: 18, color: AppColors.ink200),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Tổng cộng',
                style: AppTypography.bodyLarge.copyWith(
                  color: AppColors.ink900,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                formatVnd(form.estimatedFare),
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

  Widget _buildBottomCta(ScheduleRideFormState form) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final canBook = form.pickup != null &&
        form.dropoff != null &&
        form.scheduledAt != null &&
        form.estimatedFare > 0 &&
        !form.isCalculating;
    return Container(
      padding: EdgeInsets.fromLTRB(20, 14, 20, bottomInset + 14),
      decoration: const BoxDecoration(
        color: AppColors.white,
        border: Border(top: BorderSide(color: AppColors.ink100, width: 0.5)),
      ),
      child: WgButton.primary(
        label: form.estimatedFare > 0
            ? 'Đặt chuyến — ${formatVnd(form.estimatedFare)}'
            : 'Đặt chuyến',
        size: WgButtonSize.lg,
        isFullWidth: true,
        trailingIcon: PhosphorIconsRegular.arrowRight,
        isLoading: _booking,
        onPressed: canBook && !_booking ? _book : null,
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────

  String _luggageLabel(LuggageType l) => switch (l) {
    LuggageType.none => 'Không',
    LuggageType.small => 'Nhỏ',
    LuggageType.large => 'Lớn',
  };

  String _recurrenceLabel(RecurrenceType r) => switch (r) {
    RecurrenceType.once => '1 lần',
    RecurrenceType.daily => 'Hàng ngày',
    RecurrenceType.weekly => 'Hàng tuần',
  };

  IconData _paymentIcon(SchedulePaymentMethod m) => switch (m) {
    SchedulePaymentMethod.cash => PhosphorIconsFill.money,
    SchedulePaymentMethod.vnpay => PhosphorIconsFill.creditCard,
    SchedulePaymentMethod.momo => PhosphorIconsFill.wallet,
  };

  Color _paymentColor(SchedulePaymentMethod m) => switch (m) {
    SchedulePaymentMethod.cash => AppColors.success,
    SchedulePaymentMethod.vnpay => AppColors.info,
    SchedulePaymentMethod.momo => const Color(0xFFA50064),
  };

  String _paymentLabel(SchedulePaymentMethod m) => switch (m) {
    SchedulePaymentMethod.cash => 'Tiền mặt',
    SchedulePaymentMethod.vnpay => 'VNPay',
    SchedulePaymentMethod.momo => 'MoMo',
  };

  String _formatScheduledAt(DateTime dt) {
    const weekdays = ['Hai', 'Ba', 'Tư', 'Năm', 'Sáu', 'Bảy', 'CN'];
    final wd = weekdays[dt.weekday - 1];
    final prefix = wd == 'CN' ? 'CN' : 'Thứ $wd';
    final dd = dt.day.toString().padLeft(2, '0');
    final mm = dt.month.toString().padLeft(2, '0');
    final hh = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return '$prefix, $dd/$mm • $hh:$min';
  }
}

// ── Reusable sub-widgets ────────────────────────────────────────────

class _CardShell extends StatelessWidget {
  const _CardShell({
    required this.child,
    this.title,
    this.subtitle,
    this.icon,
    this.iconColor,
  });

  final Widget child;
  final String? title;
  final String? subtitle;
  final IconData? icon;
  final Color? iconColor;

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
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title != null) ...[
            Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 16, color: iconColor ?? AppColors.primary500),
                  const SizedBox(width: 6),
                ],
                Text(
                  title!,
                  style: AppTypography.caption.copyWith(
                    color: AppColors.ink700,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(width: 4),
                  Text(
                    '· $subtitle',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.ink400,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 10),
          ],
          child,
        ],
      ),
    );
  }
}

class _LocationRow extends StatelessWidget {
  const _LocationRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    required this.placeholder,
    required this.onTap,
    this.address,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final String? address;
  final bool placeholder;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 16),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: AppTypography.caption.copyWith(
                      color: AppColors.ink500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: AppTypography.body.copyWith(
                      color: placeholder ? AppColors.ink500 : AppColors.ink900,
                      fontWeight: placeholder
                          ? FontWeight.w400
                          : FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (address != null && !placeholder) ...[
                    const SizedBox(height: 2),
                    Text(
                      address!,
                      style: AppTypography.micro.copyWith(
                        color: AppColors.ink500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
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

class _SelectorPill extends StatelessWidget {
  const _SelectorPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppColors.primary500 : AppColors.ink50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppColors.primary500 : AppColors.ink200,
          ),
        ),
        child: Text(
          label,
          style: AppTypography.caption.copyWith(
            color: selected ? AppColors.white : AppColors.ink700,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _ChipPill extends StatelessWidget {
  const _ChipPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary500 : AppColors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? AppColors.primary500 : AppColors.ink200,
          ),
        ),
        child: Text(
          label,
          style: AppTypography.caption.copyWith(
            color: selected ? AppColors.white : AppColors.ink700,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _SmallPill extends StatelessWidget {
  const _SmallPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary500 : AppColors.ink50,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? AppColors.primary500 : AppColors.ink200,
          ),
        ),
        child: Text(
          label,
          style: AppTypography.micro.copyWith(
            color: selected ? AppColors.white : AppColors.ink700,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _RideTypeOption extends StatelessWidget {
  const _RideTypeOption({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.iconColor,
    required this.selected,
    required this.onTap,
  });
  final String title;
  final String subtitle;
  final IconData icon;
  final Color iconColor;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected ? iconColor.withValues(alpha: 0.08) : AppColors.ink50,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? iconColor : AppColors.ink200,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: AppTypography.body.copyWith(
                      color: AppColors.ink900,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: AppTypography.caption.copyWith(
                      color: AppColors.ink500,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(
              selected
                  ? PhosphorIconsFill.checkCircle
                  : PhosphorIconsRegular.circle,
              size: 22,
              color: selected ? iconColor : AppColors.ink300,
            ),
          ],
        ),
      ),
    );
  }
}

class _StepperButton extends StatelessWidget {
  const _StepperButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;
    return Material(
      color: disabled ? AppColors.ink100 : AppColors.primary500,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: disabled
            ? null
            : () {
                HapticFeedback.lightImpact();
                onTap!();
              },
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 48,
          height: 48,
          child: Icon(
            icon,
            color: disabled ? AppColors.ink400 : AppColors.white,
            size: 22,
          ),
        ),
      ),
    );
  }
}

class _FareRow extends StatelessWidget {
  const _FareRow({
    required this.label,
    required this.value,
    this.valueColor,
  });
  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: AppTypography.caption.copyWith(color: AppColors.ink700),
          ),
          Text(
            value,
            style: AppTypography.body.copyWith(
              color: valueColor ?? AppColors.ink900,
              fontWeight: FontWeight.w600,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }
}
