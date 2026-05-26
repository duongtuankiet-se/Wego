"""
Patch vendored phosphor_flutter 2.1.0 for Flutter 3.44+ compatibility.

Problem: Flutter 3.44 marked `IconData` as `final class`, so
`PhosphorIconData extends IconData` no longer compiles.

Fix:
  - Rewrite `phosphor_icon_data.dart` to alias PhosphorIconData /
    PhosphorFlatIconData to IconData via typedef, and keep
    PhosphorDuotoneIconData as a standalone wrapper.
  - Rewrite the static `const acorn = PhosphorFlatIconData(0xeb9a, 'Regular')`
    declarations in each variant file to be direct `IconData(...)` instances
    so they satisfy the typedef.
  - Rewrite duotone declarations to use the new constructor signature.
  - Patch phosphor_icon.dart to type-check via duck-type instead of `is`.
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

sys.stdout.reconfigure(encoding="utf-8", errors="replace")

VENDOR = Path(r"D:\exe\vendor\phosphor_flutter\lib")

NEW_ICON_DATA = '''library phosphor_flutter;

import 'package:flutter/widgets.dart';

/// Alias kept for API back-compat. Phosphor icons are now plain [IconData]
/// because Flutter 3.44 made `IconData` a `final class` (no longer
/// extensible by external libraries).
typedef PhosphorIconData = IconData;

/// Alias kept for API back-compat — same as [PhosphorIconData].
typedef PhosphorFlatIconData = IconData;

/// Wrapper for duotone Phosphor icons that holds both the primary
/// and secondary [IconData]. Not a subtype of [IconData]; use the
/// [primary] / [secondary] fields directly.
class PhosphorDuotoneIconData {
  const PhosphorDuotoneIconData(this.primary, this.secondary);
  final IconData primary;
  final IconData secondary;

  // Convenience getters so callers that used to read `iconData.codePoint`
  // etc. on the old class can still do so.
  int get codePoint => primary.codePoint;
  String? get fontFamily => primary.fontFamily;
  String? get fontPackage => primary.fontPackage;
  bool get matchTextDirection => primary.matchTextDirection;
}
'''

NEW_PHOSPHOR_ICON = '''library phosphor_flutter;

import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

class PhosphorIcon extends StatelessWidget {
  const PhosphorIcon(
    this.icon, {
    super.key,
    this.size,
    this.fill,
    this.weight,
    this.grade,
    this.opticalSize,
    this.color,
    this.shadows,
    this.semanticLabel,
    this.textDirection,
    this.duotoneSecondaryOpacity = 0.20,
    this.duotoneSecondaryColor,
  });

  /// Accepts a plain [IconData] (used by Regular/Fill/Thin/Light/Bold
  /// variants) OR a [PhosphorDuotoneIconData] (duotone variant).
  final Object icon;
  final double? size;
  final double? fill;
  final double? weight;
  final double? grade;
  final double? opticalSize;
  final Color? color;
  final List<Shadow>? shadows;
  final String? semanticLabel;
  final TextDirection? textDirection;
  final double duotoneSecondaryOpacity;
  final Color? duotoneSecondaryColor;

  @override
  Widget build(BuildContext context) {
    final ic = icon;
    if (ic is PhosphorDuotoneIconData) {
      return Stack(
        alignment: Alignment.center,
        children: [
          Opacity(
            opacity: duotoneSecondaryOpacity,
            child: Icon(
              ic.secondary,
              size: size,
              fill: fill,
              weight: weight,
              grade: grade,
              opticalSize: opticalSize,
              color: duotoneSecondaryColor ?? color,
              shadows: shadows,
              semanticLabel: semanticLabel,
              textDirection: textDirection,
            ),
          ),
          Icon(
            ic.primary,
            size: size,
            fill: fill,
            weight: weight,
            grade: grade,
            opticalSize: opticalSize,
            color: color,
            shadows: shadows,
            semanticLabel: semanticLabel,
            textDirection: textDirection,
          ),
        ],
      );
    }
    if (ic is IconData) {
      return Icon(
        ic,
        size: size,
        fill: fill,
        weight: weight,
        grade: grade,
        opticalSize: opticalSize,
        color: color,
        shadows: shadows,
        semanticLabel: semanticLabel,
        textDirection: textDirection,
      );
    }
    throw ArgumentError(
      'PhosphorIcon expected IconData or PhosphorDuotoneIconData, got '
      '${ic.runtimeType}',
    );
  }
}
'''


def patch_flat_variant(path: Path, style: str) -> int:
    """Patch a single-style icons file (regular/thin/light/bold/fill).

    Replaces:
        static const acorn = PhosphorFlatIconData(0xeb9a, 'Regular');
    with:
        static const acorn = IconData(0xeb9a, fontFamily: 'PhosphorRegular',
            fontPackage: 'phosphor_flutter', matchTextDirection: true);
    """
    src = path.read_text(encoding="utf-8")
    pattern = re.compile(
        r"PhosphorFlatIconData\(\s*(0x[0-9a-fA-F]+)\s*,\s*'" + style + r"'\s*\)"
    )
    replacement = (
        rf"IconData(\1, fontFamily: 'Phosphor{style}', "
        rf"fontPackage: 'phosphor_flutter', matchTextDirection: true)"
    )
    new_src, n = pattern.subn(replacement, src)
    if n > 0:
        path.write_text(new_src, encoding="utf-8")
    return n


def patch_duotone(path: Path) -> int:
    """Patch the duotone icons file.

    Replaces:
        static const acorn = PhosphorDuotoneIconData(
          0xeb9b,
          PhosphorIconData(0xeb9a, 'Duotone'),
        );
    with:
        static const acorn = PhosphorDuotoneIconData(
          IconData(0xeb9b, fontFamily: 'PhosphorDuotone',
              fontPackage: 'phosphor_flutter', matchTextDirection: true),
          IconData(0xeb9a, fontFamily: 'PhosphorDuotone',
              fontPackage: 'phosphor_flutter', matchTextDirection: true),
        );
    """
    src = path.read_text(encoding="utf-8")
    # Match `PhosphorDuotoneIconData(\n    0xPRIM,\n    PhosphorIconData(0xSEC, 'Duotone'),\n  )`
    pattern = re.compile(
        r"PhosphorDuotoneIconData\(\s*"
        r"(0x[0-9a-fA-F]+)\s*,\s*"
        r"PhosphorIconData\(\s*(0x[0-9a-fA-F]+)\s*,\s*'Duotone'\s*\)\s*,?\s*"
        r"\)",
    )

    def repl(m: re.Match[str]) -> str:
        prim, sec = m.group(1), m.group(2)
        return (
            f"PhosphorDuotoneIconData(\n"
            f"      IconData({prim}, fontFamily: 'PhosphorDuotone', "
            f"fontPackage: 'phosphor_flutter', matchTextDirection: true),\n"
            f"      IconData({sec}, fontFamily: 'PhosphorDuotone', "
            f"fontPackage: 'phosphor_flutter', matchTextDirection: true),\n"
            f"    )"
        )

    new_src, n = pattern.subn(repl, src)
    if n > 0:
        path.write_text(new_src, encoding="utf-8")
    return n


def main() -> int:
    src_dir = VENDOR / "src"
    if not src_dir.exists():
        print(f"ERROR: {src_dir} not found", file=sys.stderr)
        return 1

    print("Patching phosphor_icon_data.dart …")
    (src_dir / "phosphor_icon_data.dart").write_text(
        NEW_ICON_DATA, encoding="utf-8"
    )

    print("Patching phosphor_icon.dart …")
    (src_dir / "phosphor_icon.dart").write_text(
        NEW_PHOSPHOR_ICON, encoding="utf-8"
    )

    total = 0
    for style in ("Regular", "Thin", "Light", "Bold", "Fill"):
        path = src_dir / f"phosphor_icons_{style.lower()}.dart"
        n = patch_flat_variant(path, style)
        print(f"  {path.name}: {n} icons rewritten")
        total += n

    duotone_path = src_dir / "phosphor_icons_duotone.dart"
    n = patch_duotone(duotone_path)
    print(f"  {duotone_path.name}: {n} duotone icons rewritten")
    total += n

    print(f"\nDone. {total} icon declarations patched.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
