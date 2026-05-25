import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

enum _ToastKind { success, error, info }

class WgToast {
  WgToast._();

  static void success(BuildContext context, String message) =>
      _show(context, message, _ToastKind.success);

  static void error(BuildContext context, String message) =>
      _show(context, message, _ToastKind.error);

  static void info(BuildContext context, String message) =>
      _show(context, message, _ToastKind.info);

  static void _show(BuildContext context, String message, _ToastKind kind) {
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;

    final entry = OverlayEntry(
      builder: (_) => _ToastWidget(message: message, kind: kind),
    );
    overlay.insert(entry);
    Future.delayed(const Duration(seconds: 3), () {
      if (entry.mounted) entry.remove();
    });
  }
}

class _ToastWidget extends StatefulWidget {
  const _ToastWidget({required this.message, required this.kind});
  final String message;
  final _ToastKind kind;

  @override
  State<_ToastWidget> createState() => _ToastWidgetState();
}

class _ToastWidgetState extends State<_ToastWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _slide;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );
    _slide = Tween<Offset>(
      begin: const Offset(0, -0.4),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _controller.forward();
    Future.delayed(const Duration(milliseconds: 2700), () {
      if (mounted) _controller.reverse();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  ({Color bg, Color fg, IconData icon}) get _style => switch (widget.kind) {
    _ToastKind.success => (
      bg: AppColors.success,
      fg: Colors.white,
      icon: Icons.check_circle,
    ),
    _ToastKind.error => (
      bg: AppColors.danger,
      fg: Colors.white,
      icon: Icons.error,
    ),
    _ToastKind.info => (
      bg: AppColors.ink900,
      fg: Colors.white,
      icon: Icons.info,
    ),
  };

  @override
  Widget build(BuildContext context) {
    final s = _style;
    final topInset = MediaQuery.of(context).padding.top;
    return Positioned(
      top: topInset + 12,
      left: 16,
      right: 16,
      child: FadeTransition(
        opacity: _fade,
        child: SlideTransition(
          position: _slide,
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: s.bg,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Icon(s.icon, color: s.fg, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.message,
                      style: AppTypography.body.copyWith(
                        color: s.fg,
                        fontWeight: FontWeight.w500,
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
