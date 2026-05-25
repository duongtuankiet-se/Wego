class Validators {
  Validators._();

  static String? validateName(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Vui lòng nhập họ và tên';
    if (v.length < 2) return 'Tên quá ngắn';
    if (v.length > 60) return 'Tên quá dài (tối đa 60 ký tự)';
    return null;
  }

  static String? validatePhone(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Vui lòng nhập số điện thoại';
    final cleaned = v.replaceAll(RegExp(r'[\s\-\.]'), '');
    final ok = RegExp(r'^(\+84|0)\d{9}$').hasMatch(cleaned);
    if (!ok) return 'Số điện thoại không hợp lệ (vd: 0905xxxxxx)';
    return null;
  }

  static String? validateRequired(String? value, {String? fieldName}) {
    if (value == null || value.trim().isEmpty) {
      return '${fieldName ?? "Trường này"} không được để trống';
    }
    return null;
  }
}
