class AuthSession {
  AuthSession({
    required this.accessToken,
    required this.rol,
    required this.tenantId,
    required this.usuarioId,
    this.mustChangePassword = false,
  });

  final String accessToken;
  final String rol;
  final String? tenantId;
  final String usuarioId;
  final bool mustChangePassword;

  factory AuthSession.fromJson(Map<String, dynamic> json) {
    return AuthSession(
      accessToken: json['access_token'] as String,
      rol: json['rol'] as String,
      tenantId: json['tenant_id'] as String?,
      usuarioId: json['usuario_id'] as String,
      mustChangePassword:
          json['must_change_password'] as bool? ?? false,
    );
  }
}
