import 'package:dio/dio.dart';

import 'config.dart';

String messageFromDio(Object error) {
  if (error is DioException) {
    final data = error.response?.data;
    if (data is Map) {
      final detail = data['detail'];
      if (detail is String) return _friendlyDetail(detail);
      if (detail is List && detail.isNotEmpty) {
        final first = detail.first;
        if (first is Map && first['msg'] != null) {
          return first['msg'] as String;
        }
      }
    }
    final status = error.response?.statusCode;
    if (status == 401) {
      return 'Sesión expirada o inválida. Vuelva a iniciar sesión.';
    }
    if (status == 422) {
      return 'Correo o contraseña inválidos. Verifique que el correo esté bien escrito.';
    }
    if (status == 409) return 'El correo ya está registrado';

    if (error.type == DioExceptionType.connectionError ||
        error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.sendTimeout ||
        error.type == DioExceptionType.receiveTimeout) {
      return _connectionHelp(error);
    }
  }
  final text = error.toString();
  if (text.contains('Connection refused') ||
      text.contains('Failed host lookup') ||
      text.contains('Network is unreachable')) {
    return _connectionHelp(null);
  }
  return text;
}

String _friendlyDetail(String detail) {
  switch (detail) {
    case 'Invalid token':
    case 'Token revoked':
      return 'Sesión expirada o inválida. Vuelva a iniciar sesión.';
    case 'Invalid credentials':
      return 'Correo o contraseña incorrectos';
    default:
      return detail;
  }
}

bool isUnauthorizedError(Object error) {
  if (error is! DioException) return false;
  if (error.response?.statusCode == 401) return true;
  final detail = error.response?.data;
  if (detail is Map && detail['detail'] is String) {
    final d = detail['detail'] as String;
    return d == 'Invalid token' || d == 'Token revoked';
  }
  return false;
}

String _connectionHelp(DioException? error) {
  final uri = error?.requestOptions.uri.toString() ?? Config.apiUrl;
  return 'No se pudo conectar al servidor ($uri).\n\n'
      '• ¿Está el backend en ejecución? (docker compose up / uvicorn en puerto 8000)\n'
      '• En teléfono USB: adb reverse tcp:8000 tcp:8000 y use API_URL=http://127.0.0.1:8000\n'
      '• En Wi‑Fi: use la IP de su PC, ej. --dart-define=API_URL=http://192.168.0.27:8000';
}

bool isValidEmail(String value) {
  final email = value.trim();
  return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email);
}
