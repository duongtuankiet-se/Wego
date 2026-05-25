import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

enum WgInputVariant { text, phone, otp, password }

class WgInput extends StatefulWidget {
  const WgInput({
    super.key,
    this.label,
    this.hint,
    this.controller,
    this.initialValue,
    this.variant = WgInputVariant.text,
    this.validator,
    this.onChanged,
    this.onSubmitted,
    this.prefixIcon,
    this.suffixIcon,
    this.errorText,
    this.enabled = true,
    this.autofocus = false,
    this.textInputAction,
    this.maxLength,
  });

  final String? label;
  final String? hint;
  final TextEditingController? controller;
  final String? initialValue;
  final WgInputVariant variant;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final IconData? prefixIcon;
  final IconData? suffixIcon;
  final String? errorText;
  final bool enabled;
  final bool autofocus;
  final TextInputAction? textInputAction;
  final int? maxLength;

  @override
  State<WgInput> createState() => _WgInputState();
}

class _WgInputState extends State<WgInput> {
  bool _obscure = true;

  TextInputType _keyboard() {
    return switch (widget.variant) {
      WgInputVariant.phone => TextInputType.phone,
      WgInputVariant.otp => TextInputType.number,
      WgInputVariant.password => TextInputType.visiblePassword,
      WgInputVariant.text => TextInputType.text,
    };
  }

  List<TextInputFormatter> _formatters() {
    return switch (widget.variant) {
      WgInputVariant.phone => [
        FilteringTextInputFormatter.allow(RegExp(r'[0-9+]')),
      ],
      WgInputVariant.otp => [FilteringTextInputFormatter.digitsOnly],
      _ => const <TextInputFormatter>[],
    };
  }

  @override
  Widget build(BuildContext context) {
    final isPassword = widget.variant == WgInputVariant.password;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.label != null) ...[
          Text(
            widget.label!,
            style: AppTypography.caption.copyWith(
              color: AppColors.ink700,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
        ],
        SizedBox(
          height: widget.variant == WgInputVariant.otp ? null : 56,
          child: TextFormField(
            controller: widget.controller,
            initialValue: widget.controller == null
                ? widget.initialValue
                : null,
            keyboardType: _keyboard(),
            inputFormatters: _formatters(),
            obscureText: isPassword && _obscure,
            enabled: widget.enabled,
            autofocus: widget.autofocus,
            textInputAction: widget.textInputAction,
            maxLength: widget.maxLength,
            style: AppTypography.bodyLarge,
            validator: widget.validator,
            onChanged: widget.onChanged,
            onFieldSubmitted: widget.onSubmitted,
            decoration: InputDecoration(
              hintText: widget.hint,
              counterText: '',
              prefixIcon: widget.prefixIcon != null
                  ? Icon(widget.prefixIcon, color: AppColors.ink500, size: 20)
                  : null,
              suffixIcon: isPassword
                  ? IconButton(
                      icon: Icon(
                        _obscure ? Icons.visibility_off : Icons.visibility,
                        color: AppColors.ink500,
                        size: 20,
                      ),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    )
                  : widget.suffixIcon != null
                  ? Icon(widget.suffixIcon, color: AppColors.ink500, size: 20)
                  : null,
              errorText: widget.errorText,
            ),
          ),
        ),
      ],
    );
  }
}
