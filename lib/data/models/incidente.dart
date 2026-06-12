class Incidente {
  Incidente({
    required this.id,
    required this.estado,
    this.descripcion,
    this.prioridad,
    this.latitud,
    this.longitud,
    this.direccion,
    this.reportadoAt,
    this.vehiculoId,
    this.resumenIa,
    this.tipoIncidenteId,
    this.isLocal = false,
    this.estadoSync,
    this.serverId,
  });

  final String id;
  final String estado;
  final String? descripcion;
  final String? prioridad;
  final double? latitud;
  final double? longitud;
  final String? direccion;
  final String? reportadoAt;
  final String? vehiculoId;
  final String? resumenIa;
  final String? tipoIncidenteId;
  final bool isLocal;
  final String? estadoSync;
  final String? serverId;

  /// ID to use for tracking/WS/API — prefers server id after sync.
  String get trackingId => serverId ?? id;

  bool get isPendingSync => isLocal && estadoSync == 'PENDIENTE';

  bool get isErrorSync => isLocal && estadoSync == 'ERROR';

  bool get isSyncedLocal => isLocal && estadoSync == 'SINCRONIZADO';

  bool get needsSync =>
      isLocal && (estadoSync == 'PENDIENTE' || estadoSync == 'ERROR');

  String? get syncStatusLabel {
    if (!isLocal || estadoSync == null) return null;
    return switch (estadoSync) {
      'PENDIENTE' => 'Pendiente de sincronización',
      'ERROR' => 'Error al sincronizar',
      'SINCRONIZADO' => 'Sincronizado',
      _ => null,
    };
  }

  bool get isCancelable =>
      estado == 'PENDIENTE' || estado == 'BUSCANDO_TALLER';

  static String estadoLabel(String estado) {
    const labels = {
      'PENDIENTE': 'Pendiente',
      'BUSCANDO_TALLER': 'Buscando taller',
      'TALLER_ASIGNADO': 'Taller asignado',
      'EN_CAMINO': 'En camino',
      'EN_ATENCION': 'En atención',
      'FINALIZADO': 'Finalizado',
      'CANCELADO': 'Cancelado',
      'NO_ATENDIDO': 'No atendido',
      'PAGADO': 'Pagado',
    };
    return labels[estado] ?? estado;
  }

  factory Incidente.fromJson(Map<String, dynamic> json) {
    return Incidente(
      id: json['id'] as String,
      estado: json['estado'] as String? ?? 'PENDIENTE',
      descripcion: json['descripcion'] as String?,
      prioridad: json['prioridad'] as String?,
      latitud: (json['latitud'] as num?)?.toDouble(),
      longitud: (json['longitud'] as num?)?.toDouble(),
      direccion: json['direccion'] as String?,
      reportadoAt: json['reportado_at']?.toString(),
      vehiculoId: json['vehiculo_id'] as String?,
      resumenIa: json['resumen_ia'] as String?,
      tipoIncidenteId: json['tipo_incidente_id'] as String?,
    );
  }

  factory Incidente.fromDetailResponse(Map<String, dynamic> json) {
    final inc = json['incidente'] as Map<String, dynamic>? ?? json;
    return Incidente.fromJson(inc);
  }

  factory Incidente.fromLocalRow(Map<String, dynamic> row) {
    return Incidente(
      id: row['id_local'] as String,
      estado: 'PENDIENTE',
      descripcion: row['descripcion'] as String?,
      latitud: (row['latitud'] as num?)?.toDouble(),
      longitud: (row['longitud'] as num?)?.toDouble(),
      direccion: row['direccion'] as String?,
      reportadoAt: row['client_created_at'] as String?,
      vehiculoId: row['vehiculo_id'] as String?,
      isLocal: true,
      estadoSync: row['estado_sync'] as String?,
      serverId: row['id_servidor'] as String?,
    );
  }
}

class IncidenteDetail {
  IncidenteDetail({
    required this.incidente,
    required this.evidencias,
    this.asignacion,
    this.ofertas = const [],
    this.ultimaUbicacion,
  });

  final Incidente incidente;
  final List<Map<String, dynamic>> evidencias;
  final Map<String, dynamic>? asignacion;
  final List<OfertaTaller> ofertas;
  final Map<String, dynamic>? ultimaUbicacion;

  factory IncidenteDetail.fromResponse(Map<String, dynamic> json) {
    return IncidenteDetail(
      incidente: Incidente.fromDetailResponse(json),
      evidencias: (json['evidencias'] as List<dynamic>? ?? [])
          .cast<Map<String, dynamic>>(),
      asignacion: json['asignacion'] as Map<String, dynamic>?,
      ofertas: (json['ofertas'] as List<dynamic>? ?? [])
          .cast<Map<String, dynamic>>()
          .map(OfertaTaller.fromJson)
          .toList(),
      ultimaUbicacion: json['ultima_ubicacion'] as Map<String, dynamic>?,
    );
  }
}

class OfertaTaller {
  OfertaTaller({
    required this.id,
    required this.tallerId,
    required this.monto,
    required this.estado,
    this.tallerNombre,
    this.precioSugerido,
    this.tiempoEstimadoMin,
    this.comentarioTaller,
    this.calificacion,
  });

  final String id;
  final String tallerId;
  final double monto;
  final String estado;
  final String? tallerNombre;
  final double? precioSugerido;
  final int? tiempoEstimadoMin;
  final String? comentarioTaller;
  final double? calificacion;

  factory OfertaTaller.fromJson(Map<String, dynamic> json) {
    return OfertaTaller(
      id: json['id'] as String,
      tallerId: json['taller_id'] as String,
      monto: (json['monto'] as num).toDouble(),
      estado: json['estado'] as String? ?? 'PENDIENTE',
      tallerNombre: json['taller_nombre'] as String?,
      precioSugerido: (json['precio_sugerido'] as num?)?.toDouble(),
      tiempoEstimadoMin: (json['tiempo_estimado_min'] as num?)?.toInt(),
      comentarioTaller: json['comentario_taller'] as String?,
      calificacion: (json['calificacion'] as num?)?.toDouble(),
    );
  }
}

class IncidenteCreate {
  IncidenteCreate({
    required this.vehiculoId,
    this.descripcion,
    this.latitud,
    this.longitud,
    this.direccion,
    this.externalId,
  });

  final String vehiculoId;
  final String? descripcion;
  final double? latitud;
  final double? longitud;
  final String? direccion;
  final String? externalId;

  Map<String, dynamic> toJson() => {
        'vehiculo_id': vehiculoId,
        if (descripcion != null) 'descripcion': descripcion,
        if (latitud != null) 'latitud': latitud,
        if (longitud != null) 'longitud': longitud,
        if (direccion != null) 'direccion': direccion,
        if (externalId != null) 'external_id': externalId,
      };
}
