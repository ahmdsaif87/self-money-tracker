import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import '../stores/ai_queue_store.dart';
import 'ai_key.dart';
import 'ai_tools.dart';

/// Gemini AI service — mirrors src/services/geminiService.ts
/// Calls the Gemini REST API directly (no SDK needed).
class GeminiService {
  static const _model = 'gemini-2.5-flash';

  static Future<bool> isOnline() async {
    try {
      final res = await http
          .head(Uri.parse('https://clients3.google.com/generate_204'))
          .timeout(const Duration(seconds: 5));
      return res.statusCode == 204 || res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  static Future<String> _buildSystemContext() async {
    final now = DateTime.now();
    final sb = StringBuffer();
    sb.writeln('''
Anda adalah asisten keuangan pribadi yang cerdas.
Waktu saat ini: $now
Anda memiliki akses ke data keuangan pengguna melalui fungsi/tools yang disediakan.

ATURAN PENTING:
1. Jangan pernah mengarang angka, transaksi, atau kategori. Gunakan data aktual.
2. Panggil fungsi yang sesuai untuk mendapatkan informasi sebelum menjawab.
3. Jawab dengan ringkas (maksimal 3-5 kalimat), rapi, dan mudah dibaca (gunakan format Rupiah Rp X.XXX).
4. Jika disuruh menambahkan transaksi, gunakan tool create_transaction_draft.
5. Anda dapat memberikan nasihat dan pandangan (insight) keuangan yang relevan berdasar profil data pengguna.
6. Jawab dalam Bahasa Indonesia yang santun.
''');
    return sb.toString();
  }

  static Future<({String text, String? payload})> _generate(
      String apiKey, String prompt, {List<Map<String, dynamic>>? history}) async {
    
    final systemContext = await _buildSystemContext();
    
    final List<Map<String, dynamic>> contents = [
      {'role': 'user', 'parts': [{'text': 'SYSTEM INSTRUCTION (Do not reply to this, just acknowledge it internally):\n$systemContext'}]},
      {'role': 'model', 'parts': [{'text': 'Mengerti.'}]},
    ];

    if (history != null) {
      contents.addAll(history);
    }
    
    contents.add({
      'role': 'user',
      'parts': [{'text': prompt}]
    });

    String? capturedPayload;
    
    // Loop max 5 times for tool calls
    for (int i = 0; i < 5; i++) {
      final body = jsonEncode({
        'contents': contents,
        'tools': [
          {'function_declarations': AITools.toolDeclarations}
        ],
        'generationConfig': {'maxOutputTokens': 1024},
      });

      final res = await http.post(
        Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/$_model:generateContent?key=$apiKey'),
        headers: {'Content-Type': 'application/json'},
        body: body,
      ).timeout(const Duration(seconds: 60));

      if (res.statusCode != 200) {
        throw Exception('Gemini API error ${res.statusCode}: ${res.body}');
      }

      final json = jsonDecode(res.body) as Map<String, dynamic>;
      final candidates = json['candidates'] as List? ?? [];
      if (candidates.isEmpty) return (text: '(tanpa respons)', payload: capturedPayload);
      
      final content = (candidates.first as Map<String, dynamic>)['content'] as Map<String, dynamic>?;
      if (content == null) return (text: '(tanpa respons)', payload: capturedPayload);
      
      final parts = content['parts'] as List? ?? [];
      if (parts.isEmpty) return (text: '(tanpa respons)', payload: capturedPayload);
      
      final functionCallPart = parts.firstWhere((p) => (p as Map).containsKey('functionCall'), orElse: () => null);
      
      if (functionCallPart != null) {
        // AI called a tool
        final fnCall = functionCallPart['functionCall'] as Map<String, dynamic>;
        final fnName = fnCall['name'] as String;
        final fnArgs = fnCall['args'] as Map<String, dynamic>? ?? {};
        
        // Add the model's tool call to history
        contents.add({
          'role': 'model',
          'parts': [functionCallPart]
        });

        // Execute tool
        final result = await AITools.executeTool(fnName, fnArgs);
        
        // Intercept payload if it's a draft
        if (result.containsKey('_internal_payload')) {
          capturedPayload = jsonEncode(result['_internal_payload']);
          result.remove('_internal_payload');
        }

        // Add tool response to history
        contents.add({
          'role': 'user',
          'parts': [
            {
              'functionResponse': {
                'name': fnName,
                'response': {
                  'name': fnName,
                  'content': result
                }
              }
            }
          ]
        });
        
        // Loop continues, sending function response back to LLM
      } else {
        // Normal text response
        final text = parts.first['text']?.toString() ?? '(tanpa respons)';
        return (text: text, payload: capturedPayload);
      }
    }
    
    return (text: 'Maaf, saya tidak dapat menyelesaikan permintaan karena terlalu banyak langkah.', payload: capturedPayload);
  }

  static Future<({String response, bool queued, String? queueId, String? payload})> processAIChatPrompt(
      String prompt, {List<Map<String, dynamic>>? history}) async {
    final apiKey = await AIKeyService.getApiKey();
    if (apiKey == null || apiKey.isEmpty) {
      return (
        response: 'API key Gemini belum diatur. Buka Pengaturan > Asisten AI untuk menambahkannya.',
        queued: false,
        queueId: null,
        payload: null,
      );
    }

    final online = await isOnline();
    if (!online) {
      final item = await AIQueueStore.instance.addToQueue(prompt);
      return (
        response: 'Anda sedang offline. Pertanyaan Anda masuk antrean dan akan diproses otomatis saat koneksi pulih. (Fitur interaktif tidak tersedia secara luring)',
        queued: true,
        queueId: item.id,
        payload: null,
      );
    }

    try {
      final result = await _generate(apiKey, prompt, history: history);
      return (response: result.text, queued: false, queueId: null, payload: result.payload);
    } catch (e) {
      debugPrint('Gemini API Error: $e');
      final item = await AIQueueStore.instance.addToQueue(prompt);
      return (
        response: 'Terjadi kendala jaringan saat menghubungi asisten AI. Pertanyaan Anda masuk antrean dan akan dicoba lagi nanti.',
        queued: true,
        queueId: item.id,
        payload: null,
      );
    }
  }

  static Future<int> syncPendingAIQueue() async {
    final online = await isOnline();
    if (!online) return 0;
    final apiKey = await AIKeyService.getApiKey();
    if (apiKey == null || apiKey.isEmpty) return 0;

    final store = AIQueueStore.instance;
    await store.fetchQueue();
    final pending = store.queue.where((i) => i.status == 'pending' || i.status == 'failed').toList();
    var processed = 0;

    for (final item in pending) {
      await store.updateStatus(item.id, 'processing');
      try {
        final result = await _generate(apiKey, item.prompt);
        await store.updateStatus(item.id, 'completed', response: result.text); // We don't save payload for offline queue to avoid dangling state
        processed++;
      } catch (_) {
        await store.updateStatus(item.id, 'failed');
      }
    }
    return processed;
  }

  static Future<bool> retryQueueItem(String id) async {
    final online = await isOnline();
    if (!online) return false;
    final apiKey = await AIKeyService.getApiKey();
    if (apiKey == null || apiKey.isEmpty) return false;

    final store = AIQueueStore.instance;
    await store.fetchQueue();
    final item = store.queue.where((i) => i.id == id).firstOrNull;
    if (item == null || item.status != 'failed') return false;

    await store.updateStatus(id, 'processing');
    try {
      final result = await _generate(apiKey, item.prompt);
      await store.updateStatus(id, 'completed', response: result.text);
      return true;
    } catch (_) {
      await store.updateStatus(id, 'failed');
      return false;
    }
  }
}
