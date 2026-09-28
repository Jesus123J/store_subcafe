import 'package:intl/intl.dart';

import '../constants/app_constants.dart';

class CurrencyFormatter {
  CurrencyFormatter._();

  /// Formato peruano: "S/. 1,250.50" (símbolo delante, punto decimal).
  static final NumberFormat _formatter = NumberFormat.currency(
    locale: 'en_US',
    symbol: '${AppConstants.currencySymbol} ',
    decimalDigits: 2,
    customPattern: '\u00a4#,##0.00',
  );

  static String format(num? value) {
    if (value == null) return '${AppConstants.currencySymbol} 0.00';
    return _formatter.format(value);
  }
}
