import 'package:flutter_test/flutter_test.dart';
import 'package:procesal_plazos/core/deadline_calculator.dart';
import 'package:procesal_plazos/domain/enums.dart';
import 'package:procesal_plazos/domain/holiday.dart';

void main() {
  group('DeadlineCalculator Tests', () {
    // Feriados simulados (Fiestas Patrias)
    final feriados = [
      Holiday(
        date: DateTime(2025, 9, 18),
        name: 'Independencia Nacional',
        isIrrenunciable: true,
      ),
      Holiday(
        date: DateTime(2025, 9, 19),
        name: 'Día de las Glorias del Ejército',
        isIrrenunciable: true,
      ),
    ];

    test('Cómputo Judicial (Art. 59 CPC) - Excluye Domingos y Feriados', () {
      // Martes 16 de septiembre 2025
      final inicio = DateTime(2025, 9, 16);
      
      // Plazo: 3 días judiciales
      // Día 1: Miércoles 17
      // Jueves 18 (Feriado - Salta)
      // Viernes 19 (Feriado - Salta)
      // Día 2: Sábado 20
      // Domingo 21 (Inhábil - Salta)
      // Día 3: Lunes 22
      
      final resultado = DeadlineCalculator.calcularPlazo(
        inicio,
        3,
        TipoComputo.judicial,
        feriados,
      );

      expect(resultado.year, 2025);
      expect(resultado.month, 9);
      expect(resultado.day, 22);
      expect(resultado.hour, 23);
      expect(resultado.minute, 59);
    });

    test('Cómputo Administrativo (Art. 25 Ley 19.880) - Excluye Sábado, Domingo y Feriados', () {
      // Martes 16 de septiembre 2025
      final inicio = DateTime(2025, 9, 16);
      
      // Plazo: 3 días administrativos
      // Día 1: Miércoles 17
      // Jueves 18 (Feriado - Salta)
      // Viernes 19 (Feriado - Salta)
      // Sábado 20 (Inhábil adm. - Salta)
      // Domingo 21 (Inhábil adm. - Salta)
      // Día 2: Lunes 22
      // Día 3: Martes 23
      
      final resultado = DeadlineCalculator.calcularPlazo(
        inicio,
        3,
        TipoComputo.administrativo,
        feriados,
      );

      expect(resultado.day, 23);
    });

    test('Cómputo Corridos (Art. 14 CPP) - Sin prorroga (vence en día hábil)', () {
      // Lunes 15 de septiembre 2025
      final inicio = DateTime(2025, 9, 15);
      
      // Plazo: 2 días corridos
      // Día 1: Martes 16
      // Día 2: Miércoles 17 (Hábil, aquí vence)
      
      final resultado = DeadlineCalculator.calcularPlazo(
        inicio,
        2,
        TipoComputo.corridos,
        feriados,
      );

      expect(resultado.day, 17);
    });

    test('Cómputo Corridos (Art. 14 CPP) - Con prorroga por feriado', () {
      // Martes 16 de septiembre 2025
      final inicio = DateTime(2025, 9, 16);
      
      // Plazo: 2 días corridos
      // Día 1: Miércoles 17
      // Día 2: Jueves 18 (Vence en feriado) -> Se prorroga
      // Viernes 19 (Feriado, sigue prórroga)
      // Sábado 20 (Hábil judicial, finaliza prórroga)
      
      final resultado = DeadlineCalculator.calcularPlazo(
        inicio,
        2,
        TipoComputo.corridos,
        feriados,
      );

      expect(resultado.day, 20); // El sábado es día hábil judicial, termina la prórroga
    });
  });
}
