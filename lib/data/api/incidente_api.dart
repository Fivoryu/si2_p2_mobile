import 'package:dio/dio.dart';

import '../models/incidente.dart';

class IncidenteApi {
  IncidenteApi(this._dio);

  final Dio _dio;

  Future<List<Incidente>> list({String? estado, int limit = 50}) async {
    final query = <String, dynamic>{'limit': limit};
    if (estado != null) query['estado'] = estado;

    final response = await _dio.get<Map<String, dynamic>>(
      '/incidentes',
      queryParameters: query,
    );
    final items = response.data!['items'] as List<dynamic>? ?? [];
    return items
        .cast<Map<String, dynamic>>()
        .map(Incidente.fromJson)
        .toList();
  }

  Future<IncidenteDetail> getById(String id) async {
    final response = await _dio.get<Map<String, dynamic>>('/incidentes/$id');
    return IncidenteDetail.fromResponse(response.data!);
  }

  Future<Incidente> create(IncidenteCreate body) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/incidentes',
      data: body.toJson(),
    );
    return Incidente.fromJson(response.data!);
  }

  Future<void> cancel(String id, {String? motivo}) async {
    await _dio.post<Map<String, dynamic>>(
      '/incidentes/$id/cancelar',
      data: {'motivo': motivo},
    );
  }

  Future<void> seleccionarOferta(String cotizacionId) async {
    await _dio.post<Map<String, dynamic>>(
      '/cotizaciones/$cotizacionId/seleccionar',
    );
  }

  Future<void> pagarMock({required String incidenteId, required String cotizacionId}) async {
    await _dio.post<Map<String, dynamic>>(
      '/pagos/mock-complete',
      data: {
        'incidente_id': incidenteId,
        'cotizacion_id': cotizacionId,
      },
    );
  }

Future<void> calificar(String incidenteId, int estrellas, {String? comentario}) async {
    await _dio.post<Map<String, dynamic>>(
      '/incidentes/$incidenteId/calificacion',
      data: {'estrellas': estrellas, 'comentario': comentario},
    );
  }

  Future<Map<String, dynamic>> getRuta(String incidenteId) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/incidentes/$incidenteId/ruta',
    );
    return response.data!;
  }

  Future<void> enviarUbicacion(
    String incidenteId, {
    required double lat,
    required double lng,
    String? tecnicoId,
    bool esFake = false,
  }) async {
    await _dio.post<Map<String, dynamic>>(
      '/incidentes/$incidenteId/ubicacion',
      data: {
        'lat': lat,
        'lng': lng,
        'tecnico_id': tecnicoId,
        'es_fake': esFake,
      },
    );
  }

  Future<Map<String, dynamic>> iniciarSimulacion(
    String incidenteId, {
    double velocidadKmh = 40.0,
    double? duracionSimMin,
    bool usarFake = true,
    bool usarOsrm = true,
    double intervaloSeg = 1.0,
    double? origenLat,
    double? origenLng,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/incidentes/$incidenteId/simular',
      data: {
        'velocidad_kmh': velocidadKmh,
        if (duracionSimMin != null) 'duracion_sim_min': duracionSimMin,
        'usar_fake': usarFake,
        'usar_osrm': usarOsrm,
        'intervalo_seg': intervaloSeg,
        if (origenLat != null) 'origen_lat': origenLat,
        if (origenLng != null) 'origen_lng': origenLng,
      },
    );
    return response.data as Map<String, dynamic>;
  }

  Future<void> cambiarEstado(String incidenteId, String nuevoEstado, {String? comentario}) async {
    await _dio.patch<Map<String, dynamic>>(
      '/incidentes/$incidenteId/estado',
      data: {
        'estado': nuevoEstado,
        ...comentario != null ? {'comentario': comentario} : {},
      },
    );
  }
}
