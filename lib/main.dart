import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import 'data/history_repository.dart';
import 'domain/enums.dart';
import 'domain/models.dart';
import 'services/pdf_service.dart';

void main() {
  runApp(const PlazosProcesalesApp());
}

class PlazosProcesalesApp extends StatelessWidget {
  const PlazosProcesalesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Plazos Procesales by Weitzel.cl',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0D0F12),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF00FF66),
          surface: Color(0xFF161A22),
          onSurface: Colors.white,
        ),
        cardColor: const Color(0xFF161A22),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF1C222D),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFF00FF66), width: 1),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFF2E3848)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFF00FF66), width: 2),
          ),
          labelStyle: const TextStyle(color: Color(0xFFA0AEC0)),
        ),
      ),
      home: const PlazosProcesalesScreen(),
    );
  }
}

// -----------------------------------------------------------------------------
// MODELOS Y ENUMERACIONES
// -----------------------------------------------------------------------------

enum TipoComputoDias {
  habilesCivil,  // Excluye domingos y festivos (Art. 66 CPC)
  habilesAdmin,  // Excluye sábados, domingos y festivos (Art. 25 Ley 19.880)
  corridos,      // Corridos (Art. 14 CPP / Auto Acordados)
  habilesLaboral // Excluye domingos y festivos
}

class MateriaSubmateria {
  final String id;
  final String granGrupo;
  final String rama;
  final String submateria;
  final String normativa;

  MateriaSubmateria({required this.id, required this.granGrupo, required this.rama, required this.submateria, required this.normativa});
  String get displayName => '[$granGrupo] $rama - $submateria\n($normativa)';
}

class ActuacionProcesal {
  final String id;
  final String materiaId;
  final String nombreActuacion;
  final String rolProcesal;
  final String tipoInstitucion;
  final String articuloYNorma;
  final int diasBase;
  final TipoComputoDias tipoComputo;
  final bool admiteEmplazamiento;
  final List<String> elementosAConsiderar;

  ActuacionProcesal({
    required this.id, required this.materiaId, required this.nombreActuacion,
    required this.rolProcesal, required this.tipoInstitucion, required this.articuloYNorma,
    required this.diasBase, required this.tipoComputo, this.admiteEmplazamiento = false,
    required this.elementosAConsiderar,
  });

  String get displayName => '$nombreActuacion [$articuloYNorma]';
}

class TribunalItem {
  final String nombre;
  final String comuna;
  final String region;
  final int diasAumentoEmplazamiento;

  TribunalItem({required this.nombre, required this.comuna, required this.region, this.diasAumentoEmplazamiento = 0});
}

// -----------------------------------------------------------------------------
// BASE DE DATOS JURÍDICA AMPLIADA (DERECHO CHILENO COMPLETO)
// -----------------------------------------------------------------------------

class LegalDatabase {
  static final List<MateriaSubmateria> materias = [
    // a. DERECHO LABORAL Y PREVISIONAL
    MateriaSubmateria(
      id: 'mix_lab_despido',
      granGrupo: 'a. Derecho Laboral y Previsional',
      rama: 'Despido e Indemnizaciones (Código del Trabajo)',
      submateria: 'Despido Injustificado, Indebido, Improcedente y Ley Bustos (Nulidad del Despido por Cotizaciones)',
      normativa: 'Arts. 162, 168 y 446 del Código del Trabajo (CT)',
    ),
    MateriaSubmateria(
      id: 'mix_lab_tutela',
      granGrupo: 'a. Derecho Laboral y Previsional',
      rama: 'Tutela Laboral y Derechos Fundamentales',
      submateria: 'Vulneración de Derechos Fundamentales durante la Relación Laboral o con Ocasión del Despido',
      normativa: 'Arts. 485 a 495 del Código del Trabajo (CT)',
    ),
    MateriaSubmateria(
      id: 'mix_lab_monitorio_ejec',
      granGrupo: 'a. Derecho Laboral y Previsional',
      rama: 'Procedimiento Monitorio y Cobranza Laboral',
      submateria: 'Reclamos hasta 10 UTM, Cobro de Finiquitos, Títulos Ejecutivos y Multas Dirección del Trabajo',
      normativa: 'Arts. 463, 496 y 503 del Código del Trabajo y Ley N° 20.022',
    ),

    // b. DERECHO PROCESAL CIVIL Y ARRENDAMIENTO
    MateriaSubmateria(
      id: 'priv_civ_ord',
      granGrupo: 'b. Derecho Procesal Civil',
      rama: 'Juicio Ordinario y Sumario Civil',
      submateria: 'Demanda, Contestación, Excepciones, Réplica, Dúplica y Recursos Civiles',
      normativa: 'Código de Procedimiento Civil (CPC) - Arts. 253 y ss.',
    ),
    MateriaSubmateria(
      id: 'priv_civ_ejec',
      granGrupo: 'b. Derecho Procesal Civil',
      rama: 'Juicio Ejecutivo y Embargos',
      submateria: 'Mandamiento de Ejecución, Oposición de Excepciones y Réplica Ejecutiva',
      normativa: 'Código de Procedimiento Civil (CPC) - Arts. 434 a 529',
    ),
    MateriaSubmateria(
      id: 'priv_civ_arriendo',
      granGrupo: 'b. Derecho Procesal Civil',
      rama: 'Arrendamiento de Predios Urbanos y Precario',
      submateria: 'Ley Devuélveme Mi Casa (Ley N° 21.461 y N° 18.101), Cobro de Rentas y Precario',
      normativa: 'Ley N° 18.101, Ley N° 21.461 y Art. 2195 Código Civil',
    ),

    // c. DERECHO DE FAMILIA
    MateriaSubmateria(
      id: 'mix_fam_alimentos',
      granGrupo: 'c. Derecho de Familia',
      rama: 'Pensión de Alimentos y Cumplimiento',
      submateria: 'Fijación, Aumento, Rebaja, Cese de Alimentos y Registro de Deudores',
      normativa: 'Ley N° 14.908, Ley N° 21.389 y Ley N° 19.968',
    ),
    MateriaSubmateria(
      id: 'mix_fam_cuidado_divorcio',
      granGrupo: 'c. Derecho de Familia',
      rama: 'Cuidado Personal, Visitas, Divorcio y Compensación',
      submateria: 'Tuición, Relación Directa y Regular, Divorcio Unilateral/Mutuo Acuerdo y Compensación Económica',
      normativa: 'Ley N° 19.947 (Matrimonio Civil) y Código Civil',
    ),
    MateriaSubmateria(
      id: 'mix_fam_vif_proteccion',
      granGrupo: 'c. Derecho de Familia',
      rama: 'Violencia Intrafamiliar, Protección NNA y Filiación',
      submateria: 'Medidas Cautelares VIF, Medidas de Protección NNA y Juicios de Paternidad/Filiación',
      normativa: 'Ley N° 20.066, Ley N° 19.968 y Arts. 179 y ss. CC',
    ),

    // d. DERECHO PROCESAL PENAL
    MateriaSubmateria(
      id: 'pub_penal',
      granGrupo: 'd. Derecho Procesal Penal',
      rama: 'Procedimiento Penal y Recursos',
      submateria: 'Juicio Oral, Garantía, Procedimiento Simplificado, Abreviado, Amparo y Nulidad Penal',
      normativa: 'Código Procesal Penal (CPP) - Arts. 95, 366, 372',
    ),

    // e. DERECHO TRIBUTARIO Y ADUANERO
    MateriaSubmateria(
      id: 'pub_trib',
      granGrupo: 'e. Derecho Tributario y Aduanero',
      rama: 'Reclamaciones TTA y SII',
      submateria: 'Reclamación Tributaria contra Liquidaciones o Giros (SII/TTA) y Reposición RAF/RAV',
      normativa: 'Código Tributario (DL N° 830) y Ordenanza de Aduanas',
    ),

    // f. JUZGADOS DE POLICÍA LOCAL
    MateriaSubmateria(
      id: 'mix_pol_loc',
      granGrupo: 'f. Juzgados de Policía Local',
      rama: 'Tránsito, Consumidor y Copropiedad Inmobiliaria',
      submateria: 'Infracciones y Accidentes de Tránsito, Ley del Consumidor (LPDC) y Ley de Copropiedad',
      normativa: 'Ley N° 18.287 (JPL), Ley N° 18.290, Ley N° 19.496 y Ley N° 21.442',
    ),

    // g. DERECHO CONSTITUCIONAL Y ADMINISTRATIVO
    MateriaSubmateria(
      id: 'pub_const',
      granGrupo: 'g. Derecho Constitucional y Administrativo',
      rama: 'Acciones Constitucionales y Procedimiento Administrativo',
      submateria: 'Recurso de Protección, Amparo, Reclamo de Ilegalidad y Recursos Ley 19.880',
      normativa: 'Constitución Política (Arts. 20, 21), Ley N° 19.880 y Ley N° 18.695',
    ),
    MateriaSubmateria(
      id: 'pub_tc',
      granGrupo: 'g. Derecho Constitucional y Administrativo',
      rama: 'Justicia Constitucional (TC)',
      submateria: 'Inaplicabilidad e Inconstitucionalidad de Leyes ante el Tribunal Constitucional',
      normativa: 'Constitución (Art. 93) y Ley N° 17.997 (LOC TC)',
    ),
  ];

