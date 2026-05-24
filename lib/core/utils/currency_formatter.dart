import 'package:intl/intl.dart';

import '../constants/app_constants.dart';

class CurrencyFormatter {
  CurrencyFormatter._();

  static final NumberFormat _formatter = NumberFormat.currency(
    locale: 'es_PE',
    symbol: '${AppConstants.currencySymbol} ',
    decimalDigits: 2,
  );

  static String format(num? value) {
    if (value == null) return '${AppConstants.currencySymbol} 0.00';
    return _formatter.format(value);
  }
}
