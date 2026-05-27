import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_shadows.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/wg_button.dart';
import '../../core/widgets/wg_toast.dart';
import '../../models/driver_vehicle.dart';
import '../../providers/driver_provider.dart';
import '../../providers/driver_vehicles_provider.dart';

class DriverVehiclesScreen extends ConsumerWidget {
  const DriverVehiclesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vehiclesAsync = ref.watch(driverVehiclesListProvider);
    return Scaffold(
      backgroundColor: AppColors.offWhite,
      appBar: AppBar(
        backgroundColor: AppColors.offWhite,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(PhosphorIconsRegular.arrowLeft),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Phương tiện của tôi',
          style: AppTypography.h2.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
      body: vehiclesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Lỗi: $e',
              style: AppTypography.body.copyWith(color: AppColors.ink700),
              textAlign: TextAlign.center,
            ),
          ),
        ),
        data: (list) => list.isEmpty
            ? _Empty(onAdd: () => _openForm(context, ref, null))
            : _List(
                vehicles: list,
                onEdit: (v) => _openForm(context, ref, v),
                onSetPrimary: (v) => _setPrimary(context, ref, v),
                onDelete: (v) => _delete(context, ref, v),
              ),
      ),
      floatingActionButton: vehiclesAsync.maybeWhen(
        data: (list) => list.isEmpty
            ? null
            : FloatingActionButton.extended(
                onPressed: () => _openForm(context, ref, null),
                backgroundColor: AppColors.primary500,
                foregroundColor: AppColors.white,
                icon: const Icon(PhosphorIconsBold.plus),
                label: const Text('Thêm xe'),
              ),
        orElse: () => null,
      ),
    );
  }

  Future<void> _openForm(
    BuildContext context,
    WidgetRef ref,
    DriverVehicle? existing,
  ) async {
    final driver = await ref.read(currentDriverProvider.future);
    if (driver == null || !context.mounted) return;
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => _VehicleFormSheet(driverId: driver.id, existing: existing),
    );
    if (saved == true) {
      ref.invalidate(driverVehiclesListProvider);
      ref.invalidate(driverPrimaryVehicleProvider);
    }
  }

  Future<void> _setPrimary(
    BuildContext context,
    WidgetRef ref,
    DriverVehicle v,
  ) async {
    final driver = await ref.read(currentDriverProvider.future);
    if (driver == null || !context.mounted) return;
    final ok = await ref
        .read(driverVehicleServiceProvider)
        .setPrimary(vehicleId: v.id, driverId: driver.id);
    if (!context.mounted) return;
    if (ok) {
      ref.invalidate(driverVehiclesListProvider);
      ref.invalidate(driverPrimaryVehicleProvider);
      WgToast.success(context, 'Đã đặt xe chính');
    } else {
      WgToast.error(context, 'Không cập nhật được');
    }
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    DriverVehicle v,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dctx) => AlertDialog(
        title: const Text('Xoá phương tiện?'),
        content: Text('${v.displayName} · ${v.vehiclePlate}'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dctx, false),
            child: const Text('Không'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(dctx, true),
            child: const Text('Xoá'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    final success =
        await ref.read(driverVehicleServiceProvider).deleteVehicle(v.id);
    if (!context.mounted) return;
    if (success) {
      ref.invalidate(driverVehiclesListProvider);
      ref.invalidate(driverPrimaryVehicleProvider);
      WgToast.success(context, 'Đã xoá xe');
    } else {
      WgToast.error(context, 'Không xoá được');
    }
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.onAdd});
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.primary50,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                PhosphorIconsFill.car,
                color: AppColors.primary500,
                size: 40,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Chưa có phương tiện nào',
              style: AppTypography.h3.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              'Thêm xe để bắt đầu nhận chuyến xe ghép.',
              textAlign: TextAlign.center,
              style: AppTypography.body.copyWith(color: AppColors.ink600),
            ),
            const SizedBox(height: 22),
            WgButton.primary(
              label: 'Thêm xe đầu tiên',
              leadingIcon: PhosphorIconsBold.plus,
              size: WgButtonSize.lg,
              onPressed: onAdd,
            ),
          ],
        ),
      ),
    );
  }
}