  static final List<ActuacionProcesal> actuaciones = [
    // ==========================================
    // 1. DERECHO LABORAL Y PREVISIONAL
    // ==========================================
    ActuacionProcesal(
      id: 'lab_despido_injustificado', materiaId: 'mix_lab_despido',
      nombreActuacion: 'Demanda por Despido Injustificado / Indebido (Art. 168 CT)', rolProcesal: 'Trabajador Demandante',
      tipoInstitucion: 'Juicio Ordinario Laboral', articuloYNorma: 'Art. 168 y 446 Código del Trabajo',
      diasBase: 60, tipoComputo: TipoComputoDias.habilesLaboral, admiteEmplazamiento: false,
      elementosAConsiderar: ['60 días hábiles laborales desde la separación del trabajador', 'Suspensión del plazo por reclamo administrativo ante la Inspección del Trabajo (hasta un máximo de 90 días hábiles)']
    ),
    ActuacionProcesal(
      id: 'lab_ley_bustos', materiaId: 'mix_lab_despido',
      nombreActuacion: 'Acción de Nulidad del Despido / Ley Bustos por Cotizaciones Impagas', rolProcesal: 'Trabajador Demandante',
      tipoInstitucion: 'Nulidad del Despido (Art. 162 CT)', articuloYNorma: 'Art. 162 inc. 5° a 7° Código del Trabajo',
      diasBase: 60, tipoComputo: TipoComputoDias.habilesLaboral, admiteEmplazamiento: false,
      elementosAConsiderar: ['Sanción de pago de remuneraciones y cotizaciones desde el despido hasta la convalidación en tribunal', 'Acreditar morosidad o no pago de AFP/Isapre/Fonasa/AFC']
    ),
    ActuacionProcesal(
      id: 'lab_tutela_despido', materiaId: 'mix_lab_tutela',
      nombreActuacion: 'Tutela Laboral por Vulneración de Derechos con Ocasión del Despido', rolProcesal: 'Trabajador Demandante',
      tipoInstitucion: 'Procedimiento de Tutela Laboral', articuloYNorma: 'Art. 485 y 489 Código del Trabajo',
      diasBase: 60, tipoComputo: TipoComputoDias.habilesLaboral, admiteEmplazamiento: false,
      elementosAConsiderar: ['60 días hábiles laborales desde el despido vulneratorio', 'Opcionalidad de indemnización adicional de 6 a 11 meses de remuneración']
    ),
    ActuacionProcesal(
      id: 'lab_tutela_vigente', materiaId: 'mix_lab_tutela',
      nombreActuacion: 'Tutela Laboral Durante la Relación Laboral Vigente', rolProcesal: 'Trabajador Demandante',
      tipoInstitucion: 'Procedimiento de Tutela Laboral', articuloYNorma: 'Art. 485 y 486 Código del Trabajo',
      diasBase: 60, tipoComputo: TipoComputoDias.habilesLaboral, admiteEmplazamiento: false,
      elementosAConsiderar: ['60 días hábiles laborales desde la vulneración del derecho fundamental en la empresa']
    ),
    ActuacionProcesal(
      id: 'lab_monitorio', materiaId: 'mix_lab_monitorio_ejec',
      nombreActuacion: 'Demanda Monitoria Laboral (Cuantía ≤ 10 UTM)', rolProcesal: 'Trabajador Demandante',
      tipoInstitucion: 'Procedimiento Monitorio Laboral', articuloYNorma: 'Art. 496 y ss. Código del Trabajo',
      diasBase: 60, tipoComputo: TipoComputoDias.habilesLaboral, admiteEmplazamiento: false,
      elementosAConsiderar: ['Exige reclamo administrativo previo ante la Inspección del Trabajo', 'Resolución inmediata o citación a audiencia única']
    ),
    ActuacionProcesal(
      id: 'lab_contestacion_ord', materiaId: 'mix_lab_despido',
      nombreActuacion: 'Contestación de Demanda Laboral en Juicio Ordinario', rolProcesal: 'Demandado (Empleador)',
      tipoInstitucion: 'Defensa Laboral de Fondo', articuloYNorma: 'Art. 452 y 453 Código del Trabajo',
      diasBase: 5, tipoComputo: TipoComputoDias.habilesLaboral, admiteEmplazamiento: false,
      elementosAConsiderar: ['Presentación escrita hasta 5 días antes de la fecha fijada para la audiencia preparatoria']
    ),
    ActuacionProcesal(
      id: 'lab_ejecutivo_opose', materiaId: 'mix_lab_monitorio_ejec',
      nombreActuacion: 'Oposición de Excepciones en Cobranza Laboral / Previsional', rolProcesal: 'Ejecutado (Empleador)',
      tipoInstitucion: 'Defensa Ejecutiva Laboral', articuloYNorma: 'Art. 463 y 464 Código del Trabajo',
      diasBase: 5, tipoComputo: TipoComputoDias.habilesLaboral, admiteEmplazamiento: false,
      elementosAConsiderar: ['Excepciones específicas en materia de cobranza laboral dentro de 5 días desde el requerimiento']
    ),
    ActuacionProcesal(
      id: 'lab_reclamo_multa_dt', materiaId: 'mix_lab_monitorio_ejec',
      nombreActuacion: 'Reclamación Judicial contra Multas de la Dirección del Trabajo', rolProcesal: 'Empresa / Empleador',
      tipoInstitucion: 'Contencioso Administrativo Laboral', articuloYNorma: 'Art. 503 Código del Trabajo',
      diasBase: 15, tipoComputo: TipoComputoDias.habilesLaboral, admiteEmplazamiento: false,
      elementosAConsiderar: ['15 días hábiles desde la notificación de la resolución o multa administrativa de la DT']
    ),
    ActuacionProcesal(
      id: 'lab_recurso_nulidad', materiaId: 'mix_lab_despido',
      nombreActuacion: 'Recurso de Nulidad Laboral (Corte de Apelaciones)', rolProcesal: 'Parte Agraviada',
      tipoInstitucion: 'Recurso Laboral de Alzada', articuloYNorma: 'Art. 477 y 478 Código del Trabajo',
      diasBase: 10, tipoComputo: TipoComputoDias.habilesLaboral, admiteEmplazamiento: false,
      elementosAConsiderar: ['10 días hábiles laborales desde la notificación de la sentencia definitiva laboral']
    ),
    ActuacionProcesal(
      id: 'lab_recurso_unificacion', materiaId: 'mix_lab_despido',
      nombreActuacion: 'Recurso de Unificación de Jurisprudencia (Corte Suprema)', rolProcesal: 'Parte Agraviada',
      tipoInstitucion: 'Recurso Laboral ante Corte Suprema', articuloYNorma: 'Art. 483 Código del Trabajo',
      diasBase: 15, tipoComputo: TipoComputoDias.habilesLaboral, admiteEmplazamiento: false,
      elementosAConsiderar: ['15 días hábiles laborales desde el fallo de nulidad que contenga interpretaciones contradictorias']
    ),

    // ==========================================
    // 2. DERECHO PROCESAL CIVIL Y ARRENDAMIENTO
    // ==========================================
    ActuacionProcesal(
      id: 'civ_dilatorias', materiaId: 'priv_civ_ord',
      nombreActuacion: 'Oposición de Excepciones Dilatorias', rolProcesal: 'Demandado',
      tipoInstitucion: 'Incidentes / Objeción de Forma', articuloYNorma: 'Art. 305 CPC',
      diasBase: 8, tipoComputo: TipoComputoDias.habilesCivil, admiteEmplazamiento: true,
      elementosAConsiderar: ['Deben oponerse todas en un mismo escrito y dentro del término del emplazamiento', 'Suspenden el procedimiento principal']
    ),
    ActuacionProcesal(
      id: 'civ_contesta', materiaId: 'priv_civ_ord',
      nombreActuacion: 'Contestación de la Demanda Ordinaria Civil', rolProcesal: 'Demandado',
      tipoInstitucion: 'Defensa de Fondo / Reconvención', articuloYNorma: 'Art. 258 CPC',
      diasBase: 18, tipoComputo: TipoComputoDias.habilesCivil, admiteEmplazamiento: true,
      elementosAConsiderar: ['Aumento por tabla de emplazamiento según distancia', 'Oportunidad para entablar demanda reconvencional']
    ),
    ActuacionProcesal(
      id: 'civ_replica', materiaId: 'priv_civ_ord',
      nombreActuacion: 'Réplica Civil', rolProcesal: 'Demandante',
      tipoInstitucion: 'Alegación Written', articuloYNorma: 'Art. 311 CPC',
      diasBase: 6, tipoComputo: TipoComputoDias.habilesCivil, admiteEmplazamiento: false,
      elementosAConsiderar: ['Ampliación o modificación de peticiones sin alterar la acción deducida en la demanda']
    ),
    ActuacionProcesal(
      id: 'civ_duplica', materiaId: 'priv_civ_ord',
      nombreActuacion: 'Dúplica Civil', rolProcesal: 'Demandado',
      tipoInstitucion: 'Alegación Written', articuloYNorma: 'Art. 312 CPC',
      diasBase: 6, tipoComputo: TipoComputoDias.habilesCivil, admiteEmplazamiento: false,
      elementosAConsiderar: ['Última oportunidad de alegación escrita antes de la fase de prueba o citación a oír sentencia']
    ),
    ActuacionProcesal(
      id: 'ejec_opone', materiaId: 'priv_civ_ejec',
      nombreActuacion: 'Oposición a la Ejecución en Juicio Ejecutivo (Excepciones)', rolProcesal: 'Ejecutado',
      tipoInstitucion: 'Defensa Ejecutiva', articuloYNorma: 'Art. 459 CPC (Ley N° 21.394)',
      diasBase: 8, tipoComputo: TipoComputoDias.habilesCivil, admiteEmplazamiento: true,
      elementosAConsiderar: ['Excepciones taxativas del Art. 464 CPC', 'Señalar medios de prueba en el mismo escrito de oposición']
    ),
    ActuacionProcesal(
      id: 'ejec_replica_excepciones', materiaId: 'priv_civ_ejec',
      nombreActuacion: 'Réplica a las Excepciones del Ejecutado', rolProcesal: 'Ejecutante',
      tipoInstitucion: 'Evacuación de Traslado', articuloYNorma: 'Art. 469 CPC',
      diasBase: 4, tipoComputo: TipoComputoDias.habilesCivil, admiteEmplazamiento: false,
      elementosAConsiderar: ['Contestación a las excepciones opuestas por el ejecutado con citación']
    ),
    ActuacionProcesal(
      id: 'civ_arriendo_devuelveme', materiaId: 'priv_civ_arriendo',
      nombreActuacion: 'Demanda de Restitución e Inmueble - Ley Devuélveme Mi Casa (Ley N° 21.461)', rolProcesal: 'Arrendador / Demandante',
      tipoInstitucion: 'Juicio Especial de Arrendamiento', articuloYNorma: 'Ley N° 18.101 y Ley N° 21.461',
      diasBase: 10, tipoComputo: TipoComputoDias.habilesCivil, admiteEmplazamiento: false,
      elementosAConsiderar: ['Medida cautelar de restitución precautoria por morosidad o consumo de servicios', 'Requerimiento de pago de 10 días']
    ),
    ActuacionProcesal(
      id: 'civ_precario', materiaId: 'priv_civ_arriendo',
      nombreActuacion: 'Juicio Sumario de Precario (Restitución Inmueble sin Título)', rolProcesal: 'Dueño / Demandante',
      tipoInstitucion: 'Juicio Sumario Especial', articuloYNorma: 'Art. 2195 inc. 2° Código Civil',
      diasBase: 5, tipoComputo: TipoComputoDias.habilesCivil, admiteEmplazamiento: false,
      elementosAConsiderar: ['Audiencia de contestación y conciliación al 5° día hábil tras la notificación']
    ),
    ActuacionProcesal(
      id: 'civ_repo', materiaId: 'priv_civ_ord',
      nombreActuacion: 'Recurso de Reposición (Contra Autos y Decretos)', rolProcesal: 'Agraviado',
      tipoInstitucion: 'Recurso Ordinario', articuloYNorma: 'Art. 181 CPC',
      diasBase: 3, tipoComputo: TipoComputoDias.habilesCivil, admiteEmplazamiento: false,
      elementosAConsiderar: ['Debe interponerse por escrito con fundamentos claros y precisos']
    ),
    ActuacionProcesal(
      id: 'civ_apelacion_def', materiaId: 'priv_civ_ord',
      nombreActuacion: 'Apelación contra Sentencia Definitiva Civil', rolProcesal: 'Agraviado',
      tipoInstitucion: 'Recurso Ordinario de Alzada', articuloYNorma: 'Art. 189 CPC',
      diasBase: 10, tipoComputo: TipoComputoDias.habilesCivil, admiteEmplazamiento: false,
      elementosAConsiderar: ['Fundamentos de hecho y derecho', 'Peticiones concretas exigidas por la Ley N° 20.886 / autos acordados']
    ),
    ActuacionProcesal(
      id: 'civ_apelacion_inter', materiaId: 'priv_civ_ord',
      nombreActuacion: 'Apelación contra Sentencia Interlocutoria Civil', rolProcesal: 'Agraviado',
      tipoInstitucion: 'Recurso Ordinario de Alzada', articuloYNorma: 'Art. 189 CPC',
      diasBase: 5, tipoComputo: TipoComputoDias.habilesCivil, admiteEmplazamiento: false,
      elementosAConsiderar: ['Procede contra interlocutorias que pongan término al juicio o hagan imposible su continuación']
    ),
    ActuacionProcesal(
      id: 'civ_casacion_forma', materiaId: 'priv_civ_ord',
      nombreActuacion: 'Recurso de Casación en la Forma / Fondo Civil', rolProcesal: 'Agraviado',
      tipoInstitucion: 'Recurso Extraordinario', articuloYNorma: 'Art. 770 CPC',
      diasBase: 15, tipoComputo: TipoComputoDias.habilesCivil, admiteEmplazamiento: false,
      elementosAConsiderar: ['Infracción de ley con influencia sustancial en lo dispositivo de la sentencia', 'Patrocinio especial Corte Suprema']
    ),

    // ==========================================
    // 3. DERECHO DE FAMILIA
    // ==========================================
    ActuacionProcesal(
      id: 'fam_alimentos_contesta', materiaId: 'mix_fam_alimentos',
      nombreActuacion: 'Contestación Demanda de Alimentos (Fijación, Aumento, Rebaja o Cese)', rolProcesal: 'Demandado / Alimentante',
      tipoInstitucion: 'Procedimiento de Alimentos', articuloYNorma: 'Ley N° 14.908 y Art. 59 Ley N° 19.968',
      diasBase: 5, tipoComputo: TipoComputoDias.habilesCivil, admiteEmplazamiento: false,
      elementosAConsiderar: ['Por escrito hasta 5 días antes de la audiencia preparatoria con liquidación y liquidaciones de sueldo']
    ),
    ActuacionProcesal(
      id: 'fam_cuidado_personal', materiaId: 'mix_fam_cuidado_divorcio',
      nombreActuacion: 'Demanda de Cuidado Personal / Tuición de Hijos', rolProcesal: 'Padre / Madre Demandante',
      tipoInstitucion: 'Procedimiento Ordinario Familia', articuloYNorma: 'Art. 225 Código Civil y Ley N° 19.968',
      diasBase: 5, tipoComputo: TipoComputoDias.habilesCivil, admiteEmplazamiento: false,
      elementosAConsiderar: ['Contestación escrita hasta 5 días antes de la audiencia preparatoria; informes psicosociales']
    ),
    ActuacionProcesal(
      id: 'fam_relacion_directa', materiaId: 'mix_fam_cuidado_divorcio',
      nombreActuacion: 'Demanda de Relación Directa y Regular (Régimen de Visitas)', rolProcesal: 'Padre / Madre Demandante',
      tipoInstitucion: 'Procedimiento Ordinario Familia', articuloYNorma: 'Art. 229 Código Civil y Ley N° 19.968',
      diasBase: 5, tipoComputo: TipoComputoDias.habilesCivil, admiteEmplazamiento: false,
      elementosAConsiderar: ['Contestación escrita hasta 5 días antes de la audiencia preparatoria con propuesta de régimen']
    ),
    ActuacionProcesal(
      id: 'fam_divorcio_compensacion', materiaId: 'mix_fam_cuidado_divorcio',
      nombreActuacion: 'Demanda de Divorcio (Unilateral / Mutuo Acuerdo / Culposo) y Compensación', rolProcesal: 'Cónyuge Demandante',
      tipoInstitucion: 'Juicio de Divorcio', articuloYNorma: 'Ley N° 19.947 (Matrimonio Civil)',
      diasBase: 5, tipoComputo: TipoComputoDias.habilesCivil, admiteEmplazamiento: false,
      elementosAConsiderar: ['Acreditar cese de convivencia (1 año mutuo acuerdo / 3 años unilateral) o causal de culpa']
    ),
    ActuacionProcesal(
      id: 'fam_vif_medidas', materiaId: 'mix_fam_vif_proteccion',
      nombreActuacion: 'Procedimiento por Violencia Intrafamiliar en Familia (VIF)', rolProcesal: 'Víctima / Denunciante',
      tipoInstitucion: 'Procedimiento Especial VIF', articuloYNorma: 'Ley N° 20.066 y Ley N° 19.968',
      diasBase: 1, tipoComputo: TipoComputoDias.corridos, admiteEmplazamiento: false,
      elementosAConsiderar: ['Medidas cautelares inmediatas (salida del hogar, prohibición de acercamiento, suspensión de visitas)']
    ),
    ActuacionProcesal(
      id: 'fam_medida_proteccion', materiaId: 'mix_fam_vif_proteccion',
      nombreActuacion: 'Medidas de Protección de Niños, Niñas y Adolescentes (NNA)', rolProcesal: 'Oficio / Solicitante',
      tipoInstitucion: 'Protección de NNA', articuloYNorma: 'Art. 71 Ley N° 19.968',
      diasBase: 5, tipoComputo: TipoComputoDias.corridos, admiteEmplazamiento: false,
      elementosAConsiderar: ['Audiencia preparatoria urgente dentro de 5 días desde la medida cautelar']
    ),
    ActuacionProcesal(
      id: 'fam_filiacion', materiaId: 'mix_fam_vif_proteccion',
      nombreActuacion: 'Juicio de Filiación / Impugnación o Reconocimiento de Paternidad', rolProcesal: 'Demandante',
      tipoInstitucion: 'Procedimiento de Filiación', articuloYNorma: 'Arts. 179 y ss. Código Civil',
      diasBase: 5, tipoComputo: TipoComputoDias.habilesCivil, admiteEmplazamiento: false,
      elementosAConsiderar: ['Prueba biológica de ADN obligatoria decretada por el juez de familia']
    ),
    ActuacionProcesal(
      id: 'fam_apelacion', materiaId: 'mix_fam_alimentos',
      nombreActuacion: 'Recurso de Apelación en Juicios de Familia', rolProcesal: 'Agraviado',
      tipoInstitucion: 'Recurso de Alzada de Familia', articuloYNorma: 'Art. 67 Ley N° 19.968',
      diasBase: 5, tipoComputo: TipoComputoDias.habilesCivil, admiteEmplazamiento: false,
      elementosAConsiderar: ['5 días hábiles desde la notificación del fallo definitivo de primera instancia']
    ),

    // ==========================================
    // 4. DERECHO PROCESAL PENAL (CPP)
    // ==========================================
    ActuacionProcesal(
      id: 'penal_amparo_juez', materiaId: 'pub_penal',
      nombreActuacion: 'Amparo ante el Juez de Garantía', rolProcesal: 'Imputado',
      tipoInstitucion: 'Acción Cautelar Urgente', articuloYNorma: 'Art. 95 CPP',
      diasBase: 1, tipoComputo: TipoComputoDias.corridos, admiteEmplazamiento: false,
      elementosAConsiderar: ['Privación o perturbación ilegal de libertad personal', 'Cita a audiencia inmediata']
    ),
    ActuacionProcesal(
      id: 'penal_repo_audiencia', materiaId: 'pub_penal',
      nombreActuacion: 'Reposición Oral en Audiencia Penal', rolProcesal: 'Interviniente',
      tipoInstitucion: 'Recurso Inmediato', articuloYNorma: 'Art. 362 CPP',
      diasBase: 0, tipoComputo: TipoComputoDias.corridos, admiteEmplazamiento: false,
      elementosAConsiderar: ['Se interpone y resuelve de forma verbal e inmediata en la misma audiencia']
    ),
    ActuacionProcesal(
      id: 'penal_apelacion', materiaId: 'pub_penal',
      nombreActuacion: 'Recurso de Apelación Penal', rolProcesal: 'Interviniente',
      tipoInstitucion: 'Recurso de Alzada Penal', articuloYNorma: 'Art. 366 CPP',
      diasBase: 5, tipoComputo: TipoComputoDias.corridos, admiteEmplazamiento: false,
      elementosAConsiderar: ['Procede contra prisión preventiva, sobreseimiento temporal o definitivo, y taxativas legales']
    ),
    ActuacionProcesal(
      id: 'penal_nulidad', materiaId: 'pub_penal',
      nombreActuacion: 'Recurso de Nulidad Penal', rolProcesal: 'Interviniente',
      tipoInstitucion: 'Recurso Extraordinario Penal', articuloYNorma: 'Art. 372 y 374 CPP',
      diasBase: 10, tipoComputo: TipoComputoDias.corridos, admiteEmplazamiento: false,
      elementosAConsiderar: ['Infracción sustancial de derechos y garantías constitucionales durante el juicio oral']
    ),

    // ==========================================
    // 5. DERECHO TRIBUTARIO Y ADUANERO (TTA / SII)
    // ==========================================
    ActuacionProcesal(
      id: 'trib_reclamo_sii', materiaId: 'pub_trib',
      nombreActuacion: 'Reclamación Tributaria contra Liquidaciones o Giros', rolProcesal: 'Contribuyente',
      tipoInstitucion: 'Reclamación Jurisdiccional TTA', articuloYNorma: 'Art. 124 Código Tributario (DL 830)',
      diasBase: 90, tipoComputo: TipoComputoDias.habilesCivil, admiteEmplazamiento: false,
      elementosAConsiderar: ['Plazo general de 90 días hábiles desde la notificación de la liquidación, giro o resolución', 'Opción previa de RAF (Art. 123 bis)']
    ),
    ActuacionProcesal(
      id: 'trib_reposicion_admin', materiaId: 'pub_trib',
      nombreActuacion: 'Reposición Administrativa Voluntaria (RAV / RAF)', rolProcesal: 'Contribuyente',
      tipoInstitucion: 'Gestión Administrativa Previa', articuloYNorma: 'Art. 123 bis Código Tributario',
      diasBase: 15, tipoComputo: TipoComputoDias.habilesCivil, admiteEmplazamiento: false,
      elementosAConsiderar: ['Interposición ante el Director Regional del SII dentro de plazo legal']
    ),

    // ==========================================
    // 6. JUZGADOS DE POLICÍA LOCAL
    // ==========================================
    ActuacionProcesal(
      id: 'jpl_transito_querella', materiaId: 'mix_pol_loc',
      nombreActuacion: 'Querella e Infracción por Accidentes de Tránsito (JPL)', rolProcesal: 'Denunciante / Afectado',
      tipoInstitucion: 'Procedimiento de Policía Local', articuloYNorma: 'Ley N° 18.287 y Ley N° 18.290',
      diasBase: 180, tipoComputo: TipoComputoDias.corridos, admiteEmplazamiento: false,
      elementosAConsiderar: ['Prescripción de 6 meses desde la ocurrencia del accidente de tránsito']
    ),
    ActuacionProcesal(
      id: 'jpl_consumidor_demanda', materiaId: 'mix_pol_loc',
      nombreActuacion: 'Demanda por Ley de Protección de los Derechos de los Consumidores (LPDC)', rolProcesal: 'Consumidor Demandante',
      tipoInstitucion: 'Procedimiento del Consumidor', articuloYNorma: 'Ley N° 19.496 y Ley N° 18.287',
      diasBase: 730, tipoComputo: TipoComputoDias.corridos, admiteEmplazamiento: false,
      elementosAConsiderar: ['Prescripción de 2 años desde que cesó la infracción o compra del producto/servicio']
    ),
    ActuacionProcesal(
      id: 'jpl_apelacion', materiaId: 'mix_pol_loc',
      nombreActuacion: 'Recurso de Apelación contra Sentencia de Policía Local', rolProcesal: 'Parte Agraviada',
      tipoInstitucion: 'Recurso de Alzada de Policía Local', articuloYNorma: 'Art. 32 Ley N° 18.287',
      diasBase: 5, tipoComputo: TipoComputoDias.habilesCivil, admiteEmplazamiento: false,
      elementosAConsiderar: ['5 días hábiles desde la notificación para apelar ante la Corte de Apelaciones respectiva']
    ),

    // ==========================================
    // 7. DERECHO CONSTITUCIONAL Y ADMINISTRATIVO
    // ==========================================
    ActuacionProcesal(
      id: 'const_proteccion', materiaId: 'pub_const',
      nombreActuacion: 'Recurso de Protección Constitucional (Primera Instancia)', rolProcesal: 'Recurrente / Afectado',
      tipoInstitucion: 'Acción Constitucional de Urgencia', articuloYNorma: 'Art. 20 CPR y AA CS',
      diasBase: 30, tipoComputo: TipoComputoDias.corridos, admiteEmplazamiento: false,
      elementosAConsiderar: ['30 días corridos fatales desde la ejecución del acto u omisión arbitraria/ilegal o conocimiento cierto', 'Solicitar Orden de No Innovar (ONI)']
    ),
    ActuacionProcesal(
      id: 'const_amparo', materiaId: 'pub_const',
      nombreActuacion: 'Recurso de Amparo / Habeas Corpus (Primera Instancia)', rolProcesal: 'Amparado / Recurrente',
      tipoInstitucion: 'Acción Constitucional de Libertad', articuloYNorma: 'Art. 21 CPR',
      diasBase: 0, tipoComputo: TipoComputoDias.corridos, admiteEmplazamiento: false,
      elementosAConsiderar: ['Sin plazo fijo de caducidad (interponible mientras subsista la privación o amenaza ilegal)']
    ),
    ActuacionProcesal(
      id: 'tc_ina', materiaId: 'pub_tc',
      nombreActuacion: 'Requerimiento de Inaplicabilidad por Inconstitucionalidad (INA)', rolProcesal: 'Requeriente (Parte / Juez)',
      tipoInstitucion: 'Control Concreto de Constitucionalidad', articuloYNorma: 'Art. 93 N° 6 CPR y Art. 79 Ley N° 17.997',
      diasBase: 0, tipoComputo: TipoComputoDias.corridos, admiteEmplazamiento: false,
      elementosAConsiderar: ['En cualquier estado de la gestión judicial pendiente', 'Permite solicitar suspensión del procedimiento de origen']
    ),
    ActuacionProcesal(
      id: 'admin_reposicion', materiaId: 'pub_const',
      nombreActuacion: 'Recurso de Reposición Administrativa (Ley 19.880)', rolProcesal: 'Interesado',
      tipoInstitucion: 'Impugnación Administrativa', articuloYNorma: 'Art. 59 Ley N° 19.880',
      diasBase: 5, tipoComputo: TipoComputoDias.habilesAdmin, admiteEmplazamiento: false,
      elementosAConsiderar: ['Cómputo en días hábiles administrativos (Lunes a Viernes, excluyendo festivos)', 'Apelación jerárquica en subsidio']
    ),
  ];

