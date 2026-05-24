import 'package:intl/intl.dart';

import '../constants/app_constants.dart';

class AppDateUtils {
  AppDateUtils._();

  static String formatDate(DateTime date) =>
      DateFormat(AppConstants.dateFormat).format(date);

  static String formatDateTime(DateTime date) =>
      DateFormat(AppConstants.dateTimeFormat).format(date);

  static String formatTime(DateTime date) =>
      DateFormat(AppConstants.timeFormat).format(date);

  /// Determina si una hora está dentro del turno día (7:30 - 19:30).
  static bool isTurnoDia(DateTime dateTime) {
    final m = dateTime.hour * 60 + dateTime.minute;
    final inicio = AppConstants.turnoDiaInicioHora * 60 + AppConstants.turnoDiaInicioMin;
    final fin = AppConstants.turnoNocheInicioHora * 60 + AppConstants.turnoNocheInicioMin;
    return m >= inicio && m < fin;
  }
}
