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

  if (apiKey.isEmpty) {
    print('No GEMINI_API_KEY');
    return;
  }

  final model = 'gemini-3.1-flash-lite';
  print('Testing model $model...');
  
  final start = DateTime.now();
  final body = jsonEncode({
    'contents': [
      {'role': 'user', 'parts': [{'text': 'Hello'}]}
    ]
  });

  try {
    final res = await http.post(
      Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$apiKey'),
      headers: {'Content-Type': 'application/json'},
      body: body,
    ).timeout(const Duration(seconds: 30));

    final duration = DateTime.now().difference(start).inMilliseconds;
    print('Response status: ${res.statusCode}');
    print('Duration: $duration ms');
    print('Body: ${res.body}');
  } catch (e) {
    print('Error: $e');
  }
}