  static final List<TribunalItem> tribunales = [
    // -------------------------------------------------------------------------
    // I. TRIBUNALES ORDINARIOS Y CORTE SUPREMA (Poder Judicial - PJUD)
    // -------------------------------------------------------------------------
    // 1. CORTE SUPREMA
    TribunalItem(nombre: 'Corte Suprema - Sala Primera (Civil)', comuna: 'Santiago', region: 'RM'),
    TribunalItem(nombre: 'Corte Suprema - Sala Segunda (Penal)', comuna: 'Santiago', region: 'RM'),
    TribunalItem(nombre: 'Corte Suprema - Sala Tercera (Constitucional / Contencioso)', comuna: 'Santiago', region: 'RM'),
    TribunalItem(nombre: 'Corte Suprema - Sala Cuarta (Laboral / Familia)', comuna: 'Santiago', region: 'RM'),

    // 2. CORTES DE APELACIONES (17 Jurisdicciones)
    TribunalItem(nombre: 'Corte de Apelaciones de Arica', comuna: 'Arica', region: 'Arica y Parinacota'),
    TribunalItem(nombre: 'Corte de Apelaciones de Iquique', comuna: 'Iquique', region: 'Tarapacá'),
    TribunalItem(nombre: 'Corte de Apelaciones de Antofagasta', comuna: 'Antofagasta', region: 'Antofagasta'),
    TribunalItem(nombre: 'Corte de Apelaciones de Copiapó', comuna: 'Copiapó', region: 'Atacama'),
    TribunalItem(nombre: 'Corte de Apelaciones de La Serena', comuna: 'La Serena', region: 'Coquimbo'),
    TribunalItem(nombre: 'Corte de Apelaciones de Valparaíso', comuna: 'Valparaíso', region: 'Valparaíso'),
    TribunalItem(nombre: 'Corte de Apelaciones de Santiago', comuna: 'Santiago', region: 'RM'),
    TribunalItem(nombre: 'Corte de Apelaciones de San Miguel', comuna: 'San Miguel', region: 'RM'),
    TribunalItem(nombre: 'Corte de Apelaciones de Rancagua', comuna: 'Rancagua', region: 'O\'Higgins'),
    TribunalItem(nombre: 'Corte de Apelaciones de Talca', comuna: 'Talca', region: 'Maule'),
    TribunalItem(nombre: 'Corte de Apelaciones de Chillán', comuna: 'Chillán', region: 'Ñuble'),
    TribunalItem(nombre: 'Corte de Apelaciones de Concepción', comuna: 'Concepción', region: 'Biobío'),
    TribunalItem(nombre: 'Corte de Apelaciones de Temuco', comuna: 'Temuco', region: 'Araucanía'),
    TribunalItem(nombre: 'Corte de Apelaciones de Valdivia', comuna: 'Valdivia', region: 'Los Ríos'),
    TribunalItem(nombre: 'Corte de Apelaciones de Puerto Montt', comuna: 'Puerto Montt', region: 'Los Lagos'),
    TribunalItem(nombre: 'Corte de Apelaciones de Coyhaique', comuna: 'Coyhaique', region: 'Aysén'),
    TribunalItem(nombre: 'Corte de Apelaciones de Punta Arenas', comuna: 'Punta Arenas', region: 'Magallanes'),

    // 3. JUZGADOS CIVILES Y DE LETRAS (Competencia Común)
    TribunalItem(nombre: '1º al 30º Juzgado Civil de Santiago', comuna: 'Santiago', region: 'RM', diasAumentoEmplazamiento: 0),
    TribunalItem(nombre: '1º al 4º Juzgado Civil de San Miguel', comuna: 'San Miguel', region: 'RM', diasAumentoEmplazamiento: 0),
    TribunalItem(nombre: '1º al 5º Juzgado Civil de Valparaíso', comuna: 'Valparaíso', region: 'Valparaíso', diasAumentoEmplazamiento: 0),
    TribunalItem(nombre: '1º al 3º Juzgado Civil de Viña del Mar', comuna: 'Viña del Mar', region: 'Valparaíso', diasAumentoEmplazamiento: 0),
    TribunalItem(nombre: '1º Juzgado Civil de Concepción', comuna: 'Concepción', region: 'Biobío', diasAumentoEmplazamiento: 0),
    TribunalItem(nombre: '2º Juzgado Civil de Concepción', comuna: 'Concepción', region: 'Biobío', diasAumentoEmplazamiento: 0),
    TribunalItem(nombre: '3º Juzgado Civil de Concepción', comuna: 'Concepción', region: 'Biobío', diasAumentoEmplazamiento: 0),
    TribunalItem(nombre: '1º Juzgado Civil de Talcahuano', comuna: 'Talcahuano', region: 'Biobío', diasAumentoEmplazamiento: 3),
    TribunalItem(nombre: '2º Juzgado Civil de Talcahuano', comuna: 'Talcahuano', region: 'Biobío', diasAumentoEmplazamiento: 3),
    TribunalItem(nombre: '1º y 2º Juzgado Civil de Los Ángeles', comuna: 'Los Ángeles', region: 'Biobío', diasAumentoEmplazamiento: 3),
    TribunalItem(nombre: '1º al 3º Juzgado Civil de Antofagasta', comuna: 'Antofagasta', region: 'Antofagasta', diasAumentoEmplazamiento: 0),
    TribunalItem(nombre: '1º al 3º Juzgado Civil de Temuco', comuna: 'Temuco', region: 'Araucanía', diasAumentoEmplazamiento: 0),
    TribunalItem(nombre: '1º y 2º Juzgado Civil de Rancagua', comuna: 'Rancagua', region: 'O\'Higgins', diasAumentoEmplazamiento: 0),
    TribunalItem(nombre: '1º y 2º Juzgado Civil de Talca', comuna: 'Talca', region: 'Maule', diasAumentoEmplazamiento: 0),
    TribunalItem(nombre: '1º y 2º Juzgado Civil de Valdivia', comuna: 'Valdivia', region: 'Los Ríos', diasAumentoEmplazamiento: 0),
    TribunalItem(nombre: '1º y 2º Juzgado Civil de Puerto Montt', comuna: 'Puerto Montt', region: 'Los Lagos', diasAumentoEmplazamiento: 0),
    TribunalItem(nombre: '1º al 3º Juzgado de Letras de Arica', comuna: 'Arica', region: 'Arica y Parinacota', diasAumentoEmplazamiento: 0),
    TribunalItem(nombre: '1º al 3º Juzgado de Letras de Iquique', comuna: 'Iquique', region: 'Tarapacá', diasAumentoEmplazamiento: 0),
    TribunalItem(nombre: '1º y 2º Juzgado de Letras de Calama', comuna: 'Calama', region: 'Antofagasta', diasAumentoEmplazamiento: 3),
    TribunalItem(nombre: '1º al 3º Juzgado de Letras de Copiapó', comuna: 'Copiapó', region: 'Atacama', diasAumentoEmplazamiento: 0),
    TribunalItem(nombre: '1º al 3º Juzgado de Letras de La Serena', comuna: 'La Serena', region: 'Coquimbo', diasAumentoEmplazamiento: 0),
    TribunalItem(nombre: '1º al 3º Juzgado de Letras de Coquimbo', comuna: 'Coquimbo', region: 'Coquimbo', diasAumentoEmplazamiento: 0),
    TribunalItem(nombre: 'Juzgado de Letras de Quillota', comuna: 'Quillota', region: 'Valparaíso', diasAumentoEmplazamiento: 3),
    TribunalItem(nombre: 'Juzgado de Letras de San Antonio', comuna: 'San Antonio', region: 'Valparaíso', diasAumentoEmplazamiento: 3),
    TribunalItem(nombre: 'Juzgado de Letras de San Felipe', comuna: 'San Felipe', region: 'Valparaíso', diasAumentoEmplazamiento: 3),
    TribunalItem(nombre: 'Juzgado de Letras de Los Andes', comuna: 'Los Andes', region: 'Valparaíso', diasAumentoEmplazamiento: 3),
    TribunalItem(nombre: 'Juzgado de Letras de Quilpué', comuna: 'Quilpué', region: 'Valparaíso', diasAumentoEmplazamiento: 3),
    TribunalItem(nombre: 'Juzgado de Letras de Villa Alemana', comuna: 'Villa Alemana', region: 'Valparaíso', diasAumentoEmplazamiento: 3),
    TribunalItem(nombre: 'Juzgado de Letras de San Bernardo', comuna: 'San Bernardo', region: 'RM', diasAumentoEmplazamiento: 3),
    TribunalItem(nombre: 'Juzgado de Letras de Puente Alto', comuna: 'Puente Alto', region: 'RM', diasAumentoEmplazamiento: 3),
    TribunalItem(nombre: 'Juzgado de Letras de Melipilla', comuna: 'Melipilla', region: 'RM', diasAumentoEmplazamiento: 3),
    TribunalItem(nombre: 'Juzgado de Letras de Talagante', comuna: 'Talagante', region: 'RM', diasAumentoEmplazamiento: 3),
    TribunalItem(nombre: 'Juzgado de Letras de Colina', comuna: 'Colina', region: 'RM', diasAumentoEmplazamiento: 3),
    TribunalItem(nombre: 'Juzgado de Letras de Buin', comuna: 'Buin', region: 'RM', diasAumentoEmplazamiento: 3),
    TribunalItem(nombre: 'Juzgado de Letras de Peñaflor', comuna: 'Peñaflor', region: 'RM', diasAumentoEmplazamiento: 3),
    TribunalItem(nombre: 'Juzgado de Letras de Rengo', comuna: 'Rengo', region: 'O\'Higgins', diasAumentoEmplazamiento: 3),
    TribunalItem(nombre: 'Juzgado de Letras de San Fernando', comuna: 'San Fernando', region: 'O\'Higgins', diasAumentoEmplazamiento: 3),
    TribunalItem(nombre: 'Juzgado de Letras de Curicó', comuna: 'Curicó', region: 'Maule', diasAumentoEmplazamiento: 3),
    TribunalItem(nombre: 'Juzgado de Letras de Linares', comuna: 'Linares', region: 'Maule', diasAumentoEmplazamiento: 3),
    TribunalItem(nombre: 'Juzgado de Letras de Cauquenes', comuna: 'Cauquenes', region: 'Maule', diasAumentoEmplazamiento: 3),
    TribunalItem(nombre: 'Juzgado de Letras de Constitución', comuna: 'Constitución', region: 'Maule', diasAumentoEmplazamiento: 3),
    TribunalItem(nombre: 'Juzgado de Letras de Chillán', comuna: 'Chillán', region: 'Ñuble', diasAumentoEmplazamiento: 0),
    TribunalItem(nombre: 'Juzgado de Letras de San Carlos', comuna: 'San Carlos', region: 'Ñuble', diasAumentoEmplazamiento: 3),
    TribunalItem(nombre: 'Juzgado de Letras de Coronel', comuna: 'Coronel', region: 'Biobío', diasAumentoEmplazamiento: 3),
    TribunalItem(nombre: 'Juzgado de Letras de Lota', comuna: 'Lota', region: 'Biobío', diasAumentoEmplazamiento: 3),
    TribunalItem(nombre: 'Juzgado de Letras de Arauco', comuna: 'Arauco', region: 'Biobío', diasAumentoEmplazamiento: 3),
    TribunalItem(nombre: 'Juzgado de Letras de Cañete', comuna: 'Cañete', region: 'Biobío', diasAumentoEmplazamiento: 3),
    TribunalItem(nombre: 'Juzgado de Letras de Angol', comuna: 'Angol', region: 'Araucanía', diasAumentoEmplazamiento: 3),
    TribunalItem(nombre: 'Juzgado de Letras de Victoria', comuna: 'Victoria', region: 'Araucanía', diasAumentoEmplazamiento: 3),
    TribunalItem(nombre: 'Juzgado de Letras de Villarrica', comuna: 'Villarrica', region: 'Araucanía', diasAumentoEmplazamiento: 3),
    TribunalItem(nombre: 'Juzgado de Letras de Pucón', comuna: 'Pucón', region: 'Araucanía', diasAumentoEmplazamiento: 3),
    TribunalItem(nombre: '1º y 2º Juzgado de Letras de Osorno', comuna: 'Osorno', region: 'Los Lagos', diasAumentoEmplazamiento: 3),
    TribunalItem(nombre: 'Juzgado de Letras de Castro', comuna: 'Castro', region: 'Los Lagos', diasAumentoEmplazamiento: 3),
    TribunalItem(nombre: 'Juzgado de Letras de Ancud', comuna: 'Ancud', region: 'Los Lagos', diasAumentoEmplazamiento: 3),
    TribunalItem(nombre: 'Juzgado de Letras de Coyhaique', comuna: 'Coyhaique', region: 'Aysén', diasAumentoEmplazamiento: 0),
    TribunalItem(nombre: 'Juzgado de Letras de Puerto Aysén', comuna: 'Puerto Aysén', region: 'Aysén', diasAumentoEmplazamiento: 3),
    TribunalItem(nombre: '1º al 3º Juzgado de Letras de Punta Arenas', comuna: 'Punta Arenas', region: 'Magallanes', diasAumentoEmplazamiento: 0),
    TribunalItem(nombre: 'Juzgado de Letras de Puerto Natales', comuna: 'Puerto Natales', region: 'Magallanes', diasAumentoEmplazamiento: 3),

    // 4. JUZGADOS DE GARANTÍA (JG) Y TRIBUNALES DE JUICIO ORAL EN LO PENAL (TOP)
    TribunalItem(nombre: '1º al 14º Juzgados de Garantía de Santiago (Centro de Justicia)', comuna: 'Santiago', region: 'RM', diasAumentoEmplazamiento: 0),
    TribunalItem(nombre: '1º al 7º Tribunales de Juicio Oral en lo Penal (TOP) de Santiago', comuna: 'Santiago', region: 'RM', diasAumentoEmplazamiento: 0),
    TribunalItem(nombre: 'Juzgado de Garantía y TOP de San Bernardo', comuna: 'San Bernardo', region: 'RM', diasAumentoEmplazamiento: 0),
    TribunalItem(nombre: 'Juzgado de Garantía y TOP de Puente Alto', comuna: 'Puente Alto', region: 'RM', diasAumentoEmplazamiento: 0),
    TribunalItem(nombre: 'Juzgado de Garantía y TOP de Melipilla', comuna: 'Melipilla', region: 'RM', diasAumentoEmplazamiento: 0),
    TribunalItem(nombre: 'Juzgado de Garantía y TOP de Talagante', comuna: 'Talagante', region: 'RM', diasAumentoEmplazamiento: 0),
    TribunalItem(nombre: 'Juzgado de Garantía y TOP de Colina', comuna: 'Colina', region: 'RM', diasAumentoEmplazamiento: 0),
    TribunalItem(nombre: 'Juzgado de Garantía de Curacaví', comuna: 'Curacaví', region: 'RM', diasAumentoEmplazamiento: 0),
    TribunalItem(nombre: 'Juzgado de Garantía y TOP de Arica', comuna: 'Arica', region: 'Arica y Parinacota', diasAumentoEmplazamiento: 0),
    TribunalItem(nombre: 'Juzgado de Garantía y TOP de Iquique', comuna: 'Iquique', region: 'Tarapacá', diasAumentoEmplazamiento: 0),
    TribunalItem(nombre: 'Juzgado de Garantía y TOP de Antofagasta', comuna: 'Antofagasta', region: 'Antofagasta', diasAumentoEmplazamiento: 0),
    TribunalItem(nombre: 'Juzgado de Garantía y TOP de Calama', comuna: 'Calama', region: 'Antofagasta', diasAumentoEmplazamiento: 0),
    TribunalItem(nombre: 'Juzgado de Garantía y TOP de Copiapó', comuna: 'Copiapó', region: 'Atacama', diasAumentoEmplazamiento: 0),
    TribunalItem(nombre: 'Juzgado de Garantía y TOP de La Serena', comuna: 'La Serena', region: 'Coquimbo', diasAumentoEmplazamiento: 0),
    TribunalItem(nombre: 'Juzgado de Garantía y TOP de Coquimbo', comuna: 'Coquimbo', region: 'Coquimbo', diasAumentoEmplazamiento: 0),
    TribunalItem(nombre: 'Juzgado de Garantía y TOP de Valparaíso', comuna: 'Valparaíso', region: 'Valparaíso', diasAumentoEmplazamiento: 0),
    TribunalItem(nombre: 'Juzgado de Garantía y TOP de Viña del Mar', comuna: 'Viña del Mar', region: 'Valparaíso', diasAumentoEmplazamiento: 0),
    TribunalItem(nombre: 'Juzgado de Garantía y TOP de San Antonio', comuna: 'San Antonio', region: 'Valparaíso', diasAumentoEmplazamiento: 0),
    TribunalItem(nombre: 'Juzgado de Garantía y TOP de Rancagua', comuna: 'Rancagua', region: 'O\'Higgins', diasAumentoEmplazamiento: 0),
    TribunalItem(nombre: 'Juzgado de Garantía y TOP de Talca', comuna: 'Talca', region: 'Maule', diasAumentoEmplazamiento: 0),
    TribunalItem(nombre: 'Juzgado de Garantía y TOP de Curicó', comuna: 'Curicó', region: 'Maule', diasAumentoEmplazamiento: 0),
    TribunalItem(nombre: 'Juzgado de Garantía y TOP de Chillán', comuna: 'Chillán', region: 'Ñuble', diasAumentoEmplazamiento: 0),
    TribunalItem(nombre: 'Juzgado de Garantía de Concepción', comuna: 'Concepción', region: 'Biobío', diasAumentoEmplazamiento: 0),
    TribunalItem(nombre: 'Tribunal de Juicio Oral en lo Penal (TOP) Concepción', comuna: 'Concepción', region: 'Biobío', diasAumentoEmplazamiento: 0),
    TribunalItem(nombre: 'Juzgado de Garantía y TOP de Talcahuano', comuna: 'Talcahuano', region: 'Biobío', diasAumentoEmplazamiento: 0),
    TribunalItem(nombre: 'Juzgado de Garantía y TOP de Los Ángeles', comuna: 'Los Ángeles', region: 'Biobío', diasAumentoEmplazamiento: 0),
    TribunalItem(nombre: 'Juzgado de Garantía y TOP de Temuco', comuna: 'Temuco', region: 'Araucanía', diasAumentoEmplazamiento: 0),
    TribunalItem(nombre: 'Juzgado de Garantía y TOP de Angol', comuna: 'Angol', region: 'Araucanía', diasAumentoEmplazamiento: 0),
    TribunalItem(nombre: 'Juzgado de Garantía y TOP de Valdivia', comuna: 'Valdivia', region: 'Los Ríos', diasAumentoEmplazamiento: 0),
    TribunalItem(nombre: 'Juzgado de Garantía y TOP de Osorno', comuna: 'Osorno', region: 'Los Lagos', diasAumentoEmplazamiento: 0),
    TribunalItem(nombre: 'Juzgado de Garantía y TOP de Puerto Montt', comuna: 'Puerto Montt', region: 'Los Lagos', diasAumentoEmplazamiento: 0),
    TribunalItem(nombre: 'Juzgado de Garantía y TOP de Castro', comuna: 'Castro', region: 'Los Lagos', diasAumentoEmplazamiento: 0),
    TribunalItem(nombre: 'Juzgado de Garantía y TOP de Coyhaique', comuna: 'Coyhaique', region: 'Aysén', diasAumentoEmplazamiento: 0),
    TribunalItem(nombre: 'Juzgado de Garantía y TOP de Punta Arenas', comuna: 'Punta Arenas', region: 'Magallanes', diasAumentoEmplazamiento: 0),

    // 5. JUZGADOS DE FAMILIA
    TribunalItem(nombre: '1º al 4º Juzgado de Familia de Santiago', comuna: 'Santiago', region: 'RM', diasAumentoEmplazamiento: 0),
    TribunalItem(nombre: 'Juzgado de Familia de Pudahuel', comuna: 'Pudahuel', region: 'RM', diasAumentoEmplazamiento: 0),
    TribunalItem(nombre: 'Juzgado de Familia de San Bernardo', comuna: 'San Bernardo', region: 'RM', diasAumentoEmplazamiento: 0),
    TribunalItem(nombre: 'Juzgado de Familia de Puente Alto', comuna: 'Puente Alto', region: 'RM', diasAumentoEmplazamiento: 0),
    TribunalItem(nombre: 'Juzgado de Familia de Colina', comuna: 'Colina', region: 'RM', diasAumentoEmplazamiento: 0),
    TribunalItem(nombre: 'Juzgado de Familia de Melipilla', comuna: 'Melipilla', region: 'RM', diasAumentoEmplazamiento: 0),
    TribunalItem(nombre: 'Juzgado de Familia de Talagante', comuna: 'Talagante', region: 'RM', diasAumentoEmplazamiento: 0),
    TribunalItem(nombre: 'Juzgado de Familia de Arica', comuna: 'Arica', region: 'Arica y Parinacota', diasAumentoEmplazamiento: 0),
    TribunalItem(nombre: 'Juzgado de Familia de Iquique', comuna: 'Iquique', region: 'Tarapacá', diasAumentoEmplazamiento: 0),
    TribunalItem(nombre: 'Juzgado de Familia de Antofagasta', comuna: 'Antofagasta', region: 'Antofagasta', diasAumentoEmplazamiento: 0),
    TribunalItem(nombre: 'Juzgado de Familia de Calama', comuna: 'Calama', region: 'Antofagasta', diasAumentoEmplazamiento: 0),
    TribunalItem(nombre: 'Juzgado de Familia de Copiapó', comuna: 'Copiapó', region: 'Atacama', diasAumentoEmplazamiento: 0),
    TribunalItem(nombre: 'Juzgado de Familia de La Serena', comuna: 'La Serena', region: 'Coquimbo', diasAumentoEmplazamiento: 0),
    TribunalItem(nombre: 'Juzgado de Familia de Coquimbo', comuna: 'Coquimbo', region: 'Coquimbo', diasAumentoEmplazamiento: 0),
    TribunalItem(nombre: 'Juzgado de Familia de Valparaíso', comuna: 'Valparaíso', region: 'Valparaíso', diasAumentoEmplazamiento: 0),
    TribunalItem(nombre: 'Juzgado de Familia de Viña del Mar', comuna: 'Viña del Mar', region: 'Valparaíso', diasAumentoEmplazamiento: 0),
    TribunalItem(nombre: 'Juzgado de Familia de Quilpué', comuna: 'Quilpué', region: 'Valparaíso', diasAumentoEmplazamiento: 0),
    TribunalItem(nombre: 'Juzgado de Familia de San Antonio', comuna: 'San Antonio', region: 'Valparaíso', diasAumentoEmplazamiento: 0),
    TribunalItem(nombre: 'Juzgado de Familia de Rancagua', comuna: 'Rancagua', region: 'O\'Higgins', diasAumentoEmplazamiento: 0),
    TribunalItem(nombre: 'Juzgado de Familia de Talca', comuna: 'Talca', region: 'Maule', diasAumentoEmplazamiento: 0),
    TribunalItem(nombre: 'Juzgado de Familia de Curicó', comuna: 'Curicó', region: 'Maule', diasAumentoEmplazamiento: 0),
    TribunalItem(nombre: 'Juzgado de Familia de Linares', comuna: 'Linares', region: 'Maule', diasAumentoEmplazamiento: 0),
    TribunalItem(nombre: 'Juzgado de Familia de Chillán', comuna: 'Chillán', region: 'Ñuble', diasAumentoEmplazamiento: 0),
    TribunalItem(nombre: 'Juzgado de Familia de Concepción', comuna: 'Concepción', region: 'Biobío', diasAumentoEmplazamiento: 0),
    TribunalItem(nombre: 'Juzgado de Familia de Talcahuano', comuna: 'Talcahuano', region: 'Biobío', diasAumentoEmplazamiento: 0),
    TribunalItem(nombre: 'Juzgado de Familia de Los Ángeles', comuna: 'Los Ángeles', region: 'Biobío', diasAumentoEmplazamiento: 0),
    TribunalItem(nombre: 'Juzgado de Familia de Temuco', comuna: 'Temuco', region: 'Araucanía', diasAumentoEmplazamiento: 0),
    TribunalItem(nombre: 'Juzgado de Familia de Valdivia', comuna: 'Valdivia', region: 'Los Ríos', diasAumentoEmplazamiento: 0),
    TribunalItem(nombre: 'Juzgado de Familia de Osorno', comuna: 'Osorno', region: 'Los Lagos', diasAumentoEmplazamiento: 0),
    TribunalItem(nombre: 'Juzgado de Familia de Puerto Montt', comuna: 'Puerto Montt', region: 'Los Lagos', diasAumentoEmplazamiento: 0),
    TribunalItem(nombre: 'Juzgado de Familia de Castro', comuna: 'Castro', region: 'Los Lagos', diasAumentoEmplazamiento: 0),
    TribunalItem(nombre: 'Juzgado de Familia de Coyhaique', comuna: 'Coyhaique', region: 'Aysén', diasAumentoEmplazamiento: 0),
    TribunalItem(nombre: 'Juzgado de Familia de Punta Arenas', comuna: 'Punta Arenas', region: 'Magallanes', diasAumentoEmplazamiento: 0),

    // 6. JUZGADOS DE LETRAS DEL TRABAJO Y COBRANZA LABORAL/PREVISIONAL
    TribunalItem(nombre: '1º y 2º Juzgado de Letras del Trabajo de Santiago', comuna: 'Santiago', region: 'RM', diasAumentoEmplazamiento: 0),
    TribunalItem(nombre: 'Juzgado de Cobranza Laboral y Previsional de Santiago', comuna: 'Santiago', region: 'RM', diasAumentoEmplazamiento: 0),
    TribunalItem(nombre: 'Juzgado de Letras del Trabajo de San Miguel', comuna: 'San Miguel', region: 'RM', diasAumentoEmplazamiento: 0),
    TribunalItem(nombre: 'Juzgado de Letras del Trabajo de San Bernardo', comuna: 'San Bernardo', region: 'RM', diasAumentoEmplazamiento: 0),
    TribunalItem(nombre: 'Juzgado de Letras del Trabajo de Puente Alto', comuna: 'Puente Alto', region: 'RM', diasAumentoEmplazamiento: 0),
    TribunalItem(nombre: 'Juzgado de Letras del Trabajo de Valparaíso', comuna: 'Valparaíso', region: 'Valparaíso', diasAumentoEmplazamiento: 0),
    TribunalItem(nombre: 'Juzgado de Letras del Trabajo de Viña del Mar', comuna: 'Viña del Mar', region: 'Valparaíso', diasAumentoEmplazamiento: 0),
    TribunalItem(nombre: 'Juzgado de Letras del Trabajo de Antofagasta', comuna: 'Antofagasta', region: 'Antofagasta', diasAumentoEmplazamiento: 0),
    TribunalItem(nombre: 'Juzgado de Letras del Trabajo de Calama', comuna: 'Calama', region: 'Antofagasta', diasAumentoEmplazamiento: 0),
    TribunalItem(nombre: 'Juzgado de Letras del Trabajo de La Serena', comuna: 'La Serena', region: 'Coquimbo', diasAumentoEmplazamiento: 0),
    TribunalItem(nombre: 'Juzgado de Letras del Trabajo de Rancagua', comuna: 'Rancagua', region: 'O\'Higgins', diasAumentoEmplazamiento: 0),
    TribunalItem(nombre: 'Juzgado de Letras del Trabajo de Talca', comuna: 'Talca', region: 'Maule', diasAumentoEmplazamiento: 0),
    TribunalItem(nombre: 'Juzgado de Letras del Trabajo de Chillán', comuna: 'Chillán', region: 'Ñuble', diasAumentoEmplazamiento: 0),
    TribunalItem(nombre: 'Juzgado de Letras del Trabajo de Concepción', comuna: 'Concepción', region: 'Biobío', diasAumentoEmplazamiento: 0),
    TribunalItem(nombre: 'Juzgado de Letras del Trabajo de Los Ángeles', comuna: 'Los Ángeles', region: 'Biobío', diasAumentoEmplazamiento: 0),
    TribunalItem(nombre: 'Juzgado de Letras del Trabajo de Temuco', comuna: 'Temuco', region: 'Araucanía', diasAumentoEmplazamiento: 0),
    TribunalItem(nombre: 'Juzgado de Letras del Trabajo de Valdivia', comuna: 'Valdivia', region: 'Los Ríos', diasAumentoEmplazamiento: 0),
    TribunalItem(nombre: 'Juzgado de Letras del Trabajo de Osorno', comuna: 'Osorno', region: 'Los Lagos', diasAumentoEmplazamiento: 0),
    TribunalItem(nombre: 'Juzgado de Letras del Trabajo de Puerto Montt', comuna: 'Puerto Montt', region: 'Los Lagos', diasAumentoEmplazamiento: 0),
    TribunalItem(nombre: 'Juzgado de Letras del Trabajo de Punta Arenas', comuna: 'Punta Arenas', region: 'Magallanes', diasAumentoEmplazamiento: 0),

    // -------------------------------------------------------------------------
    // II. TRIBUNALES ESPECIALES (Fuera del Poder Judicial)
    // -------------------------------------------------------------------------
    TribunalItem(nombre: 'Tribunal Constitucional de Chile (TC)', comuna: 'Santiago', region: 'RM'),
    TribunalItem(nombre: 'Tribunal de Defensa de la Libre Competencia (TDLC)', comuna: 'Santiago', region: 'RM'),
    TribunalItem(nombre: '1º Tribunal Ambiental', comuna: 'Antofagasta', region: 'Antofagasta'),
    TribunalItem(nombre: '2º Tribunal Ambiental', comuna: 'Santiago', region: 'RM'),
    TribunalItem(nombre: '3º Tribunal Ambiental', comuna: 'Valdivia', region: 'Los Ríos'),
    TribunalItem(nombre: 'Tribunal de Propiedad Industrial (TDPI)', comuna: 'Santiago', region: 'RM'),
    TribunalItem(nombre: 'Tribunal Calificador de Elecciones (TRICEL)', comuna: 'Santiago', region: 'RM'),
    TribunalItem(nombre: 'Tribunales Electorales Regionales (TER 1º al 16º)', comuna: 'Capitales Regionales', region: 'Nacional'),
    TribunalItem(nombre: 'Tribunales Militares y Navales de Chile', comuna: 'Santiago / Valparaíso / Iquique', region: 'Nacional'),

    // TRIBUNALES TRIBUTARIOS Y ADUANEROS (TTA)
    TribunalItem(nombre: 'Tribunal Tributario y Aduanero (TTA) Arica y Parinacota', comuna: 'Arica', region: 'Arica y Parinacota'),
    TribunalItem(nombre: 'Tribunal Tributario y Aduanero (TTA) Tarapacá', comuna: 'Iquique', region: 'Tarapacá'),
    TribunalItem(nombre: 'Tribunal Tributario y Aduanero (TTA) Antofagasta', comuna: 'Antofagasta', region: 'Antofagasta'),
    TribunalItem(nombre: 'Tribunal Tributario y Aduanero (TTA) Atacama', comuna: 'Copiapó', region: 'Atacama'),
    TribunalItem(nombre: 'Tribunal Tributario y Aduanero (TTA) Coquimbo', comuna: 'La Serena', region: 'Coquimbo'),
    TribunalItem(nombre: 'Tribunal Tributario y Aduanero (TTA) Valparaíso', comuna: 'Valparaíso', region: 'Valparaíso'),
    TribunalItem(nombre: '1º al 4º Tribunal Tributario y Aduanero (TTA) Metropolitano', comuna: 'Santiago', region: 'RM'),
    TribunalItem(nombre: 'Tribunal Tributario y Aduanero (TTA) O\'Higgins', comuna: 'Rancagua', region: 'O\'Higgins'),
    TribunalItem(nombre: 'Tribunal Tributario y Aduanero (TTA) Maule', comuna: 'Talca', region: 'Maule'),
    TribunalItem(nombre: 'Tribunal Tributario y Aduanero (TTA) Ñuble', comuna: 'Chillán', region: 'Ñuble'),
    TribunalItem(nombre: 'Tribunal Tributario y Aduanero (TTA) Biobío', comuna: 'Concepción', region: 'Biobío'),
    TribunalItem(nombre: 'Tribunal Tributario y Aduanero (TTA) La Araucanía', comuna: 'Temuco', region: 'Araucanía'),
    TribunalItem(nombre: 'Tribunal Tributario y Aduanero (TTA) Los Ríos', comuna: 'Valdivia', region: 'Los Ríos'),
    TribunalItem(nombre: 'Tribunal Tributario y Aduanero (TTA) Los Lagos', comuna: 'Puerto Montt', region: 'Los Lagos'),
    TribunalItem(nombre: 'Tribunal Tributario y Aduanero (TTA) Aysén', comuna: 'Coyhaique', region: 'Aysén'),
    TribunalItem(nombre: 'Tribunal Tributario y Aduanero (TTA) Magallanes', comuna: 'Punta Arenas', region: 'Magallanes'),

    // -------------------------------------------------------------------------
    // III. JUZGADOS DE POLICÍA LOCAL (JPL por Región)
    // -------------------------------------------------------------------------
    // Región Metropolitana (RM)
    TribunalItem(nombre: '1º al 5º Juzgado de Policía Local de Santiago', comuna: 'Santiago', region: 'RM'),
    TribunalItem(nombre: '1º al 3º Juzgado de Policía Local de Las Condes', comuna: 'Las Condes', region: 'RM'),
    TribunalItem(nombre: '1º al 3º Juzgado de Policía Local de La Florida', comuna: 'La Florida', region: 'RM'),
    TribunalItem(nombre: '1º y 2º Juzgado de Policía Local de Providencia', comuna: 'Providencia', region: 'RM'),
    TribunalItem(nombre: '1º al 3º Juzgado de Policía Local de Maipú', comuna: 'Maipú', region: 'RM'),
    TribunalItem(nombre: '1º y 2º Juzgado de Policía Local de Ñuñoa', comuna: 'Ñuñoa', region: 'RM'),
    TribunalItem(nombre: '1º y 2º Juzgado de Policía Local de Vitacura', comuna: 'Vitacura', region: 'RM'),
    TribunalItem(nombre: 'Juzgado de Policía Local de Buin', comuna: 'Buin', region: 'RM'),
    TribunalItem(nombre: 'Juzgado de Policía Local de Colina', comuna: 'Colina', region: 'RM'),
    TribunalItem(nombre: 'Juzgado de Policía Local de Conchalí', comuna: 'Conchalí', region: 'RM'),
    TribunalItem(nombre: 'Juzgado de Policía Local de Curacaví', comuna: 'Curacaví', region: 'RM'),
    TribunalItem(nombre: 'Juzgado de Policía Local de El Bosque', comuna: 'El Bosque', region: 'RM'),
    TribunalItem(nombre: '1º y 2º Juzgado de Policía Local de Estación Central', comuna: 'Estación Central', region: 'RM'),
    TribunalItem(nombre: 'Juzgado de Policía Local de Huechuraba', comuna: 'Huechuraba', region: 'RM'),
    TribunalItem(nombre: 'Juzgado de Policía Local de Independencia', comuna: 'Independencia', region: 'RM'),
    TribunalItem(nombre: 'Juzgado de Policía Local de La Cisterna', comuna: 'La Cisterna', region: 'RM'),
    TribunalItem(nombre: 'Juzgado de Policía Local de La Granja', comuna: 'La Granja', region: 'RM'),
    TribunalItem(nombre: 'Juzgado de Policía Local de La Pintana', comuna: 'La Pintana', region: 'RM'),
    TribunalItem(nombre: 'Juzgado de Policía Local de La Reina', comuna: 'La Reina', region: 'RM'),
    TribunalItem(nombre: 'Juzgado de Policía Local de Lo Barnechea', comuna: 'Lo Barnechea', region: 'RM'),
    TribunalItem(nombre: '1º y 2º Juzgado de Policía Local de Lo Espejo', comuna: 'Lo Espejo', region: 'RM'),
    TribunalItem(nombre: 'Juzgado de Policía Local de Lo Prado', comuna: 'Lo Prado', region: 'RM'),
    TribunalItem(nombre: 'Juzgado de Policía Local de Macul', comuna: 'Macul', region: 'RM'),
    TribunalItem(nombre: 'Juzgado de Policía Local de Melipilla', comuna: 'Melipilla', region: 'RM'),
    TribunalItem(nombre: 'Juzgado de Policía Local de Paine', comuna: 'Paine', region: 'RM'),
    TribunalItem(nombre: 'Juzgado de Policía Local de Pedro Aguirre Cerda', comuna: 'Pedro Aguirre Cerda', region: 'RM'),
    TribunalItem(nombre: 'Juzgado de Policía Local de Peñalolén', comuna: 'Peñalolén', region: 'RM'),
    TribunalItem(nombre: 'Juzgado de Policía Local de Pirque', comuna: 'Pirque', region: 'RM'),
    TribunalItem(nombre: '1º y 2º Juzgado de Policía Local de Pudahuel', comuna: 'Pudahuel', region: 'RM'),
    TribunalItem(nombre: '1º y 2º Juzgado de Policía Local de Puente Alto', comuna: 'Puente Alto', region: 'RM'),
    TribunalItem(nombre: 'Juzgado de Policía Local de Quilicura', comuna: 'Quilicura', region: 'RM'),
    TribunalItem(nombre: 'Juzgado de Policía Local de Quinta Normal', comuna: 'Quinta Normal', region: 'RM'),
    TribunalItem(nombre: '1º y 2º Juzgado de Policía Local de Recoleta', comuna: 'Recoleta', region: 'RM'),
    TribunalItem(nombre: 'Juzgado de Policía Local de Renca', comuna: 'Renca', region: 'RM'),
    TribunalItem(nombre: '1º y 2º Juzgado de Policía Local de San Bernardo', comuna: 'San Bernardo', region: 'RM'),
    TribunalItem(nombre: 'Juzgado de Policía Local de San Joaquín', comuna: 'San Joaquín', region: 'RM'),
    TribunalItem(nombre: 'Juzgado de Policía Local de San José de Maipo', comuna: 'San José de Maipo', region: 'RM'),
    TribunalItem(nombre: '1º y 2º Juzgado de Policía Local de San Miguel', comuna: 'San Miguel', region: 'RM'),
    TribunalItem(nombre: 'Juzgado de Policía Local de San Ramón', comuna: 'San Ramón', region: 'RM'),
    TribunalItem(nombre: 'Juzgado de Policía Local de Talagante', comuna: 'Talagante', region: 'RM'),
    TribunalItem(nombre: 'Juzgado de Policía Local de Isla de Maipo', comuna: 'Isla de Maipo', region: 'RM'),
    TribunalItem(nombre: 'Juzgado de Policía Local de El Monte', comuna: 'El Monte', region: 'RM'),
    TribunalItem(nombre: 'Juzgado de Policía Local de Padre Hurtado', comuna: 'Padre Hurtado', region: 'RM'),
    TribunalItem(nombre: 'Juzgado de Policía Local de Peñaflor', comuna: 'Peñaflor', region: 'RM'),

    // Región de Valparaíso
    TribunalItem(nombre: '1º y 2º Juzgado de Policía Local de Valparaíso', comuna: 'Valparaíso', region: 'Valparaíso'),
    TribunalItem(nombre: '1º y 2º Juzgado de Policía Local de Viña del Mar', comuna: 'Viña del Mar', region: 'Valparaíso'),
    TribunalItem(nombre: 'Juzgado de Policía Local de Quilpué', comuna: 'Quilpué', region: 'Valparaíso'),
    TribunalItem(nombre: 'Juzgado de Policía Local de Villa Alemana', comuna: 'Villa Alemana', region: 'Valparaíso'),
    TribunalItem(nombre: 'Juzgado de Policía Local de Quillota', comuna: 'Quillota', region: 'Valparaíso'),
    TribunalItem(nombre: 'Juzgado de Policía Local de San Antonio', comuna: 'San Antonio', region: 'Valparaíso'),
    TribunalItem(nombre: 'Juzgado de Policía Local de Los Andes', comuna: 'Los Andes', region: 'Valparaíso'),
    TribunalItem(nombre: 'Juzgado de Policía Local de San Felipe', comuna: 'San Felipe', region: 'Valparaíso'),
    TribunalItem(nombre: 'Juzgado de Policía Local de La Ligua', comuna: 'La Ligua', region: 'Valparaíso'),
    TribunalItem(nombre: 'Juzgado de Policía Local de Limache', comuna: 'Limache', region: 'Valparaíso'),
    TribunalItem(nombre: 'Juzgado de Policía Local de Olmué', comuna: 'Olmué', region: 'Valparaíso'),
    TribunalItem(nombre: 'Juzgado de Policía Local de Concón', comuna: 'Concón', region: 'Valparaíso'),
    TribunalItem(nombre: 'Juzgado de Policía Local de Quintero', comuna: 'Quintero', region: 'Valparaíso'),
    TribunalItem(nombre: 'Juzgado de Policía Local de Puchuncaví', comuna: 'Puchuncaví', region: 'Valparaíso'),
    TribunalItem(nombre: 'Juzgado de Policía Local de Casablanca', comuna: 'Casablanca', region: 'Valparaíso'),
    TribunalItem(nombre: 'Juzgado de Policía Local de Isla de Pascua', comuna: 'Isla de Pascua', region: 'Valparaíso'),
    TribunalItem(nombre: 'Juzgado de Policía Local de Juan Fernández', comuna: 'Juan Fernández', region: 'Valparaíso'),

    // Región del Biobío
    TribunalItem(nombre: '1º al 3º Juzgado de Policía Local de Concepción', comuna: 'Concepción', region: 'Biobío'),
    TribunalItem(nombre: '1º y 2º Juzgado de Policía Local de Talcahuano', comuna: 'Talcahuano', region: 'Biobío'),
    TribunalItem(nombre: '1º y 2º Juzgado de Policía Local de San Pedro de la Paz', comuna: 'San Pedro de la Paz', region: 'Biobío'),
    TribunalItem(nombre: 'Juzgado de Policía Local de Chiguayante', comuna: 'Chiguayante', region: 'Biobío'),
    TribunalItem(nombre: 'Juzgado de Policía Local de Coronel', comuna: 'Coronel', region: 'Biobío'),
    TribunalItem(nombre: 'Juzgado de Policía Local de Lota', comuna: 'Lota', region: 'Biobío'),
    TribunalItem(nombre: 'Juzgado de Policía Local de Hualpén', comuna: 'Hualpén', region: 'Biobío'),
    TribunalItem(nombre: 'Juzgado de Policía Local de Penco', comuna: 'Penco', region: 'Biobío'),
    TribunalItem(nombre: 'Juzgado de Policía Local de Tomé', comuna: 'Tomé', region: 'Biobío'),
    TribunalItem(nombre: '1º y 2º Juzgado de Policía Local de Los Ángeles', comuna: 'Los Ángeles', region: 'Biobío'),
    TribunalItem(nombre: 'Juzgado de Policía Local de Nacimiento', comuna: 'Nacimiento', region: 'Biobío'),
    TribunalItem(nombre: 'Juzgado de Policía Local de Mulchén', comuna: 'Mulchén', region: 'Biobío'),
    TribunalItem(nombre: 'Juzgado de Policía Local de Cabrero', comuna: 'Cabrero', region: 'Biobío'),
    TribunalItem(nombre: 'Juzgado de Policía Local de Yumbel', comuna: 'Yumbel', region: 'Biobío'),
    TribunalItem(nombre: 'Juzgado de Policía Local de Lebu', comuna: 'Lebu', region: 'Biobío'),
    TribunalItem(nombre: 'Juzgado de Policía Local de Arauco', comuna: 'Arauco', region: 'Biobío'),
    TribunalItem(nombre: 'Juzgado de Policía Local de Cañete', comuna: 'Cañete', region: 'Biobío'),
    TribunalItem(nombre: 'Juzgado de Policía Local de Curanilahue', comuna: 'Curanilahue', region: 'Biobío'),

    // Región de La Araucanía
    TribunalItem(nombre: '1º y 2º Juzgado de Policía Local de Temuco', comuna: 'Temuco', region: 'Araucanía'),
    TribunalItem(nombre: 'Juzgado de Policía Local de Padre Las Casas', comuna: 'Padre Las Casas', region: 'Araucanía'),
    TribunalItem(nombre: 'Juzgado de Policía Local de Angol', comuna: 'Angol', region: 'Araucanía'),
    TribunalItem(nombre: 'Juzgado de Policía Local de Villarrica', comuna: 'Villarrica', region: 'Araucanía'),
    TribunalItem(nombre: 'Juzgado de Policía Local de Pucón', comuna: 'Pucón', region: 'Araucanía'),
    TribunalItem(nombre: 'Juzgado de Policía Local de Lautaro', comuna: 'Lautaro', region: 'Araucanía'),
    TribunalItem(nombre: 'Juzgado de Policía Local de Victoria', comuna: 'Victoria', region: 'Araucanía'),
    TribunalItem(nombre: 'Juzgado de Policía Local de Nueva Imperial', comuna: 'Nueva Imperial', region: 'Araucanía'),
    TribunalItem(nombre: 'Juzgado de Policía Local de Carahue', comuna: 'Carahue', region: 'Araucanía'),
    TribunalItem(nombre: 'Juzgado de Policía Local de Pitrufquén', comuna: 'Pitrufquén', region: 'Araucanía'),
    TribunalItem(nombre: 'Juzgado de Policía Local de Collipulli', comuna: 'Collipulli', region: 'Araucanía'),
    TribunalItem(nombre: 'Juzgado de Policía Local de Traiguén', comuna: 'Traiguén', region: 'Araucanía'),

    // Región del Maule
    TribunalItem(nombre: '1º y 2º Juzgado de Policía Local de Talca', comuna: 'Talca', region: 'Maule'),
    TribunalItem(nombre: '1º y 2º Juzgado de Policía Local de Curicó', comuna: 'Curicó', region: 'Maule'),
    TribunalItem(nombre: 'Juzgado de Policía Local de Linares', comuna: 'Linares', region: 'Maule'),
    TribunalItem(nombre: 'Juzgado de Policía Local de Cauquenes', comuna: 'Cauquenes', region: 'Maule'),
    TribunalItem(nombre: 'Juzgado de Policía Local de Constitución', comuna: 'Constitución', region: 'Maule'),
    TribunalItem(nombre: 'Juzgado de Policía Local de San Javier', comuna: 'San Javier', region: 'Maule'),
    TribunalItem(nombre: 'Juzgado de Policía Local de Molina', comuna: 'Molina', region: 'Maule'),
    TribunalItem(nombre: 'Juzgado de Policía Local de Parral', comuna: 'Parral', region: 'Maule'),
    TribunalItem(nombre: 'Juzgado de Policía Local de San Clemente', comuna: 'San Clemente', region: 'Maule'),
    TribunalItem(nombre: 'Juzgado de Policía Local de Teno', comuna: 'Teno', region: 'Maule'),
    TribunalItem(nombre: 'Juzgado de Policía Local de Longaví', comuna: 'Longaví', region: 'Maule'),

    // Región de Ñuble
    TribunalItem(nombre: '1º y 2º Juzgado de Policía Local de Chillán', comuna: 'Chillán', region: 'Ñuble'),
    TribunalItem(nombre: 'Juzgado de Policía Local de Chillán Viejo', comuna: 'Chillán Viejo', region: 'Ñuble'),
    TribunalItem(nombre: 'Juzgado de Policía Local de San Carlos', comuna: 'San Carlos', region: 'Ñuble'),
    TribunalItem(nombre: 'Juzgado de Policía Local de Bulnes', comuna: 'Bulnes', region: 'Ñuble'),
    TribunalItem(nombre: 'Juzgado de Policía Local de Yungay', comuna: 'Yungay', region: 'Ñuble'),
    TribunalItem(nombre: 'Juzgado de Policía Local de Quillón', comuna: 'Quillón', region: 'Ñuble'),
    TribunalItem(nombre: 'Juzgado de Policía Local de Coihueco', comuna: 'Coihueco', region: 'Ñuble'),
    TribunalItem(nombre: 'Juzgado de Policía Local de San Nicolás', comuna: 'San Nicolás', region: 'Ñuble'),

    // Región de Coquimbo
    TribunalItem(nombre: 'Juzgado de Policía Local de La Serena', comuna: 'La Serena', region: 'Coquimbo'),
    TribunalItem(nombre: 'Juzgado de Policía Local de Coquimbo', comuna: 'Coquimbo', region: 'Coquimbo'),
    TribunalItem(nombre: 'Juzgado de Policía Local de Ovalle', comuna: 'Ovalle', region: 'Coquimbo'),
    TribunalItem(nombre: 'Juzgado de Policía Local de Illapel', comuna: 'Illapel', region: 'Coquimbo'),
    TribunalItem(nombre: 'Juzgado de Policía Local de Vicuña', comuna: 'Vicuña', region: 'Coquimbo'),
    TribunalItem(nombre: 'Juzgado de Policía Local de Andacollo', comuna: 'Andacollo', region: 'Coquimbo'),
    TribunalItem(nombre: 'Juzgado de Policía Local de Los Vilos', comuna: 'Los Vilos', region: 'Coquimbo'),
    TribunalItem(nombre: 'Juzgado de Policía Local de Salamanca', comuna: 'Salamanca', region: 'Coquimbo'),
    TribunalItem(nombre: 'Juzgado de Policía Local de Monte Patria', comuna: 'Monte Patria', region: 'Coquimbo'),

    // Región de Antofagasta
    TribunalItem(nombre: '1º y 2º Juzgado de Policía Local de Antofagasta', comuna: 'Antofagasta', region: 'Antofagasta'),
    TribunalItem(nombre: '1º y 2º Juzgado de Policía Local de Calama', comuna: 'Calama', region: 'Antofagasta'),
    TribunalItem(nombre: 'Juzgado de Policía Local de Tocopilla', comuna: 'Tocopilla', region: 'Antofagasta'),
    TribunalItem(nombre: 'Juzgado de Policía Local de Taltal', comuna: 'Taltal', region: 'Antofagasta'),
    TribunalItem(nombre: 'Juzgado de Policía Local de Mejillones', comuna: 'Mejillones', region: 'Antofagasta'),
    TribunalItem(nombre: 'Juzgado de Policía Local de San Pedro de Atacama', comuna: 'San Pedro de Atacama', region: 'Antofagasta'),

    // Región de Los Lagos
    TribunalItem(nombre: '1º y 2º Juzgado de Policía Local de Puerto Montt', comuna: 'Puerto Montt', region: 'Los Lagos'),
    TribunalItem(nombre: '1º y 2º Juzgado de Policía Local de Osorno', comuna: 'Osorno', region: 'Los Lagos'),
    TribunalItem(nombre: 'Juzgado de Policía Local de Castro', comuna: 'Castro', region: 'Los Lagos'),
    TribunalItem(nombre: 'Juzgado de Policía Local de Ancud', comuna: 'Ancud', region: 'Los Lagos'),
    TribunalItem(nombre: 'Juzgado de Policía Local de Puerto Varas', comuna: 'Puerto Varas', region: 'Los Lagos'),
    TribunalItem(nombre: 'Juzgado de Policía Local de Llanquihue', comuna: 'Llanquihue', region: 'Los Lagos'),
    TribunalItem(nombre: 'Juzgado de Policía Local de Frutillar', comuna: 'Frutillar', region: 'Los Lagos'),
    TribunalItem(nombre: 'Juzgado de Policía Local de Calbuco', comuna: 'Calbuco', region: 'Los Lagos'),
    TribunalItem(nombre: 'Juzgado de Policía Local de Quellón', comuna: 'Quellón', region: 'Los Lagos'),

    // Arica y Parinacota, Tarapacá, Atacama, O'Higgins, Los Ríos, Aysén, Magallanes
    TribunalItem(nombre: '1º y 2º Juzgado de Policía Local de Arica', comuna: 'Arica', region: 'Arica y Parinacota'),
    TribunalItem(nombre: 'Juzgado de Policía Local de Putre', comuna: 'Putre', region: 'Arica y Parinacota'),
    TribunalItem(nombre: '1º y 2º Juzgado de Policía Local de Iquique', comuna: 'Iquique', region: 'Tarapacá'),
    TribunalItem(nombre: 'Juzgado de Policía Local de Alto Hospicio', comuna: 'Alto Hospicio', region: 'Tarapacá'),
    TribunalItem(nombre: 'Juzgado de Policía Local de Pozo Almonte', comuna: 'Pozo Almonte', region: 'Tarapacá'),
    TribunalItem(nombre: 'Juzgado de Policía Local de Pica', comuna: 'Pica', region: 'Tarapacá'),
    TribunalItem(nombre: 'Juzgado de Policía Local de Huara', comuna: 'Huara', region: 'Tarapacá'),
    TribunalItem(nombre: '1º y 2º Juzgado de Policía Local de Copiapó', comuna: 'Copiapó', region: 'Atacama'),
    TribunalItem(nombre: 'Juzgado de Policía Local de Vallenar', comuna: 'Vallenar', region: 'Atacama'),
    TribunalItem(nombre: 'Juzgado de Policía Local de Chañaral', comuna: 'Chañaral', region: 'Atacama'),
    TribunalItem(nombre: 'Juzgado de Policía Local de Caldera', comuna: 'Caldera', region: 'Atacama'),
    TribunalItem(nombre: 'Juzgado de Policía Local de Diego de Almagro', comuna: 'Diego de Almagro', region: 'Atacama'),
    TribunalItem(nombre: 'Juzgado de Policía Local de Huasco', comuna: 'Huasco', region: 'Atacama'),
    TribunalItem(nombre: '1º y 2º Juzgado de Policía Local de Rancagua', comuna: 'Rancagua', region: 'O\'Higgins'),
    TribunalItem(nombre: 'Juzgado de Policía Local de Machalí', comuna: 'Machalí', region: 'O\'Higgins'),
    TribunalItem(nombre: 'Juzgado de Policía Local de Rengo', comuna: 'Rengo', region: 'O\'Higgins'),
    TribunalItem(nombre: 'Juzgado de Policía Local de San Fernando', comuna: 'San Fernando', region: 'O\'Higgins'),
    TribunalItem(nombre: 'Juzgado de Policía Local de Pichilemu', comuna: 'Pichilemu', region: 'O\'Higgins'),
    TribunalItem(nombre: 'Juzgado de Policía Local de Chimbarongo', comuna: 'Chimbarongo', region: 'O\'Higgins'),
    TribunalItem(nombre: 'Juzgado de Policía Local de Graneros', comuna: 'Graneros', region: 'O\'Higgins'),
    TribunalItem(nombre: 'Juzgado de Policía Local de San Vicente', comuna: 'San Vicente', region: 'O\'Higgins'),
    TribunalItem(nombre: '1º y 2º Juzgado de Policía Local de Valdivia', comuna: 'Valdivia', region: 'Los Ríos'),
    TribunalItem(nombre: 'Juzgado de Policía Local de La Unión', comuna: 'La Unión', region: 'Los Ríos'),
    TribunalItem(nombre: 'Juzgado de Policía Local de Río Bueno', comuna: 'Río Bueno', region: 'Los Ríos'),
    TribunalItem(nombre: 'Juzgado de Policía Local de Panguipulli', comuna: 'Panguipulli', region: 'Los Ríos'),
    TribunalItem(nombre: 'Juzgado de Policía Local de Paillaco', comuna: 'Paillaco', region: 'Los Ríos'),
    TribunalItem(nombre: 'Juzgado de Policía Local de Mariquina', comuna: 'Mariquina', region: 'Los Ríos'),
    TribunalItem(nombre: 'Juzgado de Policía Local de Coyhaique', comuna: 'Coyhaique', region: 'Aysén'),
    TribunalItem(nombre: 'Juzgado de Policía Local de Puerto Aysén', comuna: 'Puerto Aysén', region: 'Aysén'),
    TribunalItem(nombre: 'Juzgado de Policía Local de Chile Chico', comuna: 'Chile Chico', region: 'Aysén'),
    TribunalItem(nombre: 'Juzgado de Policía Local de Cochrane', comuna: 'Cochrane', region: 'Aysén'),
    TribunalItem(nombre: '1º y 2º Juzgado de Policía Local de Punta Arenas', comuna: 'Punta Arenas', region: 'Magallanes'),
    TribunalItem(nombre: 'Juzgado de Policía Local de Puerto Natales', comuna: 'Puerto Natales', region: 'Magallanes'),
    TribunalItem(nombre: 'Juzgado de Policía Local de Porvenir', comuna: 'Porvenir', region: 'Magallanes'),
    TribunalItem(nombre: 'Juzgado de Policía Local de Cabo de Hornos', comuna: 'Cabo de Hornos', region: 'Magallanes'),
  ];
}

