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
}
