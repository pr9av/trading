import 'package:google_generative_ai/google_generative_ai.dart';
import '../../config/api_config.dart';

class GeminiService {
  late final GenerativeModel _model;

  GeminiService() {
    _model = GenerativeModel(
      model: 'gemini-2.5-flash',
      apiKey: ApiConfig.geminiApiKey,
    );
  }

  Future<String> analyzeStock(String symbol, String context) async {
    if (ApiConfig.geminiApiKey == 'YOUR_GEMINI_API_KEY') {
      return "Hello! I am Gemini, your virtual trading assistant. To get real AI insights, please add your Gemini API key to lib/config/api_config.dart.";
    }

    try {
      final prompt = '''
You are a virtual AI trading assistant for a Flutter stock trading app.
The user is asking about stock: $symbol.

Here is the recent price trend and portfolio context:
$context

Provide short, punchy analysis (buy/sell/hold sentiment) and potential risks in Markdown format.
Keep it under 3 paragraphs.
''';
      
      final content = [Content.text(prompt)];
      final response = await _model.generateContent(content);
      return response.text ?? 'Sorry, I couldn\'t generate an analysis at this time.';
    } catch (e) {
      return 'AI Analysis offline: $e';
    }
  }
}
