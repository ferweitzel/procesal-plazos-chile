import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../domain/models.dart';

class PdfService {
  static final DateFormat _dateFormat = DateFormat('dd/MM/yyyy', 'es');
  static final DateFormat _dateTimeFormat = DateFormat("dd/MM/yyyy 'a las' HH:mm:ss 'hrs.'", 'es');
  static final DateFormat _longDateFormat = DateFormat("EEEE d 'de' MMMM 'de' yyyy", 'es');

  /// Genera un PDF detallado para un cálculo individual
  static Future<Uint8List> generateSingleCalculationPdf(CalculationRecord record) async {
    final pdf = pw.Document();

    final fontBase = pw.Font.helvetica();
    final fontBold = pw.Font.helveticaBold();

    final primaryColor = PdfColor.fromHex('#006633');
    final accentColor = PdfColor.fromHex('#1A202C');
    final lightBg = PdfColor.fromHex('#F7FAFC');

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.letter,
        margin: const pw.EdgeInsets.all(36),
        theme: pw.ThemeData.withFont(base: fontBase, bold: fontBold),
        build: (pw.Context context) {
          return [
            // Encabezado
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: primaryColor,
                borderRadius: pw.BorderRadius.circular(6),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'PLAZOS PROCESALES - DERECHO CHILENO',
                        style: pw.TextStyle(font: fontBold, fontSize: 16, color: PdfColors.white),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        'Comprobante Oficial de Cómputo y Vencimiento Legal',
                        style: pw.TextStyle(font: fontBase, fontSize: 10, color: PdfColors.white),
                      ),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        'FECHA DE CONSULTA:',
                        style: pw.TextStyle(font: fontBold, fontSize: 8, color: PdfColors.amber100),
                      ),
                      pw.Text(
                        _dateTimeFormat.format(record.consultationDate),
                        style: pw.TextStyle(font: fontBase, fontSize: 9, color: PdfColors.white),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 16),

            // Tarjeta de Resultado Principal (Fecha Máxima)
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(14),
              decoration: pw.BoxDecoration(
                color: PdfColor.fromHex('#E6FFFA'),
                border: pw.Border.all(color: primaryColor, width: 1.5),
                borderRadius: pw.BorderRadius.circular(6),
              ),
              child: pw.Column(
                children: [
                  pw.Text(
                    'FECHA MÁXIMA DE PRESENTACIÓN / VENCIMIENTO:',
                    style: pw.TextStyle(font: fontBold, fontSize: 11, color: primaryColor),
                  ),
                  pw.SizedBox(height: 6),
                  pw.Text(
                    '${_longDateFormat.format(record.endDate).toUpperCase()} a las 23:59:59 hrs.',
                    style: pw.TextStyle(font: fontBold, fontSize: 16, color: PdfColor.fromHex('#22543D')),
                    textAlign: pw.TextAlign.center,
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 16),

            // Cuadro 1: Identificación del Proceso
            pw.Text('1. IDENTIFICACIÓN DE LA CAUSA Y TRIBUNAL', style: pw.TextStyle(font: fontBold, fontSize: 12, color: accentColor)),
            pw.SizedBox(height: 6),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.8),
              children: [
                _buildTableRow(fontBold, fontBase, 'Rol / RUC / RIT:', record.rolRuc ?? 'No especificado'),
                _buildTableRow(fontBold, fontBase, 'Tipo de Causa / Letra:', record.tipoLetra ?? 'General'),
                _buildTableRow(fontBold, fontBase, 'Tribunal Competente:', record.tribunal ?? 'No especificado'),
              ],
            ),
            pw.SizedBox(height: 16),

            // Cuadro 2: Fundamento Legal y Materia
            pw.Text('2. MATERIA Y FUNDAMENTO NORMATIVO', style: pw.TextStyle(font: fontBold, fontSize: 12, color: accentColor)),
            pw.SizedBox(height: 6),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.8),
              children: [
                _buildTableRow(fontBold, fontBase, 'Materia:', record.materiaNombre ?? record.materia.name.toUpperCase()),
                _buildTableRow(fontBold, fontBase, 'Actuación Procesal:', record.actuacionNombre ?? record.title),
                _buildTableRow(fontBold, fontBase, 'Norma / Artículo:', record.articuloNorma ?? 'Código de Procedimiento / Ley Especial'),
                _buildTableRow(fontBold, fontBase, 'Regla de Cómputo:', record.tipoComputoDesc ?? 'Días Hábiles Judiciales (Art. 66 CPC)'),
              ],
            ),
            pw.SizedBox(height: 16),

            // Cuadro 3: Desglose de Días
            pw.Text('3. DESGLOSE DEL CÓMPUTO DEL PLAZO', style: pw.TextStyle(font: fontBold, fontSize: 12, color: accentColor)),
            pw.SizedBox(height: 6),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.8),
              children: [
                _buildTableRow(fontBold, fontBase, 'Fecha Notificación / Inicio:', _dateFormat.format(record.startDate)),
                _buildTableRow(fontBold, fontBase, 'Plazo Base Legal:', '${record.baseDays} días'),
                _buildTableRow(fontBold, fontBase, 'Aumento Tabla Emplazamiento:', '${record.additionalDays} días'),
                _buildTableRow(fontBold, fontBase, 'Plazo Total Computado:', '${record.baseDays + record.additionalDays} días'),
              ],
            ),

            // Cuadro 4: Checklist Legal si existe
            if (record.elementosConsiderar != null && record.elementosConsiderar!.isNotEmpty) ...[
              pw.SizedBox(height: 16),
              pw.Text('4. ELEMENTOS Y CONSIDERACIONES ADICIONALES (CHECKLIST)', style: pw.TextStyle(font: fontBold, fontSize: 12, color: accentColor)),
              pw.SizedBox(height: 6),
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  color: lightBg,
                  border: pw.Border.all(color: PdfColors.grey300),
                  borderRadius: pw.BorderRadius.circular(4),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: record.elementosConsiderar!.map((elem) {
                    return pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(vertical: 2),
                      child: pw.Row(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('• ', style: pw.TextStyle(font: fontBold, color: primaryColor)),
                          pw.Expanded(child: pw.Text(elem, style: pw.TextStyle(font: fontBase, fontSize: 9))),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],

            pw.Spacer(),

            // Pie de Página
            pw.Divider(color: PdfColors.grey400, thickness: 0.5),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Generado por Sistema Procesal Plazos Chile - Weitzel.cl', style: pw.TextStyle(font: fontBase, fontSize: 8, color: PdfColors.grey600)),
                pw.Text('Página 1 de 1', style: pw.TextStyle(font: fontBase, fontSize: 8, color: PdfColors.grey600)),
              ],
            ),
          ];
        },
      ),
    );

    return pdf.save();
  }

  /// Genera un PDF con la tabla completa del historial persistente de consultas
  static Future<Uint8List> generateHistoryTablePdf(List<CalculationRecord> records) async {
    final pdf = pw.Document();

    final fontBase = pw.Font.helvetica();
    final fontBold = pw.Font.helveticaBold();

    final primaryColor = PdfColor.fromHex('#006633');

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.letter.landscape,
        margin: const pw.EdgeInsets.all(28),
        theme: pw.ThemeData.withFont(base: fontBase, bold: fontBold),
        build: (pw.Context context) {
          return [
            // Encabezado
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'HISTORIAL REGISTRADO DE CONSULTAS DE PLAZOS PROCESALES',
                      style: pw.TextStyle(font: fontBold, fontSize: 14, color: primaryColor),
                    ),
                    pw.Text(
                      'Registro Persistente de Cálculos de Plazos Legales - Chile',
                      style: pw.TextStyle(font: fontBase, fontSize: 9, color: PdfColors.grey700),
                    ),
                  ],
                ),
                pw.Text(
                  'Fecha Emisión: ${_dateTimeFormat.format(DateTime.now())}',
                  style: pw.TextStyle(font: fontBase, fontSize: 8, color: PdfColors.grey700),
                ),
              ],
            ),
            pw.SizedBox(height: 12),

            // Tabla de Registros
            pw.TableHelper.fromTextArray(
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
              headerStyle: pw.TextStyle(font: fontBold, fontSize: 8, color: PdfColors.white),
              headerDecoration: pw.BoxDecoration(color: primaryColor),
              cellStyle: pw.TextStyle(font: fontBase, fontSize: 8),
              cellPadding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              headers: [
                'N°',
                'Fecha Consulta',
                'Rol / RUC',
                'Tribunal',
                'Actuación / Materia',
                'Notificación',
                'Plazo Total',
                'Vencimiento'
              ],
              data: List<List<String>>.generate(records.length, (index) {
                final r = records[index];
                final rol = r.rolRuc != null && r.rolRuc!.isNotEmpty ? r.rolRuc! : '-';
                final trib = r.tribunal != null && r.tribunal!.isNotEmpty ? r.tribunal! : '-';
                final act = r.actuacionNombre ?? r.title;
                final plazo = '${r.baseDays}${r.additionalDays > 0 ? " + ${r.additionalDays}d" : ""}d';

                return [
                  (index + 1).toString(),
                  _dateFormat.format(r.consultationDate),
                  rol,
                  trib,
                  act,
                  _dateFormat.format(r.startDate),
                  plazo,
                  _dateFormat.format(r.endDate),
                ];
              }),
            ),

            pw.SizedBox(height: 12),
            pw.Text(
              'Total de registros consultados: ${records.length}',
              style: pw.TextStyle(font: fontBold, fontSize: 9, color: PdfColors.grey800),
            ),
          ];
        },
      ),
    );

    return pdf.save();
  }

  /// Muestra la vista previa / diálogo de impresión / guardado para un PDF individual
  static Future<void> previewOrPrintSinglePdf(CalculationRecord record) async {
    final pdfBytes = await generateSingleCalculationPdf(record);
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdfBytes,
      name: 'Plazo_Procesal_${record.rolRuc ?? record.id}.pdf',
    );
  }

  /// Muestra la vista previa / impresión del informe en tabla de historial
  static Future<void> previewOrPrintHistoryTablePdf(List<CalculationRecord> records) async {
    final pdfBytes = await generateHistoryTablePdf(records);
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdfBytes,
      name: 'Historial_Plazos_Procesales_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf',
    );
  }

  static pw.TableRow _buildTableRow(pw.Font fontBold, pw.Font fontBase, String label, String value) {
    return pw.TableRow(
      children: [
        pw.Padding(
          padding: const pw.EdgeInsets.all(6),
          child: pw.Text(label, style: pw.TextStyle(font: fontBold, fontSize: 9, color: PdfColor.fromHex('#2D3748'))),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.all(6),
          child: pw.Text(value, style: pw.TextStyle(font: fontBase, fontSize: 9, color: PdfColor.fromHex('#1A202C'))),
        ),
      ],
    );
  }
}
