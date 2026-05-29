import 'package:dio/dio.dart';

import '../models/usuario.dart';

class UsuarioApi {
  UsuarioApi(this._dio);

  final Dio _dio;

  Future<Usuario> me() async {
    final response = await _dio.get<Map<String, dynamic>>('/usuarios/me');
    return Usuario.fromJson(response.data!);
  }

  Future<Usuario> update(Map<String, dynamic> data) async {
    final response = await _dio.patch<Map<String, dynamic>>(
      '/usuarios/me',
      data: data,
    );
    return Usuario.fromJson(response.data!);
  }
}
