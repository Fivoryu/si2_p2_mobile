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

  Future<Incidente> getById(String id) async {
    final response = await _dio.get<Map<String, dynamic>>('/incidentes/$id');
    return Incidente.fromJson(response.data!);
  }
}
