import 'package:flutter_test/flutter_test.dart';
import 'package:procesal_plazos/domain/enums.dart';
import 'package:procesal_plazos/domain/models.dart';
import 'package:procesal_plazos/services/pdf_service.dart';

void main() {
  test('Genera un PDF individual válido para un cálculo almacenado', () async {
    final record = CalculationRecord(
      id: 'calculo-1',
      title: 'Contestación de demanda',
      startDate: DateTime(2026, 10, 1),
      endDate: DateTime(2026, 10, 15),
      baseDays: 10,
      additionalDays: 2,
      materia: Materia.civil,
      rolRuc: 'Rol C-123-2026',
      tipoLetra: 'Rol C',
      tribunal: 'Juzgado Civil - Santiago (Metropolitana)',
      materiaNombre: 'Derecho Procesal Civil',
      actuacionNombre: 'Contestación de demanda',
      articuloNorma: 'Art. 258 CPC',
      tipoComputoDesc: 'Días hábiles judiciales',
      elementosConsiderar: const ['Considerar los días feriados'],
    );

    final pdf = await PdfService.generateSingleCalculationPdf(record);

    expect(pdf.sublist(0, 5), equals([0x25, 0x50, 0x44, 0x46, 0x2D]));
    expect(pdf.length, greaterThan(1000));
  });
}
