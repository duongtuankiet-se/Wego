import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/wg_avatar.dart';
import '../../core/widgets/wg_badge.dart';
import '../../core/widgets/wg_button.dart';
import '../../core/widgets/wg_card.dart';
import '../../core/widgets/wg_chip.dart';
import '../../core/widgets/wg_input.dart';
import '../../core/widgets/wg_sheet.dart';
import '../../core/widgets/wg_toast.dart';

class ShowcaseScreen extends StatelessWidget {
  const ShowcaseScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('WeGo Design System')),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        children: [
          _Section(title: '1. Colors', child: _ColorsGrid()),
          _Section(title: '2. Typography', child: _TypographyDemo()),
          _Section(title: '3. Buttons', child: _ButtonsDemo()),
          _Section(title: '4. Inputs', child: _InputsDemo()),
          _Section(title: '5. Cards', child: _CardsDemo()),
          _Section(title: '6. Chips', child: _ChipsDemo()),
          _Section(title: '7. Badges', child: _BadgesDemo()),
          _Section(title: '8. Avatars', child: _AvatarsDemo()),
          const _Section(title: '9. Toasts', child: _ToastsDemo()),
          const _Section(title: '10. Bottom Sheet', child: _SheetDemo()),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});
  final String title;
  final Widget child;
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Text(title, style: AppTypography.h2),
        const SizedBox(height: 12),
        child,
        const SizedBox(height: 24),
        const Divider(),
      ],
    );
  }
}

class _ColorsGrid extends StatelessWidget {
  final swatches = const [
    ('primary500', AppColors.primary500),
    ('primary100', AppColors.primary100),
    ('primary700', AppColors.primary700),
    ('ink900', AppColors.ink900),
    ('ink500', AppColors.ink500),
    ('ink100', AppColors.ink100),
    ('success', AppColors.success),
    ('warning', AppColors.warning),
    ('danger', AppColors.danger),
    ('info', AppColors.info),
    ('shared', AppColors.sharedAccent),
    ('surge', AppColors.surge),
  ];

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 4,
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 0.85,
      children: swatches
          .map(
            (s) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: s.$2,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.ink100),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  s.$1,
                  style: AppTypography.micro,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '#${(s.$2.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}',
                  style: AppTypography.mono.copyWith(fontSize: 10),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          )
          .toList(),
    );
  }
}

class _TypographyDemo extends StatelessWidget {
  final entries = const [
    ('display', AppTypography.display),
    ('h1', AppTypography.h1),
    ('h2', AppTypography.h2),
    ('bodyLarge', AppTypography.bodyLarge),
    ('body', AppTypography.body),
    ('caption', AppTypography.caption),
    ('micro', AppTypography.micro),
    ('mono', AppTypography.mono),
  ];
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: entries
          .map(
            (e) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  SizedBox(
                    width: 80,
                    child: Text(e.$1, style: AppTypography.micro),
                  ),
                  Expanded(child: Text('Đặt xe nhanh', style: e.$2)),
                ],
              ),
            ),
          )
          .toList(),
    );
  }
}

class _ButtonsDemo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        WgButton.primary(label: 'Primary md', onPressed: () {}),
        WgButton.secondary(label: 'Secondary md', onPressed: () {}),
        WgButton.ghost(label: 'Ghost md', onPressed: () {}),
        WgButton.primary(
          label: 'Primary lg',
          size: WgButtonSize.lg,
          onPressed: () {},
        ),
        WgButton.primary(
          label: 'Primary sm',
          size: WgButtonSize.sm,
          onPressed: () {},
        ),
        WgButton.primary(label: 'Loading', isLoading: true, onPressed: () {}),
        WgButton.primary(label: 'Disabled', onPressed: null),
        WgButton.primary(
          label: 'With icons',
          leadingIcon: Icons.add,
          trailingIcon: Icons.arrow_forward,
          onPressed: () {},
        ),
      ],
    );
  }
}

class _InputsDemo extends StatefulWidget {
  @override
  State<_InputsDemo> createState() => _InputsDemoState();
}

