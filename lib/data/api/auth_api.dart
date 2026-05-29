import 'package:dio/dio.dart';

import '../models/auth_session.dart';
import '../../core/config.dart';

class AuthApi {
  AuthApi(this._dio);

  final Dio _dio;

  Future<AuthSession> login({
    required String email,
    required String password,
    String? tenantId,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/auth/login',
      data: {
        'email': email,
        'password': password,
        'tenant_id': tenantId ?? Config.defaultTenantId,
      },
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
