import 'package:dio/dio.dart';

import '../models/vehiculo.dart';

class VehiculoApi {
  VehiculoApi(this._dio);

  final Dio _dio;

  Future<List<Vehiculo>> list() async {
    final response = await _dio.get<Map<String, dynamic>>('/vehiculos');
    final items = response.data?['items'] as List<dynamic>? ?? [];
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
    final id = response.data!['id'] as String;
    return Vehiculo(
      id: id,
      placa: vehiculo.placa,
      marca: vehiculo.marca,
      modelo: vehiculo.modelo,
      anio: vehiculo.anio,
      color: vehiculo.color,
      tipoCombustible: vehiculo.tipoCombustible,
    );
  }

  Future<void> delete(String id) async {
    await _dio.delete<void>('/vehiculos/$id');
  }
}
