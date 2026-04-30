class ApiConfig {
  static const String baseUrl = String.fromEnvironment(
    'MORA_KNODE_API',
    defaultValue: 'http://localhost:5163',
  );
}
