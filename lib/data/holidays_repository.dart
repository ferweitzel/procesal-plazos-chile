import '../domain/holiday.dart';

class ChileHolidaysEngine {
  /// Calcula la fecha de Pascua de Resurrección para cualquier año (Algoritmo de Meeus/Butcher)
  static DateTime calcularPascua(int year) {
    int a = year % 19;
    int b = year ~/ 100;
    int c = year % 100;
    int d = b ~/ 4;
    int e = b % 4;
    int f = (b + 8) ~/ 25;
    int g = (b - f + 1) ~/ 3;
    int h = (19 * a + b - d - g + 15) % 30;
    int i = c ~/ 4;
    int k = c % 4;
    int L = (32 + 2 * e + 2 * i - h - k) % 7;
    int m = (a + 11 * h + 22 * L) ~/ 451;
    int month = (h + L - 7 * m + 114) ~/ 31;
    int day = ((h + L - 7 * m + 114) % 31) + 1;
    return DateTime(year, month, day);
  }

  /// Retorna la lista oficial y matemáticamente exacta de feriados legales en Chile para un año dado.
  static List<Holiday> getHolidaysForYear(int year) {
    final List<Holiday> list = [];

    void addH(int m, int d, String name, {bool irrenunciable = false}) {
      final date = DateTime(year, m, d);
      if (!list.any((h) => h.date.year == date.year && h.date.month == date.month && h.date.day == date.day)) {
        list.add(Holiday(date: date, name: name, isIrrenunciable: irrenunciable));
      }
    }

    // 1. Feriados Fijos Legales (Ley N° 2.977)
    addH(1, 1, 'Año Nuevo', irrenunciable: true);
    addH(5, 1, 'Día Nacional del Trabajo', irrenunciable: true);
    addH(5, 21, 'Día de las Glorias Navales');
    addH(6, 21, 'Día Nacional de los Pueblos Indígenas');
    addH(7, 16, 'Día de la Virgen del Carmen');
    addH(8, 15, 'Asunción de la Virgen');
    addH(9, 18, 'Independencia Nacional', irrenunciable: true);
    addH(9, 19, 'Día de las Glorias del Ejército', irrenunciable: true);
    addH(11, 1, 'Día de Todos los Santos');
    addH(12, 8, 'Inmaculada Concepción');
    addH(12, 25, 'Natividad del Señor (Navidad)', irrenunciable: true);

    // 2. Fiestas Patrias Especiales (Ley N° 20.215 / Ley N° 20.983)
    final sep18 = DateTime(year, 9, 18);
    if (sep18.weekday == DateTime.tuesday) {
      addH(9, 17, 'Fiestas Patrias (Lunes 17)');
    } else if (sep18.weekday == DateTime.wednesday) {
      addH(9, 20, 'Fiestas Patrias (Viernes 20)');
    } else if (sep18.weekday == DateTime.saturday) {
      addH(9, 17, 'Fiestas Patrias (Viernes 17)');
    }

    // 3. Feriados Movibles (Pascua, Viernes Santo y Sábado Santo)
    final pascua = calcularPascua(year);
    final viernesSanto = pascua.subtract(const Duration(days: 2));
    final sabadoSanto = pascua.subtract(const Duration(days: 1));
    addH(viernesSanto.month, viernesSanto.day, 'Viernes Santo');
    addH(sabadoSanto.month, sabadoSanto.day, 'Sábado Santo');

    // 4. San Pedro y San Pablo (Ley N° 19.668 - Traslado al Lunes)
    final sanPedroBase = DateTime(year, 6, 29);
    if (sanPedroBase.weekday >= DateTime.tuesday && sanPedroBase.weekday <= DateTime.friday) {
      final lunes = sanPedroBase.subtract(Duration(days: sanPedroBase.weekday - DateTime.monday));
      addH(lunes.month, lunes.day, 'San Pedro y San Pablo');
    } else {
      addH(6, 29, 'San Pedro y San Pablo');
    }

    // 5. Encuentro de Dos Mundos (12 de Octubre - Ley N° 19.668 - Traslado al Lunes)
    final oct12Base = DateTime(year, 10, 12);
    if (oct12Base.weekday >= DateTime.tuesday && oct12Base.weekday <= DateTime.friday) {
      final lunes = oct12Base.subtract(Duration(days: oct12Base.weekday - DateTime.monday));
      addH(lunes.month, lunes.day, 'Encuentro de Dos Mundos');
    } else {
      addH(10, 12, 'Encuentro de Dos Mundos');
    }

    // 6. Día de las Iglesias Evangélicas (31 de Octubre - Ley N° 20.299)
    final oct31Base = DateTime(year, 10, 31);
    if (oct31Base.weekday == DateTime.tuesday) {
      addH(10, 27, 'Día de las Iglesias Evangélicas (Viernes 27)');
    } else if (oct31Base.weekday == DateTime.wednesday) {
      addH(11, 2, 'Día de las Iglesias Evangélicas (Viernes 2)');
    } else {
      addH(10, 31, 'Día de las Iglesias Evangélicas y Protestantes');
    }

    return list;
  }
}

class HolidaysRepository {
  /// Obtiene los feriados de un año determinado sin depender nunca de APIs externas ni lanzar excepciones.
  Future<List<Holiday>> getHolidays(int year, {bool forceRefresh = false}) async {
    return ChileHolidaysEngine.getHolidaysForYear(year);
  }
}