// -----------------------------------------------------------------------------
// SERVICIO DE FERIADOS API & FALLBACK
// -----------------------------------------------------------------------------

class FeriadosService {
  static List<DateTime> feriadosDinamicos = [];
  static bool apiOnline = false;

  static Future<void> inicializarFeriados() async {
    try {
      final response2026 = await http.get(Uri.parse('https://apis.digital.gob.cl/fl/feriados/2026')).timeout(const Duration(seconds: 5));
      final response2027 = await http.get(Uri.parse('https://apis.digital.gob.cl/fl/feriados/2027')).timeout(const Duration(seconds: 5));

      if (response2026.statusCode == 200) {
        List<dynamic> data2026 = jsonDecode(response2026.body);
        for (var item in data2026) {
          feriadosDinamicos.add(DateTime.parse(item['fecha']));
        }
      }
      if (response2027.statusCode == 200) {
        List<dynamic> data2027 = jsonDecode(response2027.body);
        for (var item in data2027) {
          feriadosDinamicos.add(DateTime.parse(item['fecha']));
        }
      }
      if (feriadosDinamicos.isNotEmpty) {
        apiOnline = true;
        return;
      }
    } catch (e) {
      apiOnline = false;
    }
    _cargarFeriadosFallback();
  }

  static void _cargarFeriadosFallback() {
    feriadosDinamicos.addAll([
      DateTime(2026, 1, 1), DateTime(2026, 4, 3), DateTime(2026, 4, 4), DateTime(2026, 5, 1),
      DateTime(2026, 5, 21), DateTime(2026, 6, 20), DateTime(2026, 6, 29), DateTime(2026, 7, 16),
      DateTime(2026, 8, 15), DateTime(2026, 9, 18), DateTime(2026, 9, 19), DateTime(2026, 10, 12),
      DateTime(2026, 10, 31), DateTime(2026, 11, 1), DateTime(2026, 12, 8), DateTime(2026, 12, 25),
      DateTime(2027, 1, 1), DateTime(2027, 3, 26), DateTime(2027, 3, 27), DateTime(2027, 5, 1),
      DateTime(2027, 5, 21), DateTime(2027, 6, 20), DateTime(2027, 6, 28), DateTime(2027, 7, 16),
      DateTime(2027, 8, 15), DateTime(2027, 9, 17), DateTime(2027, 9, 18), DateTime(2027, 9, 19),
      DateTime(2027, 10, 11), DateTime(2027, 10, 31), DateTime(2027, 11, 1), DateTime(2027, 12, 8),
      DateTime(2027, 12, 25)
    ]);
  }