class _List extends StatelessWidget {
  const _List({
    required this.vehicles,
    required this.onEdit,
    required this.onSetPrimary,
    required this.onDelete,
  });
  final List<DriverVehicle> vehicles;
  final void Function(DriverVehicle) onEdit;
  final void Function(DriverVehicle) onSetPrimary;
  final void Function(DriverVehicle) onDelete;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      itemCount: vehicles.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (_, i) {
        final v = vehicles[i];
        return _VehicleCard(
          vehicle: v,
          onEdit: () => onEdit(v),
          onSetPrimary: v.isPrimary ? null : () => onSetPrimary(v),
          onDelete: () => onDelete(v),
        );
      },
    );
  }
}

class _VehicleCard extends StatelessWidget {
  const _VehicleCard({
    required this.vehicle,
    required this.onEdit,
    required this.onSetPrimary,
    required this.onDelete,
  });
  final DriverVehicle vehicle;
  final VoidCallback onEdit;
  final VoidCallback? onSetPrimary;
  final VoidCallback onDelete;

  Color get _swatch => switch (vehicle.vehicleColor) {
    VehicleColor.white => const Color(0xFFF3F4F6),
    VehicleColor.black => const Color(0xFF111827),
    VehicleColor.gray => const Color(0xFF6B7280),
    VehicleColor.silver => const Color(0xFFC0C0C0),
    VehicleColor.red => const Color(0xFFDC2626),
    VehicleColor.blue => const Color(0xFF2563EB),
    VehicleColor.other => AppColors.ink400,
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: AppRadius.card,
        boxShadow: AppShadows.xs,
        border: vehicle.isPrimary
            ? Border.all(color: AppColors.primary300, width: 1.5)
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: _swatch,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.ink200),
                ),
                child: Icon(
                  PhosphorIconsFill.car,
                  color: vehicle.vehicleColor == VehicleColor.white ||
                          vehicle.vehicleColor == VehicleColor.silver
                      ? AppColors.ink700
                      : AppColors.white,
                  size: 26,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      vehicle.displayName,
                      style: AppTypography.body.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.ink900,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            vehicle.vehiclePlate,
                            style: const TextStyle(
                              color: AppColors.white,
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                        if (vehicle.isPrimary) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primary500,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: const Text(
                              'Xe chính',
                              style: TextStyle(
                                color: AppColors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                icon: const Icon(PhosphorIconsRegular.dotsThreeVertical),
                onSelected: (v) {
                  switch (v) {
                    case 'edit':
                      onEdit();
                      break;
                    case 'primary':
                      onSetPrimary?.call();
                      break;
                    case 'delete':
                      onDelete();
                      break;
                  }
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'edit', child: Text('Sửa')),
                  if (onSetPrimary != null)
                    const PopupMenuItem(
                      value: 'primary',
                      child: Text('Đặt làm xe chính'),
                    ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Text(
                      'Xoá',
                      style: TextStyle(color: AppColors.danger),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _VehicleFormSheet extends ConsumerStatefulWidget {
  const _VehicleFormSheet({required this.driverId, this.existing});
  final String driverId;
  final DriverVehicle? existing;

  @override
  ConsumerState<_VehicleFormSheet> createState() => _VehicleFormSheetState();
}

class _VehicleFormSheetState extends ConsumerState<_VehicleFormSheet> {
  late VehicleType _type;
  late int _seats;
  late VehicleColor _color;
  late final TextEditingController _plateCtrl;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _type = e?.vehicleType ?? VehicleType.vios;
    _seats = e?.vehicleSeats ?? 4;
    _color = e?.vehicleColor ?? VehicleColor.white;
    _plateCtrl = TextEditingController(text: e?.vehiclePlate ?? '');
  }

  @override
  void dispose() {
    _plateCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final plate = _plateCtrl.text.trim().toUpperCase();
    if (plate.length < 6) {
      setState(() => _error = 'Biển số không hợp lệ');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final svc = ref.read(driverVehicleServiceProvider);
    try {
      if (widget.existing != null) {
        await svc.updateVehicle(
          vehicleId: widget.existing!.id,
          vehicleSeats: _seats,
          vehicleType: _type,
          vehiclePlate: plate,
          vehicleColor: _color,
        );
      } else {
        await svc.addVehicle(
          driverId: widget.driverId,
          vehicleSeats: _seats,
          vehicleType: _type,
          vehiclePlate: plate,
          vehicleColor: _color,
        );
      }
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = e.toString().contains('duplicate')
            ? 'Biển số đã tồn tại'
            : 'Lưu thất bại: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final insets = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 12, 20, insets + 20),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.ink300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              widget.existing == null ? 'Thêm xe' : 'Sửa xe',
              style: AppTypography.h2.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 18),
            Text(
              'Loại xe',
              style: AppTypography.caption.copyWith(
                color: AppColors.ink700,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: VehicleType.values.map((t) {
                final selected = _type == t;
                return _Chip(
                  label: t.label,
                  selected: selected,
                  onTap: () => setState(() => _type = t),
                );
              }).toList(growable: false),
            ),
            const SizedBox(height: 18),
            Text(
              'Số chỗ',
              style: AppTypography.caption.copyWith(
                color: AppColors.ink700,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _SeatPill(
                    label: '4 chỗ',
                    selected: _seats == 4,
                    onTap: () => setState(() => _seats = 4),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _SeatPill(
                    label: '7 chỗ',
                    selected: _seats == 7,
                    onTap: () => setState(() => _seats = 7),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Text(
              'Màu xe',
              style: AppTypography.caption.copyWith(
                color: AppColors.ink700,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: VehicleColor.values.map((c) {
                final selected = _color == c;
                return _Chip(
                  label: c.label,
                  selected: selected,
                  onTap: () => setState(() => _color = c),
                );
              }).toList(growable: false),
            ),
            const SizedBox(height: 18),
            Text(
              'Biển số',
              style: AppTypography.caption.copyWith(
                color: AppColors.ink700,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _plateCtrl,
              textCapitalization: TextCapitalization.characters,
              autocorrect: false,
              enableSuggestions: false,
              smartDashesType: SmartDashesType.disabled,
              smartQuotesType: SmartQuotesType.disabled,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9.\-]')),
                LengthLimitingTextInputFormatter(12),
                TextInputFormatter.withFunction(
                  (oldVal, newVal) => newVal.copyWith(
                    text: newVal.text.toUpperCase(),
                  ),
                ),
              ],
              style: const TextStyle(
                fontFamily: 'monospace',
                fontWeight: FontWeight.w700,
                fontSize: 16,
                letterSpacing: 1.5,
              ),
              decoration: InputDecoration(
                hintText: '43A-128.66',
                errorText: _error,
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
            const SizedBox(height: 22),
            WgButton.primary(
              label: widget.existing == null ? 'Thêm xe' : 'Lưu thay đổi',
              size: WgButtonSize.lg,
              isFullWidth: true,
              isLoading: _saving,
              onPressed: _saving ? null : _save,
            ),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
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
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary500 : AppColors.ink50,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? AppColors.primary500 : AppColors.ink200,
          ),
        ),
        child: Text(
          label,
          style: AppTypography.caption.copyWith(
            color: selected ? AppColors.white : AppColors.ink700,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _SeatPill extends StatelessWidget {
  const _SeatPill({
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
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppColors.primary50 : AppColors.ink50,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? AppColors.primary500 : AppColors.ink200,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: AppTypography.body.copyWith(
            color: selected ? AppColors.primary700 : AppColors.ink700,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
