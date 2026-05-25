import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'payment_method_provider.g.dart';

enum PaymentMethod { cash, card, momo, zalopay }

extension PaymentMethodX on PaymentMethod {
  String get label => switch (this) {
    PaymentMethod.cash => 'Tiền mặt',
    PaymentMethod.card => 'Thẻ',
    PaymentMethod.momo => 'MoMo',
    PaymentMethod.zalopay => 'ZaloPay',
  };
}

@Riverpod(keepAlive: true)
class SelectedPaymentMethod extends _$SelectedPaymentMethod {
  @override
  PaymentMethod build() => PaymentMethod.cash;

  void set(PaymentMethod m) => state = m;
}
