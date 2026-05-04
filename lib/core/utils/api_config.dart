class ApiConfig {
  // Keep backend endpoints unchanged; only the base URL should be adjusted per env.
  static const String baseUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: 'http://192.168.0.102:8080',
  );
}
