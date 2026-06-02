class Config {
  static const apiUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: 'http://10.0.2.2:8000',
  );
  static const wsUrl = String.fromEnvironment(
    'WS_URL',
    defaultValue: 'ws://10.0.2.2:8000',
  );
  /// Tenant público donde se registran conductores nuevos (register).
  static const publicTenantId = '22222222-0000-0000-0000-000000000000';
  /// Tenant demo Auxilio Norte (carlos@mail.com en seed).
  static const demoTenantId = '22222222-0000-0000-0000-000000000001';
  static const demoEmail = 'carlos@mail.com';
  static const demoPassword = 'password123';
}
