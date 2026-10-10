# Plazos Procesales Chile [Sistema Profesional Weitzel.cl]

Aplicación profesional web, móvil y de escritorio desarrollada en Flutter para el cálculo automatizado de plazos procesales en el **Ordenamiento Jurídico Chileno**, contemplando feriados legales actualizados (API Feriados Chile y fallback offline), tabla de aumento por emplazamiento de tribunales nacionales, identificación de causas por tipo de letras, persistencia de historial de consultas y exportación de comprobantes e informes en formato **PDF**.

Cada cálculo se muestra en pantalla y se guarda en el historial local del navegador. Desde el resultado o desde cada fila del historial se puede descargar un comprobante PDF con los datos de causa, tribunal, materia, actuación, fundamento normativo, cómputo, vencimiento y checklist; también se puede descargar el resumen del historial.

---

## 🏛️ Cobertura Integral del Ecosistema Jurídico Chileno

<details class="accordion-item" open>
  <summary class="accordion-header">💼 a. Derecho Laboral y Previsional</summary>
  <div class="accordion-body">
    <p>Acciones orientadas a resolver conflictos individuales y de seguridad social bajo el marco del Código del Trabajo:</p>
    <ul>
      <li><strong>Despido Injustificado, Indebido, Improcedente y Ley Bustos:</strong> Vía para impugnar la causal de despido y exigir indemnizaciones incrementadas, además de la nulidad del despido por deudas en cotizaciones previsionales (Arts. 162, 168 y 446 del Código del Trabajo).</li>
      <li><strong>Tutela Laboral y Derechos Fundamentales:</strong> Procedimiento de urgencia ante la vulneración de derechos fundamentales acaecida durante la relación laboral o con ocasión del despido (Arts. 485 a 495 del Código del Trabajo).</li>
      <li><strong>Procedimiento Monitorio y Cobranza Laboral:</strong> Reclamos de hasta 10 UTM, cobro de finiquitos, títulos ejecutivos y multas de la Dirección del Trabajo (Arts. 463, 496 y 503 del Código del Trabajo y Ley N° 20.022).</li>
    </ul>
  </div>
</details>

<details class="accordion-item">
  <summary class="accordion-header">⚖️ b. Derecho Procesal Civil</summary>
  <div class="accordion-body">
    <p>Mecanismos judiciales ordinarios y de ejecución patrimonial normados por el Código de Procedimiento Civil (CPC):</p>
    <ul>
      <li><strong>Juicio Ordinario y Sumario Civil:</strong> Vías de lato conocimiento para demandas, contestaciones, excepciones, réplicas, dúplicas y recursos civiles (Código de Procedimiento Civil - Arts. 253 y ss.).</li>
      <li><strong>Juicio Ejecutivo y Embargos:</strong> Procedimientos de apremio basados en títulos ejecutivos para el mandamiento de ejecución, oposición de excepciones y réplica ejecutiva (Código de Procedimiento Civil - Arts. 434 a 529).</li>
      <li><strong>Arrendamiento de Predios Urbanos y Precario:</strong> Acciones especiales amparadas en la Ley Devuélveme Mi Casa, cobro de rentas y acción de precario (Ley N° 18.101, Ley N° 21.461 y Art. 2195 del Código Civil).</li>
    </ul>
  </div>
</details>

<details class="accordion-item">
  <summary class="accordion-header">👨‍👩‍👧‍👦 c. Derecho de Familia</summary>
  <div class="accordion-body">
    <p>Acciones de protección y regulación del núcleo familiar radicadas en los Tribunales de Familia:</p>
    <ul>
      <li><strong>Pensión de Alimentos y Cumplimiento:</strong> Demanda para la fijación, aumento, rebaja, cese de alimentos y articulación con el Registro de Deudores (Ley N° 14.908, Ley N° 21.389 y Ley N° 19.968).</li>
      <li><strong>Cuidado Personal, Visitas, Divorcio y Compensación:</strong> Tuición, relación directa y regular, divorcio (unilateral o de mutuo acuerdo) y compensación económica (Ley N° 19.947 y Código Civil).</li>
      <li><strong>Violencia Intrafamiliar, Protección NNA y Filiación:</strong> Solicitud de medidas cautelares VIF, medidas de protección para Niños, Niñas y Adolescentes (NNA) y juicios de paternidad/filiación (Ley N° 20.066, Ley N° 19.968 y Arts. 179 y ss. del CC).</li>
    </ul>
  </div>
</details>

<details class="accordion-item">
  <summary class="accordion-header">🔒 d. Derecho Procesal Penal</summary>
  <div class="accordion-body">
    <p>Persecución criminal y garantías de los intervinientes bajo el marco del Código Procesal Penal (CPP):</p>
    <ul>
      <li><strong>Procedimiento Penal y Recursos:</strong> Tramitación de causas a través de juicio oral, tribunales de garantía, procedimiento simplificado, procedimiento abreviado, además de recursos de amparo y nulidad penal (Código Procesal Penal - Arts. 95, 366, 372).</li>
    </ul>
  </div>
</details>

<details class="accordion-item">
  <summary class="accordion-header">🏦 e. Derecho Tributario y Aduanero</summary>
  <div class="accordion-body">
    <p>Litigación contencioso-administrativa fiscal ante los Tribunales Tributarios y Aduaneros (TTA) y organismos fiscalizadores:</p>
    <ul>
      <li><strong>Reclamaciones TTA y SII:</strong> Reclamación tributaria contra liquidaciones o giros (SII/TTA) y recursos de reposición administrativa (RAF/RAV) (Código Tributario DL. N° 830 y Ordenanza de Aduanas).</li>
    </ul>
  </div>
</details>

<details class="accordion-item">
  <summary class="accordion-header">🚓 f. Juzgados de Policía Local (JPL)</summary>
  <div class="accordion-body">
    <p>Competentes en materias de contravenciones menores, convivencia urbana y normativa de consumo:</p>
    <ul>
      <li><strong>Tránsito, Consumidor y Copropiedad Inmobiliaria:</strong> Infracciones y accidentes de tránsito, reclamos de la Ley de Protección de los Consumidores (LPDC) y conflictos de copropiedad (Ley N° 18.287, Ley N° 18.290, Ley N° 19.496 y Ley N° 21.442).</li>
    </ul>
  </div>
</details>

<details class="accordion-item">
  <summary class="accordion-header">🏛️ g. Derecho Constitucional y Administrativo</summary>
  <div class="accordion-body">
    <p>Mecanismos de alta tutela de derechos fundamentales y control de juridicidad del Estado:</p>
    <ul>
      <li><strong>Acciones Constitucionales y Procedimiento Administrativo:</strong> Interposición de Recurso de Protección, Recurso de Amparo, Reclamos de Ilegalidad y procedimientos de la Ley N° 19.880 (Constitución Política Arts. 20, 21, Ley N° 19.880 y Ley N° 18.695).</li>
      <li><strong>Justicia Constitucional (TC):</strong> Solicitudes de inaplicabilidad e inconstitucionalidad de preceptos legales ante el Tribunal Constitucional (Constitución Art. 93 y Ley N° 17.997).</li>
    </ul>
  </div>
</details>

---

## 🚀 Despliegue de la Web App en Vivo
- **URL Pública:** [https://ferweitzel.github.io/procesal-plazos-chile/](https://ferweitzel.github.io/procesal-plazos-chile/)
- **Desarrollado por:** Weitzel.cl
