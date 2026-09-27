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
    // a. DERECHO PÚBLICO
    MateriaSubmateria(id: 'pub_const', granGrupo: 'a. Derecho Público', rama: 'Derecho Constitucional', submateria: 'Acciones Constitucionales y Recursos (Corte de Apelaciones y Corte Suprema)', normativa: 'Constitución Política de la República (Arts. 20, 21) y Autos Acordados CS'),
    MateriaSubmateria(id: 'pub_tc', granGrupo: 'a. Derecho Público', rama: 'Justicia Constitucional', submateria: 'Tribunal Constitucional (Inaplicabilidad, Inconstitucionalidad y Controles)', normativa: 'Constitución (Art. 93) y Ley N° 17.997 (LOC del TC)'),
    MateriaSubmateria(id: 'pub_admin', granGrupo: 'a. Derecho Público', rama: 'Derecho Administrativo', submateria: 'Procedimiento, Reclamos y Contraloría', normativa: 'Ley N° 19.880 y Ley N° 10.336 (Orgánica CGR)'),
    MateriaSubmateria(id: 'pub_penal', granGrupo: 'a. Derecho Público', rama: 'Derecho Procesal Penal', submateria: 'Investigación, Garantía, Juicio Oral y Recursos', normativa: 'Código Procesal Penal (CPP) y Código Penal'),
    MateriaSubmateria(id: 'pub_trib', granGrupo: 'a. Derecho Público', rama: 'Derecho Tributario y Aduanero', submateria: 'Reclamaciones TTA, SII, TGR y Aduanas', normativa: 'Código Tributario (DL 830), Ordenanza de Aduanas, Ley Orgánica TTA'),

    // b. DERECHO PRIVADO
    MateriaSubmateria(id: 'priv_civ_ord', granGrupo: 'b. Derecho Privado', rama: 'Derecho Procesal Civil', submateria: 'Juicio Ordinario, Incidentes y Medidas Precautorias', normativa: 'Código de Procedimiento Civil (CPC)'),
    MateriaSubmateria(id: 'priv_civ_ejec', granGrupo: 'b. Derecho Privado', rama: 'Derecho Procesal Civil', submateria: 'Juicio Ejecutivo y Apremios', normativa: 'Código de Procedimiento Civil (CPC) y Ley N° 21.394'),
    MateriaSubmateria(id: 'priv_civ_esp', granGrupo: 'b. Derecho Privado', rama: 'Derecho Procesal Civil', submateria: 'Juicios Sumarios, Arbitrales y Juicios de Hacienda', normativa: 'Código de Procedimiento Civil (CPC)'),
    MateriaSubmateria(id: 'priv_com_conc', granGrupo: 'b. Derecho Privado', rama: 'Derecho Comercial y Concursal', submateria: 'Procedimientos Concursales de Reorganización y Liquidación', normativa: 'Ley N° 20.720 y Código de Comercio'),

    // c. RAMAS MIXTAS, ESPECIALES Y TRANSVERSALES
    MateriaSubmateria(id: 'mix_lab', granGrupo: 'c. Ramas Mixtas', rama: 'Derecho del Trabajo y Seguridad Social', submateria: 'Juicio Ordinario Laboral, Tutela y Monitorio', normativa: 'Código del Trabajo (CT) y Leyes Especiales'),
    MateriaSubmateria(id: 'mix_fam', granGrupo: 'c. Ramas Mixtas', rama: 'Derecho de Familia', submateria: 'Alimentos, Divorcio, Violencia Intrafamiliar y Cuidado Personal', normativa: 'Ley N° 19.968 (Tribunales de Familia) y CC'),
    MateriaSubmateria(id: 'mix_pol_loc', granGrupo: 'c. Ramas Mixtas', rama: 'Policía Local y Tránsito', submateria: 'Infracciones de Tránsito, Ley de Copropiedad y Ordenanzas', normativa: 'Ley N° 18.287 (JPL) y Ley N° 21.442'),
    MateriaSubmateria(id: 'mix_inapi', granGrupo: 'c. Ramas Mixtas', rama: 'Propiedad Industrial e Intelectual', submateria: 'Marcas, Patentes y Oposiciones ante INAPI y TDPI', normativa: 'Ley N° 19.039 y Ley N° 17.336'),
  ];

  static final List<ActuacionProcesal> actuaciones = [
    // ==========================================
    // 1. DERECHO PROCESAL CIVIL (ORDINARIO Y RECURSOS)
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
      nombreActuacion: 'Contestación de la Demanda Ordinaria', rolProcesal: 'Demandado',
      tipoInstitucion: 'Defensa de Fondo / Reconvención', articuloYNorma: 'Art. 258 CPC',
      diasBase: 18, tipoComputo: TipoComputoDias.habilesCivil, admiteEmplazamiento: true,
      elementosAConsiderar: ['Aumento por tabla de emplazamiento según distancia', 'Oportunidad para entablar demanda reconvencional']
    ),
    ActuacionProcesal(
      id: 'civ_replica', materiaId: 'priv_civ_ord',
      nombreActuacion: 'Réplica', rolProcesal: 'Demandante',
      tipoInstitucion: 'Alegación', articuloYNorma: 'Art. 311 CPC',
      diasBase: 6, tipoComputo: TipoComputoDias.habilesCivil, admiteEmplazamiento: false,
      elementosAConsiderar: ['Ampliación o modificación de peticiones sin alterar la acción deducida en la demanda']
    ),
    ActuacionProcesal(
      id: 'civ_duplica', materiaId: 'priv_civ_ord',
      nombreActuacion: 'Dúplica', rolProcesal: 'Demandado',
      tipoInstitucion: 'Alegación', articuloYNorma: 'Art. 312 CPC',
      diasBase: 6, tipoComputo: TipoComputoDias.habilesCivil, admiteEmplazamiento: false,
      elementosAConsiderar: ['Última oportunidad de alegación escrita antes de la fase de prueba o citación a oír sentencia']
    ),
    ActuacionProcesal(
      id: 'civ_incidente', materiaId: 'priv_civ_ord',
      nombreActuacion: 'Respuesta / Contestación de Incidente', rolProcesal: 'Parte Contueta',
      tipoInstitucion: 'Incidente Ordinario', articuloYNorma: 'Art. 89 y 327 CPC',
      diasBase: 3, tipoComputo: TipoComputoDias.habilesCivil, admiteEmplazamiento: false,
      elementosAConsiderar: ['Plazo fatal para responder incidentes promovidos en el curso del juicio']
    ),
    ActuacionProcesal(
      id: 'civ_repo', materiaId: 'priv_civ_ord',
      nombreActuacion: 'Recurso de Reposición (Contra Autos y Decretos)', rolProcesal: 'Agraviado',
      tipoInstitucion: 'Recurso Ordinario', articuloYNorma: 'Art. 181 CPC',
      diasBase: 3, tipoComputo: TipoComputoDias.habilesCivil, admiteEmplazamiento: false,
      elementosAConsiderar: ['Debe interponerse por escrito con fundamentos claros y precisos']
    ),
    ActuacionProcesal(
      id: 'civ_repo_apel', materiaId: 'priv_civ_ord',
      nombreActuacion: 'Reposición con Apelación en Subsidio', rolProcesal: 'Agraviado',
      tipoInstitucion: 'Recurso Ordinario', articuloYNorma: 'Art. 188 CPC',
      diasBase: 3, tipoComputo: TipoComputoDias.habilesCivil, admiteEmplazamiento: false,
      elementosAConsiderar: ['Se pide la revocación al mismo tribunal y, para el caso de negativa, se alza la apelación']
    ),
    ActuacionProcesal(
      id: 'civ_apelacion_def', materiaId: 'priv_civ_ord',
      nombreActuacion: 'Apelación contra Sentencia Definitiva', rolProcesal: 'Agraviado',
      tipoInstitucion: 'Recurso Ordinario de Alzada', articuloYNorma: 'Art. 189 CPC',
      diasBase: 10, tipoComputo: TipoComputoDias.habilesCivil, admiteEmplazamiento: false,
      elementosAConsiderar: ['Fundamentos de hecho y derecho', 'Peticiones concretas exigidas por la Ley N° 20.886 / autos acordados']
    ),
    ActuacionProcesal(
      id: 'civ_apelacion_inter', materiaId: 'priv_civ_ord',
      nombreActuacion: 'Apelación contra Sentencia Interlocutoria', rolProcesal: 'Agraviado',
      tipoInstitucion: 'Recurso Ordinario de Alzada', articuloYNorma: 'Art. 189 CPC',
      diasBase: 5, tipoComputo: TipoComputoDias.habilesCivil, admiteEmplazamiento: false,
      elementosAConsiderar: ['Procede contra interlocutorias que pongan término al juicio o hagan imposible su continuación']
    ),
    ActuacionProcesal(
      id: 'civ_casacion_forma', materiaId: 'priv_civ_ord',
      nombreActuacion: 'Recurso de Casación en la Forma', rolProcesal: 'Agraviado',
      tipoInstitucion: 'Recurso Extraordinario', articuloYNorma: 'Art. 770 inc. 1° CPC',
      diasBase: 15, tipoComputo: TipoComputoDias.habilesCivil, admiteEmplazamiento: false,
      elementosAConsiderar: ['Requiere preparación previa del recurso en las instancias previas (salvo excepciones legales)']
    ),
    ActuacionProcesal(
      id: 'civ_casacion_fondo', materiaId: 'priv_civ_ord',
      nombreActuacion: 'Recurso de Casación en el Fondo', rolProcesal: 'Agraviado',
      tipoInstitucion: 'Recurso Extraordinario', articuloYNorma: 'Art. 770 inc. 2° CPC',
      diasBase: 15, tipoComputo: TipoComputoDias.habilesCivil, admiteEmplazamiento: false,
      elementosAConsiderar: ['Infracción de ley con influencia sustancial en lo dispositivo de la sentencia', 'Patrocinio especial Corte Suprema']
    ),
    ActuacionProcesal(
      id: 'civ_queja', materiaId: 'priv_civ_ord',
      nombreActuacion: 'Recurso de Queja (Contra Falta o Abuso Grave)', rolProcesal: 'Agraviado',
      tipoInstitucion: 'Recurso Disciplinario Extraordinario', articuloYNorma: 'Art. 548 COT',
      diasBase: 5, tipoComputo: TipoComputoDias.habilesCivil, admiteEmplazamiento: false,
      elementosAConsiderar: ['Plazo fatal de 5 días hábiles desde la notificación, ampliable hasta 15 días si es fuera del territorio jurisdiccional de la Corte Suprema']
    ),

    // ==========================================
    // 2. JUICIO EJECUTIVO Y APREMIOS
    // ==========================================
    ActuacionProcesal(
      id: 'ejec_opone', materiaId: 'priv_civ_ejec',
      nombreActuacion: 'Oposición a la Ejecución (Excepciones Legales)', rolProcesal: 'Ejecutado',
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

    // ==========================================
    // 3. DERECHO PROCESAL PENAL (CPP)
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
      nombreActuacion: 'Reposición Oral en Audiencia', rolProcesal: 'Interviniente',
      tipoInstitucion: 'Recurso Inmediato', articuloYNorma: 'Art. 362 CPP',
      diasBase: 0, tipoComputo: TipoComputoDias.corridos, admiteEmplazamiento: false,
      elementosAConsiderar: ['Se interpone y resuelve de forma verbal e inmediata en la misma audiencia']
    ),
    ActuacionProcesal(
      id: 'penal_repo_escrito', materiaId: 'pub_penal',
      nombreActuacion: 'Reposición por Escrito (Fuera de Audiencia)', rolProcesal: 'Interviniente',
      tipoInstitucion: 'Recurso Ordinario Penal', articuloYNorma: 'Art. 362 CPP',
      diasBase: 3, tipoComputo: TipoComputoDias.corridos, admiteEmplazamiento: false,
      elementosAConsiderar: ['Contra resoluciones dictadas sin citación o en trámites que no admiten debate oral previo']
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
    // 4. DERECHO CONSTITUCIONAL Y ACCIONES (CORTE APELACIONES Y SUPREMA)
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
      id: 'const_amparo_econ', materiaId: 'pub_const',
      nombreActuacion: 'Recurso de Amparo Económico', rolProcesal: 'Recurrente (Acción Pública)',
      tipoInstitucion: 'Acción Constitucional Económica', articuloYNorma: 'Ley N° 18.971 y Art. 19 N° 21 CPR',
      diasBase: 180, tipoComputo: TipoComputoDias.corridos, admiteEmplazamiento: false,
      elementosAConsiderar: ['Plazo de 6 meses corridos desde la infracción o amenaza a la libertad económica']
    ),
    ActuacionProcesal(
      id: 'const_expropiacion', materiaId: 'pub_const',
      nombreActuacion: 'Reclamación por Expropiación', rolProcesal: 'Expropiado / Reclamante',
      tipoInstitucion: 'Reclamo Expropiatorio', articuloYNorma: 'Art. 19 N° 24 CPR y DL N° 2.186',
      diasBase: 30, tipoComputo: TipoComputoDias.corridos, admiteEmplazamiento: false,
      elementosAConsiderar: ['30 días corridos desde la publicación del acto expropiatorio en el Diario Oficial']
    ),
    ActuacionProcesal(
      id: 'const_apelacion_prot', materiaId: 'pub_const',
      nombreActuacion: 'Apelación contra Sentencia de Protección (Corte Suprema)', rolProcesal: 'Apelante / Agraviado',
      tipoInstitucion: 'Recurso de Segunda Instancia', articuloYNorma: 'Auto Acordado CS sobre Protección',
      diasBase: 5, tipoComputo: TipoComputoDias.habilesCivil, admiteEmplazamiento: false,
      elementosAConsiderar: ['5 días hábiles desde la notificación del fallo de la Corte de Apelaciones (Conoce la Tercera Sala CS)']
    ),
    ActuacionProcesal(
      id: 'const_apelacion_amparo', materiaId: 'pub_const',
      nombreActuacion: 'Apelación contra Sentencia de Amparo (Corte Suprema)', rolProcesal: 'Apelante',
      tipoInstitucion: 'Recurso de Segunda Instancia Penal', articuloYNorma: 'Art. 21 CPR',
      diasBase: 1, tipoComputo: TipoComputoDias.corridos, admiteEmplazamiento: false,
      elementosAConsiderar: ['24 horas fatales desde la notificación de la sentencia de primera instancia (Conoce la Segunda Sala CS)']
    ),
    ActuacionProcesal(
      id: 'const_nacionalidad', materiaId: 'pub_const',
      nombreActuacion: 'Reclamo por Desconocimiento de Nacionalidad Chilena', rolProcesal: 'Reclamante',
      tipoInstitucion: 'Acción Constitucional de Nacionalidad', articuloYNorma: 'Art. 12 CPR',
      diasBase: 54, tipoComputo: TipoComputoDias.habilesCivil, admiteEmplazamiento: false,
      elementosAConsiderar: ['54 días hábiles procesales desde el acto u omisión gubernamental (Conoce el Pleno de la Corte Suprema)']
    ),
    ActuacionProcesal(
      id: 'const_error_judicial', materiaId: 'pub_const',
      nombreActuacion: 'Acción de Indemnización por Error Judicial', rolProcesal: 'Demandante / Absuelto',
      tipoInstitucion: 'Demanda Patrimonial contra el Fisco', articuloYNorma: 'Art. 19 N° 7 letra i CPR',
      diasBase: 180, tipoComputo: TipoComputoDias.corridos, admiteEmplazamiento: false,
      elementosAConsiderar: ['6 meses corridos desde que quede firme la sentencia penal absolutoria o de sobreseimiento definitivo (Conoce el Pleno CS)']
    ),

    // ==========================================
    // 5. TRIBUNAL CONSTITUCIONAL (TC - LEY N° 17.997)
    // ==========================================
    ActuacionProcesal(
      id: 'tc_ina', materiaId: 'pub_tc',
      nombreActuacion: 'Requerimiento de Inaplicabilidad por Inconstitucionalidad (INA)', rolProcesal: 'Requeriente (Parte / Juez)',
      tipoInstitucion: 'Control Concreto de Constitucionalidad', articuloYNorma: 'Art. 93 N° 6 CPR y Art. 79 Ley N° 17.997',
      diasBase: 0, tipoComputo: TipoComputoDias.corridos, admiteEmplazamiento: false,
      elementosAConsiderar: ['En cualquier estado de la gestión judicial pendiente', 'Permite solicitar suspensión del procedimiento de origen']
    ),
    ActuacionProcesal(
      id: 'tc_inc', materiaId: 'pub_tc',
      nombreActuacion: 'Acción de Inconstitucionalidad de Precepto Legal (INC)', rolProcesal: 'Requeriente / Ciudadano',
      tipoInstitucion: 'Control Abstracto de Constitucionalidad', articuloYNorma: 'Art. 93 N° 7 CPR y Art. 93 Ley N° 17.997',
      diasBase: 0, tipoComputo: TipoComputoDias.corridos, admiteEmplazamiento: false,
      elementosAConsiderar: ['Requiere sentencia previa de inaplicabilidad dictada por el TC', 'Efecto derogatorio erga omnes si se acoge por 4/5 partes']
    ),
    ActuacionProcesal(
      id: 'tc_autos_acordados', materiaId: 'pub_tc',
      nombreActuacion: 'Inconstitucionalidad de Autos Acordados', rolProcesal: 'Requeriente (Autoridades Legales)',
      tipoInstitucion: 'Control Normativo', articuloYNorma: 'Art. 93 N° 2 CPR y Art. 63 Ley N° 17.997',
      diasBase: 30, tipoComputo: TipoComputoDias.corridos, admiteEmplazamiento: false,
      elementosAConsiderar: ['30 días corridos desde la publicación del Auto Acordado de la Corte Suprema, Cortes o TRICEL']
    ),
    ActuacionProcesal(
      id: 'tc_contienda', materiaId: 'pub_tc',
      nombreActuacion: 'Requerimiento por Contienda de Competencia', rolProcesal: 'Órgano Requirente',
      tipoInstitucion: 'Conflicto de Competencia', articuloYNorma: 'Art. 93 N° 12 CPR y Art. 108 Ley N° 17.997',
      diasBase: 10, tipoComputo: TipoComputoDias.habilesCivil, admiteEmplazamiento: false,
      elementosAConsiderar: ['10 días hábiles desde que la autoridad requerida afirmare su competencia o desconociere la del requirente']
    ),


    // ==========================================
    // 5. DERECHO ADMINISTRATIVO Y LEY 19.880
    // ==========================================
    ActuacionProcesal(
      id: 'admin_reposicion', materiaId: 'pub_admin',
      nombreActuacion: 'Recurso de Reposición Administrativa', rolProcesal: 'Interesado',
      tipoInstitucion: 'Impugnación Administrativa', articuloYNorma: 'Art. 59 Ley N° 19.880',
      diasBase: 5, tipoComputo: TipoComputoDias.habilesAdmin, admiteEmplazamiento: false,
      elementosAConsiderar: ['Cómputo en días hábiles administrativos (Lunes a Viernes, excluyendo festivos)', 'Apelación jerárquica en subsidio']
    ),
    ActuacionProcesal(
      id: 'admin_reclamo_ilegalidad', materiaId: 'pub_admin',
      nombreActuacion: 'Reclamo de Ilegalidad Municipal / Servicios', rolProcesal: 'Afectado',
      tipoInstitucion: 'Contencioso Administrativo', articuloYNorma: 'Art. 151 Ley N° 18.695 (Orgánica de Municipalidades)',
      diasBase: 15, tipoComputo: TipoComputoDias.habilesCivil, admiteEmplazamiento: false,
      elementosAConsiderar: ['Contra decretos alcaldicios o resoluciones ante la Corte de Apelaciones respectiva']
    ),

    // ==========================================
    // 6. DERECHO TRIBUTARIO Y ADUANERO (TTA / SII)
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
    // 7. DERECHO DEL TRABAJO
    // ==========================================
    ActuacionProcesal(
      id: 'lab_contestacion', materiaId: 'mix_lab',
      nombreActuacion: 'Contestación de Demanda Laboral (Juicio Ordinario)', rolProcesal: 'Demandado (Empleador)',
      tipoInstitucion: 'Defensa Laboral', articuloYNorma: 'Art. 452 y 453 Código del Trabajo',
      diasBase: 5, tipoComputo: TipoComputoDias.habilesLaboral, admiteEmplazamiento: false,
      elementosAConsiderar: ['Debe presentarse por escrito hasta 5 días antes de la audiencia preparatoria (o contarse según reglas del tribunal)']
    ),
    ActuacionProcesal(
      id: 'lab_nulidad', materiaId: 'mix_lab',
      nombreActuacion: 'Recurso de Nulidad Laboral', rolProcesal: 'Agraviado',
      tipoInstitucion: 'Recurso Laboral Extraordinario', articuloYNorma: 'Art. 477 Código del Trabajo',
      diasBase: 10, tipoComputo: TipoComputoDias.habilesLaboral, admiteEmplazamiento: false,
      elementosAConsiderar: ['Infracción de ley con influencia sustancial en lo dispositivo del fallo o vulneración de garantías']
    ),

    // ==========================================
    // 8. DERECHO DE FAMILIA
    // ==========================================
    ActuacionProcesal(
      id: 'fam_contestacion', materiaId: 'mix_fam',
      nombreActuacion: 'Contestación de Demanda de Familia', rolProcesal: 'Demandado',
      tipoInstitucion: 'Defensa de Familia', articuloYNorma: 'Art. 59 Ley N° 19.968',
      diasBase: 5, tipoComputo: TipoComputoDias.habilesCivil, admiteEmplazamiento: false,
      elementosAConsiderar: ['Por escrito hasta 5 días antes de la audiencia preparatoria o comparecencia directa en audiencia según el procedimiento']
    ),
    ActuacionProcesal(
      id: 'fam_apelacion', materiaId: 'mix_fam',
      nombreActuacion: 'Recurso de Apelación en Juicios de Familia', rolProcesal: 'Agraviado',
      tipoInstitucion: 'Recurso de Alzada de Familia', articuloYNorma: 'Art. 67 Ley N° 19.968',
      diasBase: 5, tipoComputo: TipoComputoDias.habilesCivil, admiteEmplazamiento: false,
      elementosAConsiderar: ['Se interpone por escrito ante el juez de familia dentro de 5 días desde la notificación de la sentencia definitiva o resolución que pone término al juicio']
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
  String _tipoLetra = 'Rol C (Ordinario Civil)';
  final TextEditingController _numeroCausaController = TextEditingController();
  final TextEditingController _anioCausaController = TextEditingController(text: DateTime.now().year.toString());
  final TextEditingController _rucController = TextEditingController();

  final List<String> _opcionesTiposLetra = [
    'Rol C (Ordinario Civil)',
    'Rol V (Voluntario Civil)',
    'Rol E (Exequátur / Especial Civil)',
    'Rol J (Ejecutivo Civil)',
    'RIT O (Ordinario Penal / Laboral)',
    'RIT P (Simplificado Penal / Monitorio Laboral)',
    'RIT I (Investigación Garantía Penal)',
    'RIT F (Familia Alimentos / Ordinario)',
    'RIT C (Familia Cuidado Personal)',
    'RIT M (Familia Protección)',
    'RIT X (Familia Violencia Intrafamiliar)',
    'RIT Z (Familia Cumplimiento)',
    'RIT T (Tributario TTA)',
    'RIT A (Aduanero TTA)',
    'Rol JPL (Juzgado de Policía Local)',
    'Rol TC (Tribunal Constitucional)',
    'Rol Corte (Protección / Amparo / Apelación)',
    'RUC (Registro Único de Causa)',
    'Libre / Personalizado',
  ];

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
      _selectedTribunal = LegalDatabase.tribunales.first;
      _historial = historialCargado;
      _cargandoFeriados = false;
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

    if (_tipoLetra == 'RUC (Registro Único de Causa)') {
      return ruc.isNotEmpty ? 'RUC $ruc' : 'RUC Pendiente';
    }

    String baseRol = '';
    if (_tipoLetra.startsWith('Rol ')) {
      final letra = _tipoLetra.split(' ')[1];
      baseRol = num.isNotEmpty ? 'Rol $letra-$num-$anio' : 'Rol $letra-___-$anio';
    } else if (_tipoLetra.startsWith('RIT ')) {
      final letra = _tipoLetra.split(' ')[1];
      baseRol = num.isNotEmpty ? 'RIT $letra-$num-$anio' : 'RIT $letra-___-$anio';
    } else {
      baseRol = num.isNotEmpty ? '$num-$anio' : 'Sin Rol Definido';
    }

    if (ruc.isNotEmpty) {
      return 'RUC $ruc | $baseRol';
    }
    return baseRol;
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
      body: SingleChildScrollView(
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
                        onChanged: (val) => setState(() { _selectedMateria = val; _updateActuacionesList(); }),
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

                      // SECCIÓN DE IDENTIFICACIÓN DE CAUSA (ROL / RUC / RIT POR TIPO DE LETRAS)
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
                                    '3. Identificación de Causa (Rol / RUC / RIT por Letras de Materia):',
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
                                    initialValue: _tipoLetra,
                                    decoration: const InputDecoration(labelText: 'Tipo de Causa / Letra'),
                                    items: _opcionesTiposLetra.map((l) => DropdownMenuItem(value: l, child: Text(l, style: const TextStyle(fontSize: 12)))).toList(),
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

                      // BÚSQUEDA / AUTOCOMPLETADO DE TRIBUNAL COMPETENTE
                      const Text('4. Tribunal Competente (Búsqueda Completa en Red Nacional):'),
                      const SizedBox(height: 8),
                      Autocomplete<TribunalItem>(
                        initialValue: TextEditingValue(text: _selectedTribunal != null ? '${_selectedTribunal!.nombre} - ${_selectedTribunal!.comuna}' : ''),
                        displayStringForOption: (TribunalItem option) => '${option.nombre} - ${option.comuna} (${option.region})',
                        optionsBuilder: (TextEditingValue textEditingValue) {
                          if (textEditingValue.text.isEmpty) {
                            return LegalDatabase.tribunales.take(15);
                          }
                          final query = textEditingValue.text.toLowerCase();
                          return LegalDatabase.tribunales.where((t) =>
                            t.nombre.toLowerCase().contains(query) ||
                            t.comuna.toLowerCase().contains(query) ||
                            t.region.toLowerCase().contains(query)
                          );
                        },
                        onSelected: (TribunalItem selection) {
                          setState(() {
                            _selectedTribunal = selection;
                            _calculado = false;
                          });
                        },
                        fieldViewBuilder: (context, controller, focusNode, onEditingComplete) {
                          return TextField(
                            controller: controller,
                            focusNode: focusNode,
                            onEditingComplete: onEditingComplete,
                            decoration: InputDecoration(
                              prefixIcon: const Icon(Icons.account_balance, color: Color(0xFF00FF66)),
                              suffixIcon: IconButton(
                                icon: const Icon(Icons.clear, color: Colors.white54),
                                onPressed: () {
                                  controller.clear();
                                  setState(() => _selectedTribunal = null);
                                },
                              ),
                              hintText: 'Buscar por nombre, comuna o región (ej: Santiago 30 civil, TTA, JPL Las Condes...)',
                              labelText: 'Seleccionar / Buscar Tribunal',
                            ),
                          );
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
    );
  }
}

