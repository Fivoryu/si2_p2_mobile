import 'package:dio/dio.dart';

import '../models/vehiculo.dart';

class VehiculoApi {
  VehiculoApi(this._dio);

  final Dio _dio;

  Future<List<Vehiculo>> list() async {
    final response = await _dio.get<List<dynamic>>('/vehiculos');
    final items = response.data ?? [];
    return items
        .cast<Map<String, dynamic>>()
        .map(Vehiculo.fromJson)
        .toList();
  }

  Future<Vehiculo> create(Vehiculo vehiculo) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/vehiculos',
      data: vehiculo.toCreateJson(),
    );
    return Vehiculo.fromJson(response.data!);
  }

  Future<void> delete(String id) async {
    await _dio.delete<void>('/vehiculos/$id');
  }
}
