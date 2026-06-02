class Asignacion {
  Asignacion({
    required this.id,
    required this.incidenteId,
    required this.tallerId,
    required this.estado,
    this.tecnicoId,
    this.motivoRechazo,
    this.respondidoAt,
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
    this.cotizacionId,
    this.precioOfertado,
    this.tiempoOfertadoMin,
    this.cotizacionEstado,
  });

  final String id;
  final String incidenteId;
  final String tallerId;
  final String estado;
  final String? tecnicoId;
  final String? motivoRechazo;
  final String? respondidoAt;
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
  final String? cotizacionId;
  final double? precioOfertado;
  final int? tiempoOfertadoMin;
  final String? cotizacionEstado;

  static String estadoLabel(String estado) {
    const labels = {
      'ASIGNADO': 'Asignado',
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

  bool get puedeAceptar => estado == 'ASIGNADO';
  bool get puedeRechazar => estado == 'ASIGNADO';

  factory Asignacion.fromJson(Map<String, dynamic> json) {
    return Asignacion(
      id: json['id'] as String,
      incidenteId: json['incidente_id'] as String,
      tallerId: json['taller_id'] as String,
      estado: json['estado'] as String,
      tecnicoId: json['tecnico_id'] as String?,
      motivoRechazo: json['motivo_rechazo'] as String?,
      respondidoAt: json['respondido_at']?.toString(),
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
      cotizacionId: json['cotizacion_id'] as String?,
      precioOfertado: (json['precio_ofertado'] as num?)?.toDouble(),
      tiempoOfertadoMin: (json['tiempo_ofertado_min'] as num?)?.toInt(),
      cotizacionEstado: json['cotizacion_estado'] as String?,
    );
  }
}
