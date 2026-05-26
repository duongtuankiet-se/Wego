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
