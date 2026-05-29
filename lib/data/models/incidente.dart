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
    this.isLocal = false,
    this.estadoSync,
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
  final bool isLocal;
  final String? estadoSync;

  factory Incidente.fromJson(Map<String, dynamic> json) {
    return Incidente(
      id: json['id'] as String,
      estado: json['estado'] as String? ?? 'PENDIENTE',
      descripcion: json['descripcion'] as String?,
      prioridad: json['prioridad'] as String?,
      latitud: (json['latitud'] as num?)?.toDouble(),
      longitud: (json['longitud'] as num?)?.toDouble(),
      direccion: json['direccion'] as String?,
      reportadoAt: json['reportado_at'] as String?,
      vehiculoId: json['vehiculo_id'] as String?,
    );
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
    );
  }
}
