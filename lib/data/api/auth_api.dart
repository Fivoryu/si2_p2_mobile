import 'package:dio/dio.dart';

import '../models/auth_session.dart';

class AuthApi {
  AuthApi(this._dio);

  final Dio _dio;

  Future<AuthSession> login({
    required String email,
    required String password,
    String? tenantId,
  }) async {
    final data = <String, dynamic>{
      'email': email,
      'password': password,
    };
    if (tenantId != null) {
      data['tenant_id'] = tenantId;
    }

    final response = await _dio.post<Map<String, dynamic>>(
      '/auth/login',
      data: data,
    );
    return AuthSession.fromJson(response.data!);
  }

  Future<String> register({
    required String nombre,
    required String email,
    required String telefono,
    required String password,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/auth/register',
      data: {
        'nombre': nombre,
        'email': email,
        'telefono': telefono,
        'password': password,
      },
    );
    return response.data!['id'] as String;
  }

  Future<void> logout() async {
    await _dio.post<void>('/auth/logout');
  }
}
