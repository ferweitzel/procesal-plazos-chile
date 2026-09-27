enum TipoComputo {
  judicial,
  administrativo,
  corridos,
}

enum Materia {
  civil,
  penal,
  laboral,
  familia,
  policiaLocal,
  constitucional,
  tributario,
  aduanero,
  sii,
  tgr,
  contraloria,
  inapi,
  otro,
}

class ActuacionNorma {
  final String nombre;
  final String codigo;
  final String articulo;
  final String plazoDescripcion;

  ActuacionNorma(this.nombre, this.codigo, this.articulo, this.plazoDescripcion);
}

enum TipoActuacion {
  // Civil
  contestacionDemanda,
  excepcionesEjecutivo,
  juicioSumario,
  trasladoComun,
  trasladoReplicaDuplica,
  recursoReposicion,
  recursoApelacion,
  recursoCasacion,
  // Penal
  querellaPenal,
  recursoAmparo,
  // Constitucional
  recursoProteccion,
  // Tributario/Aduanero
  reposicionAdministrativa,
  reclamacionTributaria,
  // Otros
  otro;

  ActuacionNorma get informacion {
    switch (this) {
      case TipoActuacion.contestacionDemanda:
        return ActuacionNorma("Contestación Demanda", "CPC", "Art. 258", "18 días (aumentado tabla)");
      case TipoActuacion.recursoApelacion:
        return ActuacionNorma("Recurso de Apelación", "CPC", "Art. 189", "5 días");
      case TipoActuacion.recursoCasacion:
        return ActuacionNorma("Recurso de Casación", "CPC", "Art. 770", "15 días fondo / 5 días forma");
      case TipoActuacion.querellaPenal:
        return ActuacionNorma("Querella Penal", "CPP", "Art. 111", "Durante toda la etapa de investigación");
      case TipoActuacion.recursoAmparo:
        return ActuacionNorma("Recurso de Amparo", "CPP", "Art. 95", "Sin plazo, durante la privación de libertad");
      case TipoActuacion.recursoProteccion:
        return ActuacionNorma("Recurso de Protección", "Constitución", "Art. 20", "30 días corridos");
      case TipoActuacion.reposicionAdministrativa:
        return ActuacionNorma("Reposición Administrativa", "Código Tributario", "Art. 123", "5 días");
      case TipoActuacion.reclamacionTributaria:
        return ActuacionNorma("Reclamación Tributaria", "Código Tributario", "Art. 124", "90 días");
      default:
        return ActuacionNorma("Otro", "N/A", "N/A", "Definido por el usuario");
    }
  }
}
