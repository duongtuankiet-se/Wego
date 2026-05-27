import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/google_g_logo.dart';

/// Material-Guidelines compliant Google sign-in button:
/// white background, 1px #DADCE0 border (Google's official spec), 4-color
/// G logo, and Roboto Medium label "Tiếp tục với Google". Shared between
/// Login + Register screens.
class GoogleSignInButton extends StatelessWidget {
  const GoogleSignInButton({
    super.key,
    required this.loading,
    required this.enabled,
    required this.onPressed,
    this.label = 'Tiếp tục với Google',
  });

  final bool loading;
  final bool enabled;
  final VoidCallback onPressed;
  final String label;

  /// Google brand border (https://developers.google.com/identity/branding-guidelines).
  static const _border = Color(0xFFDADCE0);

  /// Google "interface text" color (#3C4043 from the guideline).
  static const _labelColor = Color(0xFF3C4043);

  /// Spinner tint while signing in — Google blue.
  static const _googleBlue = Color(0xFF4285F4);

  @override
  Widget build(BuildContext context) {
    final disabled = !enabled || loading;
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: Opacity(
        opacity: enabled ? 1 : 0.5,
        child: Material(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            onTap: disabled ? null : onPressed,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _border, width: 1),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (loading)
                    const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(_googleBlue),
                      ),
                    )
                  else ...[
                    const GoogleGLogo(size: 22),
                    const SizedBox(width: 12),
                    Text(
                      label,
                      // Roboto Medium per Google guidelines. Roboto is the
                      // default system sans on Android and we already list
                      // it in AppTypography's fallback chain — this
                      // hardcoded family is intentional to honor the
                      // Google brand spec exactly.
                      style: const TextStyle(
                        fontFamily: 'Roboto',
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: _labelColor,
                        height: 1.25,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
