import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../data/api/auth_api.dart';
import '../data/api/usuario_api.dart';
import '../data/models/auth_session.dart';
import '../data/models/usuario.dart';

class AuthService {
  AuthService({
    required Dio dio,
    FlutterSecureStorage? storage,
  })  : _storage = storage ?? const FlutterSecureStorage(),
        _authApi = AuthApi(dio),
        _usuarioApi = UsuarioApi(dio);

  final FlutterSecureStorage _storage;
  final AuthApi _authApi;
  final UsuarioApi _usuarioApi;

  static const _jwtKey = 'jwt';
  static const _tenantKey = 'tenant_id';
  static const _usuarioKey = 'usuario_id';
  static const _rolKey = 'rol';
  static const _mustChangeKey = 'must_change_password';

  Future<AuthSession> login({
    required String email,
    required String password,
    String? tenantId,
  }) async {
    final session = await _authApi.login(
      email: email,
      password: password,
      tenantId: tenantId,
    );
    await _persistSession(session);
    return session;
  }

  Future<void> register({
    required String nombre,
    required String email,
    required String telefono,
    required String password,
  }) async {
    await _authApi.register(
      nombre: nombre,
      email: email,
      telefono: telefono,
      password: password,
    );
  }

  Future<void> logout() async {
    try {
      await _authApi.logout();
    } catch (_) {
      // Clear local session even if server call fails.
    }
    await clearSession();
  }

  Future<bool> getMustChangePassword() async {
    final v = await _storage.read(key: _mustChangeKey);
    return v == 'true';
  }

  Future<void> changePassword({
    required String passwordActual,
    required String passwordNueva,
  }) async {
    await _authApi.changePassword(
      passwordActual: passwordActual,
      passwordNueva: passwordNueva,
    );
    await _storage.delete(key: _mustChangeKey);
  }

  Future<bool> isLoggedIn() async {
    final token = await _storage.read(key: _jwtKey);
    return token != null && token.isNotEmpty;
  }

  Future<String?> getToken() => _storage.read(key: _jwtKey);

  Future<String?> getTenantId() => _storage.read(key: _tenantKey);

  Future<String?> getRol() => _storage.read(key: _rolKey);

  Future<Usuario?> getProfile() async {
    if (!await isLoggedIn()) return null;
    try {
      return await _usuarioApi.me();
    } catch (_) {
      return null;
    }
  }

  Future<void> _persistSession(AuthSession session) async {
    await _storage.write(key: _jwtKey, value: session.accessToken);
    if (session.tenantId != null) {
      await _storage.write(key: _tenantKey, value: session.tenantId);
    }
    await _storage.write(key: _usuarioKey, value: session.usuarioId);
    await _storage.write(key: _rolKey, value: session.rol);
    await _storage.write(
      key: _mustChangeKey,
      value: session.mustChangePassword.toString(),
    );
  }

  Future<void> clearSession() async {
    await _storage.delete(key: _jwtKey);
    await _storage.delete(key: _tenantKey);
    await _storage.delete(key: _usuarioKey);
    await _storage.delete(key: _rolKey);
    await _storage.delete(key: _mustChangeKey);
  }
}
