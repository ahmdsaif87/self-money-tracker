import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

void main() async {
  final envFile = File('.env');
  if (!envFile.existsSync()) {
    print('No .env file');
    return;
  }
  final lines = envFile.readAsLinesSync();
  String apiKey = '';
  for (var line in lines) {
    if (line.startsWith('GEMINI_API_KEY=')) {
      apiKey = line.substring('GEMINI_API_KEY='.length);
    }
  }

  final model = 'gemini-3.1-flash-lite';
  
  final start = DateTime.now();
  final body = jsonEncode({
    'contents': [
      {'role': 'user', 'parts': [{'text': 'SYSTEM INSTRUCTION: You are a financial assistant.'}]},
      {'role': 'model', 'parts': [{'text': 'Understood.'}]},
      {'role': 'user', 'parts': [{'text': 'analisis keuangan saya'}]}
    ],
    'tools': [
      {
        'function_declarations': [
          {
            'name': 'analyze_spending_anomalies',
            'description': 'Menganalisis anomali pengeluaran',
            'parameters': {'type': 'OBJECT', 'properties': {}}
          }
        ]
      }
    ],
  });

  try {
    final res = await http.post(
      Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$apiKey'),
      headers: {'Content-Type': 'application/json'},
      body: body,
    ).timeout(const Duration(seconds: 30));

    final duration = DateTime.now().difference(start).inMilliseconds;
    print('Status: ${res.statusCode}');
    print('Duration: $duration ms');
    print('Body: ${res.body}');
  } catch (e) {
    print('Error: $e');
  }
}