  static bool esFeriado(DateTime date) {
    return feriadosDinamicos.any((f) => f.year == date.year && f.month == date.month && f.day == date.day);
  }
}

// -----------------------------------------------------------------------------
// CALCULADOR CORE
// -----------------------------------------------------------------------------

class DeadlineCalculator {
  static DateTime calcularFechaVencimiento({
    required DateTime fechaInicio,
    required int diasBase,
    required int diasAumentoEmplazamiento,
    required TipoComputoDias tipoComputo,
  }) {
    int diasTotales = diasBase + diasAumentoEmplazamiento;
    DateTime fechaCur = fechaInicio;
    int diasAgregados = 0;

    if (diasTotales == 0) return fechaCur;

    while (diasAgregados < diasTotales) {
      fechaCur = fechaCur.add(const Duration(days: 1));

      bool esDomingo = fechaCur.weekday == DateTime.sunday;
      bool esSabado = fechaCur.weekday == DateTime.saturday;
      bool esFeriado = FeriadosService.esFeriado(fechaCur);

      switch (tipoComputo) {
        case TipoComputoDias.habilesCivil:
          if (!esDomingo && !esFeriado) diasAgregados++;
          break;
        case TipoComputoDias.habilesAdmin:
          if (!esSabado && !esDomingo && !esFeriado) diasAgregados++;
          break;
        case TipoComputoDias.habilesLaboral:
          if (!esDomingo && !esFeriado) diasAgregados++;
          break;
        case TipoComputoDias.corridos:
          diasAgregados++;
          break;
      }
    }

    if (tipoComputo == TipoComputoDias.corridos) {
      while (fechaCur.weekday == DateTime.sunday || FeriadosService.esFeriado(fechaCur)) {
        fechaCur = fechaCur.add(const Duration(days: 1));
      }
    }

    return fechaCur;
  }
}

