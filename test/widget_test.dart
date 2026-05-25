import 'package:exe/core/utils/format.dart';
import 'package:exe/core/utils/validators.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('normalizePhone', () {
    test('0xxx → +84xxx', () {
      expect(normalizePhone('0905123678'), '+84905123678');
    });
    test('+84xxx unchanged', () {
      expect(normalizePhone('+84905123678'), '+84905123678');
    });
    test('84xxx → +84xxx', () {
      expect(normalizePhone('84905123678'), '+84905123678');
    });
    test('strips whitespace and dashes', () {
      expect(normalizePhone('0905 123-678'), '+84905123678');
    });
  });

  group('validators', () {
    test('valid VN phone', () {
      expect(Validators.validatePhone('0905123678'), isNull);
      expect(Validators.validatePhone('+84905123678'), isNull);
    });
    test('invalid phone', () {
      expect(Validators.validatePhone('abc'), isNotNull);
      expect(Validators.validatePhone(''), isNotNull);
    });
    test('valid name', () {
      expect(Validators.validateName('Nguyễn Văn A'), isNull);
    });
    test('invalid name', () {
      expect(Validators.validateName(''), isNotNull);
      expect(Validators.validateName('A'), isNotNull);
    });
  });
}
