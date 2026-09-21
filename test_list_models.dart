import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

void main() async {
  final envFile = File('.env');
  if (!envFile.existsSync()) return;
  final lines = envFile.readAsLinesSync();
  String apiKey = '';
  for (var line in lines) {
    if (line.startsWith('GEMINI_API_KEY=')) apiKey = line.substring('GEMINI_API_KEY='.length);
  }

  try {
    final res = await http.get(
      Uri.parse('https://generativelanguage.googleapis.com/v1beta/models?key=$apiKey'),
    );
    final json = jsonDecode(res.body);
    for (var m in json['models']) {
      if (m['name'].contains('flash')) {
        print(m['name']);
      }
    }
  } catch (e) {}
}
