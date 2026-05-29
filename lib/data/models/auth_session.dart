class AuthSession {
  AuthSession({
    required this.accessToken,
    required this.rol,
    required this.tenantId,
    required this.usuarioId,
  });

  final String accessToken;
  final String rol;
  final String tenantId;
  final String usuarioId;

  factory AuthSession.fromJson(Map<String, dynamic> json) {
    return AuthSession(
      accessToken: json['access_token'] as String,
      rol: json['rol'] as String,
      tenantId: json['tenant_id'] as String,
      usuarioId: json['usuario_id'] as String,
    );
  }
}
