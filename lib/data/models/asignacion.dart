class Asignacion {
  Asignacion({
    required this.id,
    required this.incidenteId,
    required this.tallerId,
    required this.estado,
    this.tecnicoId,
    this.motivoRechazo,
    this.respondidoAt,
    this.asignadoAt,
    this.incidenteReportadoAt,
    this.asignacionAutomatica,
    this.tallerNombre,
    this.incidenteEstado,
    this.incidenteDescripcion,
    this.incidenteDireccion,
    this.incidenteLatitud,
    this.incidenteLongitud,
    this.incidentePrioridad,
    this.incidenteResumenIa,
    this.distanciaKm,
    this.tiempoLlegadaMin,
    this.precioSugerido,
    this.dificultad,
    this.precioMin,
    this.precioMax,
    this.tiempoTotalMin,
    this.comisionPlataforma,
    this.montoTaller,
    this.cotizacionId,
    this.precioOfertado,
    this.tiempoOfertadoMin,
    this.cotizacionEstado,
    this.esCandidato = false,
  });

  final String id;
  final String incidenteId;
  final String tallerId;
  final String estado;
  final String? tecnicoId;
  final String? motivoRechazo;
  final String? respondidoAt;
  final String? asignadoAt;
  final String? incidenteReportadoAt;
  final bool? asignacionAutomatica;
  final String? tallerNombre;
  final String? incidenteEstado;
  final String? incidenteDescripcion;
  final String? incidenteDireccion;
  final double? incidenteLatitud;
  final double? incidenteLongitud;
  final String? incidentePrioridad;
  final String? incidenteResumenIa;
  final double? distanciaKm;
  final int? tiempoLlegadaMin;
  final double? precioSugerido;
  final String? dificultad;
  final double? precioMin;
  final double? precioMax;
  final int? tiempoTotalMin;
  final double? comisionPlataforma;
  final double? montoTaller;
  final String? cotizacionId;
  final double? precioOfertado;
  final int? tiempoOfertadoMin;
  final String? cotizacionEstado;
  final bool esCandidato;

  static String estadoLabel(String estado, {bool esCandidato = false}) {
    if (esCandidato) return 'Candidato';
    const labels = {
      'ASIGNADO': 'Asignado',
      'PENDIENTE': 'Asignado',
      'ACEPTADO': 'Aceptado',
      'RECHAZADO': 'Rechazado',
    };
    return labels[estado] ?? estado;
  }

  static String formatDate(String? iso) {
    if (iso == null) return '—';
    try {
      final dt = DateTime.parse(iso);
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} '
             '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return iso;
    }
  }

  bool get esOportunidadCandidato =>
      esCandidato || (estado == 'PENDIENTE' && asignadoAt == null);

  bool get puedeAceptar =>
      esOportunidadCandidato || estado == 'ASIGNADO';
  bool get puedeRechazar =>
      esOportunidadCandidato || estado == 'ASIGNADO';

  DateTime get sortDate {
    for (final raw in [incidenteReportadoAt, asignadoAt, respondidoAt]) {
      if (raw == null) continue;
      final parsed = DateTime.tryParse(raw);
      if (parsed != null) return parsed;
    }
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  factory Asignacion.fromJson(Map<String, dynamic> json) {
    return Asignacion(
      id: json['id'] as String,
      incidenteId: json['incidente_id'] as String,
      tallerId: json['taller_id'] as String,
      estado: json['estado'] as String,
      tecnicoId: json['tecnico_id'] as String?,
      motivoRechazo: json['motivo_rechazo'] as String?,
      respondidoAt: json['respondido_at']?.toString(),
      asignadoAt: json['asignado_at']?.toString(),
      incidenteReportadoAt: json['incidente_reportado_at']?.toString(),
      asignacionAutomatica: json['asignacion_automatica'] as bool?,
      tallerNombre: json['taller_nombre'] as String?,
      incidenteEstado: json['incidente_estado'] as String?,
      incidenteDescripcion: json['incidente_descripcion'] as String?,
      incidenteDireccion: json['incidente_direccion'] as String?,
      incidenteLatitud: (json['incidente_latitud'] as num?)?.toDouble(),
      incidenteLongitud: (json['incidente_longitud'] as num?)?.toDouble(),
      incidentePrioridad: json['incidente_prioridad'] as String?,
      incidenteResumenIa: json['incidente_resumen_ia'] as String?,
      distanciaKm: (json['distancia_km'] as num?)?.toDouble(),
      tiempoLlegadaMin: (json['tiempo_llegada_min'] as num?)?.toInt(),
      precioSugerido: (json['precio_sugerido'] as num?)?.toDouble(),
      dificultad: json['dificultad'] as String?,
      precioMin: (json['precio_min'] as num?)?.toDouble(),
      precioMax: (json['precio_max'] as num?)?.toDouble(),
      tiempoTotalMin: (json['tiempo_total_min'] as num?)?.toInt(),
      comisionPlataforma: (json['comision_plataforma'] as num?)?.toDouble(),
      montoTaller: (json['monto_taller'] as num?)?.toDouble(),
      cotizacionId: json['cotizacion_id'] as String?,
      precioOfertado: (json['precio_ofertado'] as num?)?.toDouble(),
      tiempoOfertadoMin: (json['tiempo_ofertado_min'] as num?)?.toInt(),
      cotizacionEstado: json['cotizacion_estado'] as String?,
      esCandidato: json['es_candidato'] as bool? ?? false,
    );
  }
}
