import '../domain/enums.dart';
import '../domain/holiday.dart';

class DeadlineCalculator {
  /// Calcula la fecha de vencimiento de un plazo procesal.
  /// 
  /// [inicio]: Fecha de notificación o inicio del cómputo.
  /// [diasPlazo]: Cantidad de días del plazo legal.
  /// [diasAdicionales]: Días añadidos por Tabla de Emplazamiento.
  /// [tipo]: Judicial (CPC), Administrativo (19.880) o Corridos (CPP).
  /// [feriados]: Lista de feriados (idealmente de la API oficial).
  static DateTime calculateDeadline({
    required DateTime startDate,
    required int days,
    int additionalDays = 0,
    required TipoComputo type,
    required List<Holiday> holidays,
  }) {
    DateTime current = DateTime(startDate.year, startDate.month, startDate.day);
    int added = 0;
    int totalDays = days + additionalDays;

    if (totalDays == 0) return current;

    while (added < totalDays) {
      current = current.add(const Duration(days: 1));
      
      if (_isValidDay(current, type, holidays)) {
        added++;
      }
    }

    // Regla Especial CPP Art 14 / Prórrogas Generales (Corridos):
    if (type == TipoComputo.corridos) {
      while (!_isValidDay(current, TipoComputo.judicial, holidays)) {
        current = current.add(const Duration(days: 1));
      }
    }

    return DateTime(current.year, current.month, current.day, 23, 59, 59);
  }

  /// Alias compatible con las pruebas unitarias
  static DateTime calcularPlazo(
    DateTime inicio,
    int dias,
    TipoComputo tipo,
    List<Holiday> feriados, {
    int diasAdicionales = 0,
  }) {
    return calculateDeadline(
      startDate: inicio,
      days: dias,
      additionalDays: diasAdicionales,
      type: tipo,
      holidays: feriados,
    );
  }

  static bool _isValidDay(DateTime date, TipoComputo type, List<Holiday> holidays) {
    final isHoliday = holidays.any((h) => 
      h.date.year == date.year && 
      h.date.month == date.month && 
      h.date.day == date.day
    );

    switch (type) {
      case TipoComputo.judicial:
        return date.weekday != DateTime.sunday && !isHoliday;
      case TipoComputo.administrativo:
        return date.weekday != DateTime.saturday && date.weekday != DateTime.sunday && !isHoliday;
      case TipoComputo.corridos:
        return true; 
    }
  }
}
