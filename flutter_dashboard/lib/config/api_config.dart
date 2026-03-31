class ApiConfig {
  // Zerodha Kite Connect credentials
  static const String kiteApiKey = 'YOUR_KITE_API_KEY';
  static const String kiteApiSecret = 'YOUR_KITE_API_SECRET';
  
  // Gemini AI credentials (pass via --dart-define)
  static const String geminiApiKey = String.fromEnvironment('GEMINI_API_KEY', defaultValue: 'YOUR_GEMINI_API_KEY');

  // Backend endpoints
  static const String baseUrl = 'http://localhost:8000/v1';
  static const String wsUrl = 'ws://localhost:8000/ws/market';
}