class _InputsDemoState extends State<_InputsDemo> {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const WgInput(label: 'Text', hint: 'Họ tên'),
        const SizedBox(height: 12),
        const WgInput(
          label: 'Phone',
          hint: '0905xxxxxx',
          variant: WgInputVariant.phone,
          prefixIcon: Icons.phone,
        ),
        const SizedBox(height: 12),
        const WgInput(
          label: 'Password',
          hint: '••••••',
          variant: WgInputVariant.password,
        ),
        const SizedBox(height: 12),
        const WgInput(
          label: 'Error state',
          hint: 'Sai dữ liệu',
          errorText: 'Trường này không hợp lệ',
        ),
        const SizedBox(height: 12),
        const WgInput(
          label: 'Search',
          hint: 'Tìm địa điểm',
          prefixIcon: Icons.search,
        ),
      ],
    );
  }
}

class _CardsDemo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        WgCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Standard card', style: AppTypography.h2),
              const SizedBox(height: 4),
              Text(
                'Nền trắng, radius 20, padding 16',
                style: AppTypography.body,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        WgCard(
          elevated: true,
          child: Text('Elevated card (shadow)', style: AppTypography.body),
        ),
        const SizedBox(height: 12),
        WgCard(
          onTap: () => WgToast.info(context, 'Card tapped'),
          child: Row(
            children: [
              const Icon(Icons.touch_app, color: AppColors.primary500),
              const SizedBox(width: 12),
              Text('Tap demo', style: AppTypography.body),
            ],
          ),
        ),
      ],
    );
  }
}

class _ChipsDemo extends StatefulWidget {
  @override
  State<_ChipsDemo> createState() => _ChipsDemoState();
}

class _ChipsDemoState extends State<_ChipsDemo> {
  final _selected = <int>{0, 3};
  @override
  Widget build(BuildContext context) {
    final labels = ['4 chỗ', '7 chỗ', 'Xe máy', 'Đi ghép', 'Riêng', 'VIP'];
    final icons = [
      Icons.directions_car,
      Icons.airport_shuttle,
      Icons.two_wheeler,
      Icons.group,
      Icons.lock,
      Icons.star,
    ];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: List.generate(
        labels.length,
        (i) => WgChip(
          label: labels[i],
          leadingIcon: icons[i],
          selected: _selected.contains(i),
          onTap: () => setState(() {
            _selected.contains(i) ? _selected.remove(i) : _selected.add(i);
          }),
        ),
      ),
    );
  }
}

class _BadgesDemo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        WgBadge(label: 'Info', variant: WgBadgeVariant.info),
        WgBadge(label: 'Success', variant: WgBadgeVariant.success),
        WgBadge(label: 'Đi ghép', variant: WgBadgeVariant.shared),
        WgBadge(label: 'x1.5', variant: WgBadgeVariant.surge),
      ],
    );
  }
}

class _AvatarsDemo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 16,
      runSpacing: 16,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: const [
        WgAvatar(name: 'Nguyễn Văn A', size: 32),
        WgAvatar(name: 'Trần Thị B', size: 40),
        WgAvatar(name: 'Lê C', size: 48),
        WgAvatar(name: 'Phạm Quốc Dũng', size: 56),
        WgAvatar(name: 'Driver X', size: 56, rating: 4.8),
      ],
    );
  }
}

class _ToastsDemo extends StatelessWidget {
  const _ToastsDemo();
  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        WgButton.primary(
          label: 'Success',
          size: WgButtonSize.sm,
          onPressed: () => WgToast.success(context, 'Đặt xe thành công!'),
        ),
        WgButton.secondary(
          label: 'Error',
          size: WgButtonSize.sm,
          onPressed: () => WgToast.error(context, 'Không tìm được tài xế'),
        ),
        WgButton.ghost(
          label: 'Info',
          size: WgButtonSize.sm,
          onPressed: () => WgToast.info(context, 'Đang tìm xe gần bạn...'),
        ),
      ],
    );
  }
}

class _SheetDemo extends StatelessWidget {
  const _SheetDemo();
  @override
  Widget build(BuildContext context) {
    return WgButton.primary(
      label: 'Mở Bottom Sheet',
      leadingIcon: Icons.arrow_upward,
      onPressed: () => showWgSheet<void>(
        context: context,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Demo Bottom Sheet', style: AppTypography.h1),
            const SizedBox(height: 8),
            Text(
              'Kéo lên kéo xuống để thay đổi kích thước. Bấm ngoài để đóng.',
              style: AppTypography.body,
            ),
            const SizedBox(height: AppSpacing.xl),
            ...List.generate(
              8,
              (i) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: WgCard(
                  child: Text('Item ${i + 1}', style: AppTypography.body),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