String formatFechaEspanol(DateTime date) {
  const dias = ['Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo'];
  const meses = ['Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio', 'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'];
  return '${dias[date.weekday - 1]} ${date.day} de ${meses[date.month - 1]} de ${date.year}';
}

// -----------------------------------------------------------------------------
// PANTALLA PRINCIPAL
// -----------------------------------------------------------------------------

class PlazosProcesalesScreen extends StatefulWidget {
  const PlazosProcesalesScreen({super.key});

  @override
  State<PlazosProcesalesScreen> createState() => _PlazosProcesalesScreenState();
}

class _PlazosProcesalesScreenState extends State<PlazosProcesalesScreen> {
  final HistoryRepository _historyRepo = HistoryRepository();

  bool _cargandoFeriados = true;
  MateriaSubmateria? _selectedMateria;
  ActuacionProcesal? _selectedActuacion;
  TribunalItem? _selectedTribunal;
  DateTime _fechaNotificacion = DateTime.now();

  // Tipo de Letra y Rol / RUC
  String _tipoLetra = 'Rol C (Civil - Ordinario, Ejecutivo, Sumario)';
  final TextEditingController _numeroCausaController = TextEditingController();
  final TextEditingController _anioCausaController = TextEditingController(text: DateTime.now().year.toString());
  final TextEditingController _rucController = TextEditingController();

