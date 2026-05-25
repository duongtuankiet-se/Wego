import 'package:intl/intl.dart';

final _vndFormatter = NumberFormat.currency(
  locale: 'vi_VN',
  symbol: '₫',
  decimalDigits: 0,
);

String formatVnd(num amount) => _vndFormatter.format(amount);

String formatPhone(String phone) {
  final p = normalizePhone(phone);
  if (p.startsWith('+84') && p.length == 12) {
    return '${p.substring(0, 3)} ${p.substring(3, 6)} ${p.substring(6, 9)} ${p.substring(9)}';
  }
  return phone;
}

String formatDate(DateTime dt) =>
    DateFormat('dd/MM/yyyy', 'vi_VN').format(dt.toLocal());

String formatTime(DateTime dt) =>
    DateFormat('HH:mm', 'vi_VN').format(dt.toLocal());

String formatDateTime(DateTime dt) =>
    DateFormat('HH:mm dd/MM/yyyy', 'vi_VN').format(dt.toLocal());

/// Normalize VN phone: '0905xxx' / '+84905xxx' / '84905xxx' → '+84905xxx'
String normalizePhone(String raw) {
  var p = raw.trim().replaceAll(RegExp(r'[\s\-\.]'), '');
  if (p.startsWith('+84')) return p;
  if (p.startsWith('84') && p.length == 11) return '+$p';
  if (p.startsWith('0')) return '+84${p.substring(1)}';
  return p;
}
