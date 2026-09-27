import 'enums.dart';

class CalculationRecord {
  final String id;
  final String title;
  final DateTime startDate;
  final DateTime endDate;
  final DateTime consultationDate;
  final int baseDays;
  final int additionalDays;
  final Materia materia;

  final String? rolRuc;
  final String? tipoLetra;
  final String? numeroCausa;
  final String? anioCausa;
  final String? tribunal;
  final TipoActuacion? tipoActuacion;

  final String? materiaNombre;
  final String? actuacionNombre;
  final String? articuloNorma;
  final String? tipoComputoDesc;
  final List<String>? elementosConsiderar;

  CalculationRecord({
    required this.id,
    required this.title,
    required this.startDate,
    required this.endDate,
    DateTime? consultationDate,
    required this.baseDays,
    required this.additionalDays,
    required this.materia,
    this.rolRuc,
    this.tipoLetra,
    this.numeroCausa,
    this.anioCausa,
    this.tribunal,
    this.tipoActuacion,
    this.materiaNombre,
    this.actuacionNombre,
    this.articuloNorma,
    this.tipoComputoDesc,
    this.elementosConsiderar,
  }) : consultationDate = consultationDate ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate.toIso8601String(),
      'consultationDate': consultationDate.toIso8601String(),
      'baseDays': baseDays,
      'additionalDays': additionalDays,
      'materia': materia.name,
      'rolRuc': rolRuc,
      'tipoLetra': tipoLetra,
      'numeroCausa': numeroCausa,
      'anioCausa': anioCausa,
      'tribunal': tribunal,
      'tipoActuacion': tipoActuacion?.name,
      'materiaNombre': materiaNombre,
      'actuacionNombre': actuacionNombre,
      'articuloNorma': articuloNorma,
      'tipoComputoDesc': tipoComputoDesc,
      'elementosConsiderar': elementosConsiderar,
    };
  }

  factory CalculationRecord.fromMap(Map<String, dynamic> map) {
    return CalculationRecord(
      id: map['id'] ?? '',
      title: map['title'] ?? 'Cálculo de Plazo',
      startDate: map['startDate'] != null ? DateTime.parse(map['startDate']) : DateTime.now(),
      endDate: map['endDate'] != null ? DateTime.parse(map['endDate']) : DateTime.now(),
      consultationDate: map['consultationDate'] != null ? DateTime.parse(map['consultationDate']) : DateTime.now(),
      baseDays: map['baseDays'] ?? 0,
      additionalDays: map['additionalDays'] ?? 0,
      materia: map['materia'] != null
          ? Materia.values.firstWhere((e) => e.name == map['materia'], orElse: () => Materia.civil)
          : Materia.civil,
      rolRuc: map['rolRuc'],
      tipoLetra: map['tipoLetra'],
      numeroCausa: map['numeroCausa'],
      anioCausa: map['anioCausa'],
      tribunal: map['tribunal'],
      tipoActuacion: map['tipoActuacion'] != null
          ? TipoActuacion.values.firstWhere((e) => e.name == map['tipoActuacion'], orElse: () => TipoActuacion.values.first)
          : null,
      materiaNombre: map['materiaNombre'],
      actuacionNombre: map['actuacionNombre'],
      articuloNorma: map['articuloNorma'],
      tipoComputoDesc: map['tipoComputoDesc'],
      elementosConsiderar: map['elementosConsiderar'] != null
          ? List<String>.from(map['elementosConsiderar'])
          : null,
    );
  }
}
