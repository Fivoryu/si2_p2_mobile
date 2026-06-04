class Usuario {
  Usuario({
    required this.id,
    required this.nombre,
    required this.email,
    this.telefono,
    this.rol,
    this.tenantId,
  });

  final String id;
  final String nombre;
  final String email;
  final String? telefono;
  final String? rol;
  final String? tenantId;

  factory Usuario.fromJson(Map<String, dynamic> json) {
    return Usuario(
      id: json['id'] as String,
      nombre: json['nombre'] as String,
      email: json['email'] as String,
      telefono: json['telefono'] as String?,
      rol: json['rol'] as String?,
      tenantId: json['tenant_id'] as String?,
    );
  }

  Map<String, dynamic> toUpdateJson({
    String? nombre,
    String? telefono,
    String? email,
    String? password,
  }) {
    final data = <String, dynamic>{};
    if (nombre != null) data['nombre'] = nombre;
    if (telefono != null) data['telefono'] = telefono;
    if (email != null) data['email'] = email;
    if (password != null) data['password'] = password;
    return data;
  }
}