  List<String> _obtenerOpcionesTiposLetraParaMateria(MateriaSubmateria? materia) {
    if (materia == null) return ['Libre / Personalizado'];

    final id = materia.id;

    // Laboral
    if (id.startsWith('mix_lab')) {
      return [
        'RIT O (Ordinario Laboral / Despido)',
        'RIT P (Monitorio Laboral ≤ 10 UTM)',
        'RIT T (Tutela Laboral / Derechos Fundamentales)',
        'RIT C (Cobranza Laboral / Previsional)',
        'RUC (Registro Único de Causa Laboral)',
        'Rol Corte (Recurso de Nulidad / Unificación)',
        'Libre / Personalizado',
      ];
    }

    // Civil y Arrendamiento
    if (id.startsWith('priv_civ') || id.startsWith('priv_com')) {
      return [
        'Rol C (Civil - Ordinario, Ejecutivo, Sumario, Arriendo)',
        'Rol V (Civil - Asuntos Voluntarios)',
        'Rol E (Civil - Exequátur / Especial)',
        'Rol J (Cobranza / Ejecutivo Especial)',
        'Rol Corte (Apelación / Casación Civil)',
        'Libre / Personalizado',
      ];
    }

    // Familia
    if (id.startsWith('mix_fam')) {
      return [
        'RIT F (Familia - Alimentos / Divorcio / Ordinario)',
        'RIT C (Familia - Cuidado Personal / Tuición / Visitas)',
        'RIT M (Familia - Medidas de Protección NNA)',
        'RIT X (Familia - Violencia Intrafamiliar VIF)',
        'RIT Z (Familia - Cumplimiento de Sentencia)',
        'RUC (Registro Único de Causa Familia)',
        'Rol Corte (Apelación Familia / Protección)',
        'Libre / Personalizado',
      ];
    }

    // Penal
    if (id == 'pub_penal') {
      return [
        'RIT O (Juicio Oral Penal - TOP)',
        'RIT P (Procedimiento Simplificado / Abreviado Penal)',
        'RIT I (Garantía / Investigación Penal)',
        'RUC (Registro Único de Causa Penal)',
        'Rol Corte (Nulidad / Apelación / Amparo Penal)',
        'Libre / Personalizado',
      ];
    }

    // Tributario y Aduanero
    if (id == 'pub_trib') {
      return [
        'RIT T (TTA - Tributario)',
        'RIT A (TTA - Aduanero)',
        'RUC (Registro Único TTA)',
        'Rol Corte (Apelación / Casación TTA)',
        'Libre / Personalizado',
      ];
    }

    // Policía Local
    if (id == 'mix_pol_loc') {
      return [
        'Rol JPL (Juzgado de Policía Local)',
        'Rol Corte (Apelación Policía Local)',
        'Libre / Personalizado',
      ];
    }

    // Constitucional / Administrativo
    if (id == 'pub_const' || id == 'pub_tc' || id == 'pub_admin') {
      return [
        'Rol Corte (Recurso de Protección / Amparo)',
        'Rol TC (Tribunal Constitucional - INA / INC)',
        'RUC / Registro Administrativo',
        'Libre / Personalizado',
      ];
    }

    return [
      'Rol C (Civil - Ordinario, Ejecutivo, Sumario)',
      'RIT O (Ordinario)',
      'RUC (Registro Único de Causa)',
      'Libre / Personalizado',
    ];
  }

  bool _calculado = false;
  DateTime? _fechaVencimientoFinal;
  CalculationRecord? _ultimoRegistro;
  List<CalculationRecord> _historial = [];

  @override
  void initState() {
    super.initState();
    _initData();
  }

  @override
  void dispose() {
    _numeroCausaController.dispose();
    _anioCausaController.dispose();
    _rucController.dispose();
    super.dispose();
  }

  Future<void> _initData() async {
    await FeriadosService.inicializarFeriados();
    final historialCargado = await _historyRepo.getHistory();

    setState(() {
      _selectedMateria = LegalDatabase.materias.first;
      _updateActuacionesList();
      final opciones = _obtenerOpcionesTiposLetraParaMateria(_selectedMateria);
      _tipoLetra = opciones.first;
      _selectedTribunal = LegalDatabase.tribunales.first;
      _historial = historialCargado;
      _cargandoFeriados = false;
    });
  }

  void _onMateriaChanged(MateriaSubmateria? nuevaMateria) {
    setState(() {
      _selectedMateria = nuevaMateria;
      _updateActuacionesList();
      final opciones = _obtenerOpcionesTiposLetraParaMateria(nuevaMateria);
      _tipoLetra = opciones.first;
      _calculado = false;
    });
  }

  void _updateActuacionesList() {
    final disponibles = LegalDatabase.actuaciones.where((a) => a.materiaId == _selectedMateria?.id).toList();
    _selectedActuacion = disponibles.isNotEmpty ? disponibles.first : null;
    _calculado = false;
  }

  String _obtenerRolRucCompleto() {
    final num = _numeroCausaController.text.trim();
    final anio = _anioCausaController.text.trim();
    final ruc = _rucController.text.trim();

    if (_tipoLetra.startsWith('RUC')) {
      return ruc.isNotEmpty ? 'RUC $ruc' : 'RUC Pendiente';
    }

    String baseRol = '';
    if (_tipoLetra.startsWith('Rol ')) {
      final partes = _tipoLetra.split(' ');
      final letra = partes[1];
      baseRol = num.isNotEmpty ? 'Rol $letra-$num-$anio' : 'Rol $letra-___-$anio';
    } else if (_tipoLetra.startsWith('RIT ')) {
      final partes = _tipoLetra.split(' ');
      final letra = partes[1];
      baseRol = num.isNotEmpty ? 'RIT $letra-$num-$anio' : 'RIT $letra-___-$anio';
    } else {
      baseRol = num.isNotEmpty ? '$num-$anio' : 'Sin Rol Definido';
    }

    if (ruc.isNotEmpty) {
      return 'RUC $ruc | $baseRol';
    }
    return baseRol;
  }

