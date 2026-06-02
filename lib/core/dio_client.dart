import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'config.dart';

const _storage = FlutterSecureStorage();
const _jwtKey = 'jwt';

typedef UnauthorizedCallback = Future<void> Function();

UnauthorizedCallback? _onUnauthorized;

/// Registra callback global para limpiar sesión ante 401.
void registerUnauthorizedHandler(UnauthorizedCallback handler) {
  _onUnauthorized = handler;
}

Dio buildDio() {
  final dio = Dio(
    BaseOptions(
      baseUrl: Config.apiUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 30),
      headers: {'Content-Type': 'application/json'},
    ),
  );
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await _storage.read(key: _jwtKey);
        if (token != null && token.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
      onError: (error, handler) async {
        final status = error.response?.statusCode;
        if (status == 401 && _onUnauthorized != null) {
          await _storage.delete(key: _jwtKey);
          await _storage.delete(key: 'tenant_id');
          await _storage.delete(key: 'usuario_id');
          await _storage.delete(key: 'rol');
          await _onUnauthorized!();
        }
        handler.next(error);
      },
    ),
  );
  return dio;
}
