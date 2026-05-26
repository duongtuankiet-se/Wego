/// Convert "duong quang huy" → "Duong Quang Huy" word by word.
String toProperCase(String s) {
  return s
      .trim()
      .split(RegExp(r'\s+'))
      .map(
        (w) => w.isEmpty
            ? w
            : '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}',
      )
      .join(' ');
}

/// Mask a normalized VN phone for display.
///
/// "+84905123909" → "+84 *** 909".
///
/// Handles either a normalized phone ("+84xxxxxxxxx") or already-formatted
/// phone ("+84 905 123 909") — both collapse to "+84 *** 909".
String formatPhoneMask(String phone) {
  final clean = phone.replaceAll(RegExp(r'\s+'), '');
  if (clean.length < 6) return phone;
  final country = clean.startsWith('+84')
      ? '+84'
      : clean.substring(0, clean.length - 3);
  final last3 = clean.substring(clean.length - 3);
  return '$country *** $last3';
}