  void _abrirModalBuscadorTribunales() {
    String filtroTexto = '';
    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final listaFiltrada = LegalDatabase.tribunales.where((t) {
              if (filtroTexto.isEmpty) return true;
              final q = filtroTexto.toLowerCase();
              return t.nombre.toLowerCase().contains(q) ||
                     t.comuna.toLowerCase().contains(q) ||
                     t.region.toLowerCase().contains(q);
            }).toList();

            return AlertDialog(
              backgroundColor: const Color(0xFF161A22),
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.account_balance, color: Color(0xFF00FF66)),
                      SizedBox(width: 8),
                      Text('Lista Completa de Tribunales de Chile', style: TextStyle(color: Color(0xFF00FF66), fontSize: 18, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    autofocus: true,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Filtrar por nombre, comuna o región...',
                      prefixIcon: const Icon(Icons.search, color: Color(0xFF00FF66)),
                      suffixIcon: filtroTexto.isNotEmpty ? IconButton(
                        icon: const Icon(Icons.clear, color: Colors.white54),
                        onPressed: () => setModalState(() => filtroTexto = ''),
                      ) : null,
                    ),
                    onChanged: (val) => setModalState(() => filtroTexto = val),
                  ),
                ],
              ),
              content: SizedBox(
                width: 650,
                height: 450,
                child: Column(
                  children: [
                    Text('Mostrando ${listaFiltrada.length} tribunales disponibles:', style: const TextStyle(fontSize: 12, color: Colors.white60)),
                    const SizedBox(height: 8),
                    Expanded(
                      child: ListView.separated(
                        itemCount: listaFiltrada.length,
                        separatorBuilder: (_, __) => const Divider(color: Color(0xFF2E3848), height: 1),
                        itemBuilder: (context, index) {
                          final item = listaFiltrada[index];
                          final esSeleccionado = _selectedTribunal?.nombre == item.nombre;
                          return ListTile(
                            dense: true,
                            tileColor: esSeleccionado ? const Color(0xFF0F2B1D) : null,
                            leading: Icon(
                              Icons.gavel,
                              color: esSeleccionado ? const Color(0xFF00FF66) : Colors.white38,
                              size: 18,
                            ),
                            title: Text(
                              item.nombre,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: esSeleccionado ? const Color(0xFF00FF66) : Colors.white,
                                fontSize: 13,
                              ),
                            ),
                            subtitle: Text(
                              'Comuna: ${item.comuna} | Región: ${item.region} ${item.diasAumentoEmplazamiento > 0 ? " [+${item.diasAumentoEmplazamiento}d emplazamiento]" : ""}',
                              style: TextStyle(
                                color: item.diasAumentoEmplazamiento > 0 ? Colors.amber : Colors.white54,
                                fontSize: 11,
                              ),
                            ),
                            onTap: () {
                              setState(() {
                                _selectedTribunal = item;
                                _calculado = false;
                              });
                              Navigator.pop(ctx);
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cerrar', style: TextStyle(color: Colors.white70)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _ejecutarCalculo() async {
    if (_selectedActuacion == null) return;

    int diasAumento = (_selectedActuacion!.admiteEmplazamiento && _selectedTribunal != null)
        ? _selectedTribunal!.diasAumentoEmplazamiento : 0;

    final resultado = DeadlineCalculator.calcularFechaVencimiento(
      fechaInicio: _fechaNotificacion,
      diasBase: _selectedActuacion!.diasBase,
      diasAumentoEmplazamiento: diasAumento,
      tipoComputo: _selectedActuacion!.tipoComputo,
    );

    final rolRucComp = _obtenerRolRucCompleto();

    String tipoComputoTexto = 'Días Hábiles Judiciales (Art. 66 CPC)';
    if (_selectedActuacion!.tipoComputo == TipoComputoDias.habilesAdmin) {
      tipoComputoTexto = 'Días Hábiles Administrativos (Ley N° 19.880)';
    } else if (_selectedActuacion!.tipoComputo == TipoComputoDias.corridos) {
      tipoComputoTexto = 'Días Corridos (Art. 14 CPP / Auto Acordados)';
    } else if (_selectedActuacion!.tipoComputo == TipoComputoDias.habilesLaboral) {
      tipoComputoTexto = 'Días Hábiles Laborales (Código del Trabajo)';
    }

    final nuevoRegistro = CalculationRecord(
      id: const Uuid().v4(),
      title: _selectedActuacion!.nombreActuacion,
      startDate: _fechaNotificacion,
      endDate: resultado,
      consultationDate: DateTime.now(),
      baseDays: _selectedActuacion!.diasBase,
      additionalDays: diasAumento,
      materia: Materia.civil,
      rolRuc: rolRucComp,
      tipoLetra: _tipoLetra,
      numeroCausa: _numeroCausaController.text,
      anioCausa: _anioCausaController.text,
      tribunal: _selectedTribunal != null ? '${_selectedTribunal!.nombre} - ${_selectedTribunal!.comuna}' : 'No especificado',
      materiaNombre: _selectedMateria?.displayName ?? '',
      actuacionNombre: _selectedActuacion!.nombreActuacion,
      articuloNorma: _selectedActuacion!.articuloYNorma,
      tipoComputoDesc: tipoComputoTexto,
      elementosConsiderar: _selectedActuacion!.elementosAConsiderar,
    );

    await _historyRepo.saveRecord(nuevoRegistro);
    final historialActualizado = await _historyRepo.getHistory();

    setState(() {
      _fechaVencimientoFinal = resultado;
      _ultimoRegistro = nuevoRegistro;
      _historial = historialActualizado;
      _calculado = true;
    });
  }

  void _eliminarRegistroHistorial(String id) async {
    await _historyRepo.deleteRecord(id);
    final historialActualizado = await _historyRepo.getHistory();
    setState(() {
      _historial = historialActualizado;
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Registro eliminado del historial persistente.')),
      );
    }
  }

  void _limpiarHistorialCompleto() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Limpiar Historial Persistente?'),
        content: const Text('Se eliminarán todos los registros de consultas guardadas.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Limpiar Todo'),
          ),
        ],
      ),
    );

    if (confirmar == true) {
      await _historyRepo.clearHistory();
      setState(() {
        _historial = [];
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Historial limpiado correctamente.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_cargandoFeriados) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: Color(0xFF00FF66))),
      );
    }

    final actuacionesFiltradas = LegalDatabase.actuaciones.where((a) => a.materiaId == _selectedMateria?.id).toList();
    final opcionesLetrasActuales = _obtenerOpcionesTiposLetraParaMateria(_selectedMateria);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Plazos Procesales by Weitzel.cl', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF00FF66))),
        backgroundColor: const Color(0xFF161A22),
        elevation: 4,
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Center(
              child: Text(
                FeriadosService.apiOnline ? 'API Feriados: ONLINE' : 'API Feriados: MODO OFFLINE',
                style: TextStyle(color: FeriadosService.apiOnline ? Colors.greenAccent : Colors.orangeAccent, fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
          )
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/background.jpg'),
            fit: BoxFit.cover,
            colorFilter: ColorFilter.mode(Colors.black87, BlendMode.darken),
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 1050),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // TARJETA DE FORMULARIO DE CÁLCULO
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF161A22),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF00FF66).withValues(alpha: 0.3)),
                  ),
                  padding: const EdgeInsets.all(28.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Criterios a considerar', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF00FF66))),
                      const Divider(color: Color(0xFF2E3848), height: 30),

                      const Text('1. Materia y Clasificación Normativa:'),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<MateriaSubmateria>(
                        isExpanded: true,
                        initialValue: _selectedMateria,
                        items: LegalDatabase.materias.map((m) => DropdownMenuItem(value: m, child: Text(m.displayName, style: const TextStyle(fontSize: 13)))).toList(),
                        onChanged: _onMateriaChanged,
                      ),
                      const SizedBox(height: 20),

                      const Text('2. Tipo de Actuación y Fundamento Legal:'),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<ActuacionProcesal>(
                        isExpanded: true,
                        initialValue: _selectedActuacion,
                        items: actuacionesFiltradas.map((a) => DropdownMenuItem(value: a, child: Text(a.displayName, style: const TextStyle(fontSize: 13)))).toList(),
                        onChanged: (val) => setState(() { _selectedActuacion = val; _calculado = false; }),
                      ),
                      const SizedBox(height: 20),

                      // SECCIÓN DE IDENTIFICACIÓN DE CAUSA (FILTRADA SEGÚN MATERIA)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF131720),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFF2E3848)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.gavel, color: Color(0xFF00FF66), size: 18),
                                SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    '3. Identificación de Causa (Letras correspondientes a la Materia):',
                                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: DropdownButtonFormField<String>(
                                    isExpanded: true,
                                    value: opcionesLetrasActuales.contains(_tipoLetra) ? _tipoLetra : opcionesLetrasActuales.first,
                                    decoration: const InputDecoration(labelText: 'Tipo de Causa / Letra (Materia Seleccionada)'),
                                    items: opcionesLetrasActuales.map((l) => DropdownMenuItem(value: l, child: Text(l, style: const TextStyle(fontSize: 12)))).toList(),
                                    onChanged: (val) {
                                      if (val != null) setState(() { _tipoLetra = val; _calculado = false; });
                                    },
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  flex: 2,
                                  child: TextField(
                                    controller: _rucController,
                                    decoration: const InputDecoration(labelText: 'RUC (Opcional)', hintText: '2400123456-7'),
                                    onChanged: (_) => setState(() => _calculado = false),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _numeroCausaController,
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(labelText: 'N° de Causa', hintText: 'Ej. 1234'),
                                    onChanged: (_) => setState(() => _calculado = false),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: TextField(
                                    controller: _anioCausaController,
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(labelText: 'Año Causa', hintText: '2026'),
                                    onChanged: (_) => setState(() => _calculado = false),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(color: const Color(0xFF1E2633), borderRadius: BorderRadius.circular(4)),
                              child: Row(
                                children: [
                                  const Text('Identificador Formateado: ', style: TextStyle(fontSize: 12, color: Colors.white70)),
                                  Expanded(
                                    child: SelectableText(
                                      _obtenerRolRucCompleto(),
                                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF00FF66)),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // TRIBUNAL COMPETENTE (MENÚ DESPLEGABLE DIRECTO + MODAL BÚSQUEDA)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Flexible(
                            child: Text('4. Tribunal Competente (Menú Desplegable Directo):', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                          TextButton.icon(
                            style: TextButton.styleFrom(foregroundColor: const Color(0xFF00FF66)),
                            onPressed: _abrirModalBuscadorTribunales,
                            icon: const Icon(Icons.search, size: 18),
                            label: const Text('🔍 Buscar en Catálogo', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<TribunalItem>(
                        isExpanded: true,
                        value: _selectedTribunal,
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.account_balance, color: Color(0xFF00FF66)),
                          labelText: 'Seleccionar Tribunal de Menú Desplegable',
                        ),
                        items: LegalDatabase.tribunales.map((t) {
                          return DropdownMenuItem<TribunalItem>(
                            value: t,
                            child: Text(
                              '${t.nombre} - ${t.comuna} (${t.region}) ${t.diasAumentoEmplazamiento > 0 ? "[+${t.diasAumentoEmplazamiento}d emplazamiento]" : ""}',
                              style: const TextStyle(fontSize: 13, color: Colors.white),
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() {
                              _selectedTribunal = val;
                              _calculado = false;
                            });
                          }
                        },
                      ),
                      if (_selectedTribunal != null && _selectedTribunal!.diasAumentoEmplazamiento > 0) ...[
                        const SizedBox(height: 6),
                        Text(
                          '⚡ Aumento Tabla de Emplazamiento para ${_selectedTribunal!.comuna}: +${_selectedTribunal!.diasAumentoEmplazamiento} días.',
                          style: const TextStyle(color: Colors.amber, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ],
                      const SizedBox(height: 20),

                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('5. Fecha de Notificación / Inicio del Plazo:'),
                                const SizedBox(height: 8),
                                InkWell(
                                  onTap: () async {
                                    final picked = await showDatePicker(
                                      context: context,
                                      initialDate: _fechaNotificacion,
                                      firstDate: DateTime(2020),
                                      lastDate: DateTime(2035),
                                    );
                                    if (picked != null) setState(() => _fechaNotificacion = picked);
                                  },
                                  child: InputDecorator(
                                    decoration: const InputDecoration(prefixIcon: Icon(Icons.calendar_today, color: Color(0xFF00FF66))),
                                    child: Text(
                                      '${_fechaNotificacion.day.toString().padLeft(2, '0')}/${_fechaNotificacion.month.toString().padLeft(2, '0')}/${_fechaNotificacion.year}',
                                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 30),

                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF00FF66),
                            foregroundColor: Colors.black,
                            elevation: 4,
                          ),
                          onPressed: _ejecutarCalculo,
                          icon: const Icon(Icons.calculate, size: 22),
                          label: const Text('CALCULAR Y REGISTRAR PLAZO LEGAL', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        ),
                      ),

                      if (_calculado && _fechaVencimientoFinal != null && _selectedActuacion != null && _ultimoRegistro != null) ...[
                        const SizedBox(height: 30),

                        // TARJETA DE RESULTADO
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F2B1D),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFF00FF66), width: 1.5),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('RESULTADO DEL CÁLCULO LEGAL DE PLAZO', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF00FF66), fontSize: 16)),
                                  ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF00FF66),
                                      foregroundColor: Colors.black,
                                    ),
                                    onPressed: () => PdfService.previewOrPrintSinglePdf(_ultimoRegistro!),
                                    icon: const Icon(Icons.picture_as_pdf, size: 18),
                                    label: const Text('GENERAR PDF COMPROBANTE', style: TextStyle(fontWeight: FontWeight.bold)),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text('Causa / Identificador: ${_ultimoRegistro!.rolRuc}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                              Text('Tribunal: ${_ultimoRegistro!.tribunal}', style: const TextStyle(color: Colors.white70)),
                              Text('Plazo Base: ${_selectedActuacion!.diasBase} días | Aumento Tabla: ${_ultimoRegistro!.additionalDays} días', style: const TextStyle(color: Colors.white70)),
                              const Divider(color: Color(0xFF00FF66), height: 20),
                              const Text('FECHA MÁXIMA DE PRESENTACIÓN / VENCIMIENTO:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.amber)),
                              SelectableText('${formatFechaEspanol(_fechaVencimientoFinal!)} a las 23:59:59 hrs.', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF00FF66))),
                            ],
                          ),
                        ),

                        const SizedBox(height: 20),

                        // CHECKLIST RECOMENDADO
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E2633),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFF4A5568)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                children: [
                                  Icon(Icons.fact_check, color: Colors.amber),
                                  SizedBox(width: 8),
                                  Text(
                                    'Elementos Adicionales a Considerar (Checklist Legal):',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.amber,
                                      fontSize: 15,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              ..._selectedActuacion!.elementosAConsiderar.map((item) {
                                return Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('• ', style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
                                      Expanded(
                                        child: Text(
                                          item,
                                          style: const TextStyle(fontSize: 13, color: Colors.white70),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 35),

                // SECCIÓN DE TABLA PERSISTENTE DE CONSULTAS
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF161A22),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF2E3848)),
                  ),
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.table_chart, color: Color(0xFF00FF66)),
                              const SizedBox(width: 10),
                              Text(
                                'Historial Persistente de Consultas Realizadas (${_historial.length})',
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF00FF66)),
                              ),
                            ],
                          ),
                          Wrap(
                            spacing: 10,
                            children: [
                              if (_historial.isNotEmpty) ...[
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF1A365D),
                                    foregroundColor: Colors.white,
                                  ),
                                  onPressed: () => PdfService.previewOrPrintHistoryTablePdf(_historial),
                                  icon: const Icon(Icons.picture_as_pdf, size: 16),
                                  label: const Text('EXPORTAR TABLA A PDF'),
                                ),
                                OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.redAccent,
                                    side: const BorderSide(color: Colors.redAccent),
                                  ),
                                  onPressed: _limpiarHistorialCompleto,
                                  icon: const Icon(Icons.delete_sweep, size: 16),
                                  label: const Text('Limpiar Historial'),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                      const Divider(color: Color(0xFF2E3848), height: 25),

                      if (_historial.isEmpty) ...[
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 30),
                          child: Center(
                            child: Text(
                              'Aún no hay consultas registradas. Realice un cálculo para guardarlo automáticamente.',
                              style: TextStyle(color: Colors.white54, fontStyle: FontStyle.italic),
                            ),
                          ),
                        ),
                      ] else ...[
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            headingRowColor: WidgetStateProperty.all(const Color(0xFF1C222D)),
                            columns: const [
                              DataColumn(label: Text('N°', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF00FF66)))),
                              DataColumn(label: Text('Fecha Consulta', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF00FF66)))),
                              DataColumn(label: Text('Rol / RUC / RIT', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF00FF66)))),
                              DataColumn(label: Text('Tribunal', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF00FF66)))),
                              DataColumn(label: Text('Actuación Procesal', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF00FF66)))),
                              DataColumn(label: Text('Notificación', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF00FF66)))),
                              DataColumn(label: Text('Plazo Total', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF00FF66)))),
                              DataColumn(label: Text('Vencimiento', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF00FF66)))),
                              DataColumn(label: Text('Acciones', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF00FF66)))),
                            ],
                            rows: List<DataRow>.generate(_historial.length, (index) {
                              final record = _historial[index];
                              final fechaFormat = DateFormat('dd/MM/yyyy HH:mm', 'es');
                              final notiFormat = DateFormat('dd/MM/yyyy', 'es');
                              final vencFormat = DateFormat('dd/MM/yyyy', 'es');

                              return DataRow(
                                cells: [
                                  DataCell(Text((index + 1).toString())),
                                  DataCell(Text(fechaFormat.format(record.consultationDate), style: const TextStyle(fontSize: 12))),
                                  DataCell(Text(record.rolRuc ?? '-', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.amber))),
                                  DataCell(Text(record.tribunal ?? '-', style: const TextStyle(fontSize: 12))),
                                  DataCell(Text(record.actuacionNombre ?? record.title, style: const TextStyle(fontSize: 12))),
                                  DataCell(Text(notiFormat.format(record.startDate), style: const TextStyle(fontSize: 12))),
                                  DataCell(Text('${record.baseDays}${record.additionalDays > 0 ? " + ${record.additionalDays}d" : ""}d', style: const TextStyle(fontSize: 12))),
                                  DataCell(Text(vencFormat.format(record.endDate), style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF00FF66)))),
                                  DataCell(
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.picture_as_pdf, color: Color(0xFF00FF66), size: 18),
                                          tooltip: 'Exportar PDF de esta consulta',
                                          onPressed: () => PdfService.previewOrPrintSinglePdf(record),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 18),
                                          tooltip: 'Eliminar del historial',
                                          onPressed: () => _eliminarRegistroHistorial(record.id),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              );
                            }),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
}


