import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import '../stores/ai_queue_store.dart';
import '../stores/account_store.dart';
import '../stores/transaction_store.dart';
import '../stores/category_store.dart';
import '../stores/profile_store.dart';
import '../utils/amount.dart';
import '../utils/date.dart';
import 'ai_key.dart';
import 'ai_tools.dart';

/// Gemini AI service — mirrors src/services/geminiService.ts
/// Calls the Gemini REST API directly (no SDK needed).
class GeminiService {
  static const _model = 'gemini-3.5-flash-lite';

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
    final todayStr = toLocalDateKey(now);
    final monthKey = '${now.year}-${now.month.toString().padLeft(2, '0')}';

    final accounts = AccountStore.instance.accounts;
    final transactions = TransactionStore.instance.transactions;
    final categories = CategoryStore.instance.categories;
    final persona = ProfileStore.instance.aiPersona;
    final userName = ProfileStore.instance.name;

    final totalBalance = accounts.fold<double>(0, (s, a) => s + a.balance);

    final todayTxs = transactions.where((t) => t.date == todayStr).toList();
    final todayIncome = todayTxs.where((t) => t.type == 'income').fold<double>(0, (s, t) => s + t.amount);
    final todayExpense = todayTxs.where((t) => t.type == 'expense').fold<double>(0, (s, t) => s + t.amount);

    final monthTxs = transactions.where((t) => t.date.startsWith(monthKey)).toList();
    final monthIncome = monthTxs.where((t) => t.type == 'income').fold<double>(0, (s, t) => s + t.amount);
    final monthExpense = monthTxs.where((t) => t.type == 'expense').fold<double>(0, (s, t) => s + t.amount);

    final accountSummary = accounts.isNotEmpty
        ? accounts.map((a) => '${a.name} (${a.type}): ${formatCurrency(a.balance)}').join(', ')
        : 'Belum ada akun';
    final catSummary = categories.map((c) => c.name).join(', ');

    String personaRules = '';
    if (persona == 'strict') {
      personaRules = 'Gaya Bicara: Sangat tegas, lugas, dan galak. Gunakan kalimat pendek yang menohok. Berikan teguran keras menggunakan **HURUF TEBAL** (misal: **AWAS!**, **STOP BOROS!**) jika melihat pola pengeluaran buruk. Boleh pakai emoji peringatan (🛑, 📉, ⚠️).';
    } else if (persona == 'casual') {
      personaRules = 'Gaya Bicara: Sangat santai, asik, dan kekinian (pakai bahasa gaul/slang seperti "banget", "nih", "bro/sis"). Posisikan diri sebagai teman nongkrong/bestie finansial. Gunakan emoji ceria atau ekspresif secara proporsional (💸, 🤩, 🚀).';
    } else {
      personaRules = 'Gaya Bicara: Profesional, elegan, dan sopan layaknya wealth manager bank prioritas. Gunakan bahasa baku yang rapi. Jangan gunakan kata gaul, namun boleh pakai emoji profesional (📊, 🏦, 💡) maksimal 1-2 saja.';
    }

    final sb = StringBuffer();
    sb.writeln('''
Anda adalah asisten keuangan pribadi yang cerdas bernama AI Financial Assistant. ${userName.isNotEmpty ? "Sapa pengguna dengan nama: $userName." : ""}
Waktu saat ini: $now
Tanggal Hari Ini: $todayStr
Bulan Saat Ini: $monthKey

$personaRules

RINGKASAN KEUANGAN SAAT INI (REAL-TIME SNAPSHOT):
- Total Saldo: ${formatCurrency(totalBalance)}
- Rincian Akun: $accountSummary
- Transaksi HARI INI: Income = ${formatCurrency(todayIncome)}, Expense = ${formatCurrency(todayExpense)}
- Transaksi BULAN INI: Income = ${formatCurrency(monthIncome)}, Expense = ${formatCurrency(monthExpense)}
- Kategori Tersedia: $catSummary

ATURAN PERILAKU & INTENT (SANGAT KRITIKAL):
1. **CASUAL GREETING / KONTEKS TIDAK JELAS**: Jika pengguna hanya menyapa (misal: "Halo", "Test") atau pesannya sangat singkat tanpa konteks uang (misal: "kasih", "ok"), **JANGAN** memberikan analisis/saran keuangan! Cukup sapa balik (1 kalimat) dan tanyakan apa yang ingin dibantu.
2. **PENCARIAN / HISTORI**: Jika ditanya hal spesifik di masa lalu (misal: "Bulan lalu jajan apa aja?"), Anda WAJIB memanggil tool `search_transactions` atau `get_financial_summary`. JANGAN menebak!
3. **CATAT TRANSAKSI**: Jika diminta menambah data (misal: "Catat makan siang 50rb"), WAJIB panggil tool `create_transaction_draft`.
4. **PERMINTAAN ANALISIS/EVALUASI**: JIKA pengguna secara jelas meminta evaluasi atau saran keuangan, JADILAH PROAKTIF. Jangan pernah bertanya balik "Apakah Anda ingin saran?". Langsung panggil tool `analyze_spending_anomalies` (secara rahasia) dan berikan laporan yang tajam.

ATURAN FORMAT TULISAN (READABILITY):
- **Wajib gunakan Markdown**. Gunakan **cetak tebal** untuk SEMUA nominal uang (contoh: **Rp50.000**) dan poin penting.
- **Dilarang Wall of Text**. Pecah teks menjadi paragraf pendek (maksimal 2-3 kalimat per paragraf).
- **Gunakan Bullet Points (`-`)** jika menyebutkan lebih dari 2 poin/rincian.
- **Conciseness**: Jawab sepadat mungkin (maksimal 100-150 kata) kecuali diminta laporan super detail. Gunakan format mata uang Rupiah standar (Rp X.XXX).
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
      ).timeout(const Duration(seconds: 90));

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
    
    return (text: 'Gagal mendapatkan respons lengkap setelah beberapa panggilan fungsi.', payload: capturedPayload);
  }

  static Future<({String response, bool queued, String? queueId, String? payload})> processAIChatPrompt(
    String prompt, {
    List<Map<String, dynamic>>? history,
  }) async {
    final apiKey = await AIKeyService.getApiKey();
    final online = await isOnline();

    if (apiKey == null || apiKey.isEmpty || !online) {
      final item = await AIQueueStore.instance.addToQueue(prompt);
      return (
        response: 'Pesan Anda telah dimasukkan ke dalam antrean offline dan akan diproses secara otomatis begitu koneksi internet dan API Key tersedia.',
        queued: true,
        queueId: item.id,
        payload: null,
      );
    }

    try {
      final res = await _generate(apiKey, prompt, history: history);
      return (
        response: res.text,
        queued: false,
        queueId: null,
        payload: res.payload,
      );
    } catch (e) {
      debugPrint('Gemini generate error: $e');
      final item = await AIQueueStore.instance.addToQueue(prompt);
      return (
        response: 'Gagal menghubungkan ke asisten AI secara langsung ($e). Pesan Anda telah dimasukkan ke antrean offline.',
        queued: true,
        queueId: item.id,
        payload: null,
      );
    }
  }

  static Future<void> syncPendingAIQueue() async {
    final apiKey = await AIKeyService.getApiKey();
    if (apiKey == null || apiKey.isEmpty) return;
    final online = await isOnline();
    if (!online) return;

    await AIQueueStore.instance.fetchQueue();
    final pendingItems = AIQueueStore.instance.queue.where((i) => i.status == 'pending').toList();
    for (final item in pendingItems) {
      try {
        await AIQueueStore.instance.updateStatus(item.id, 'processing');
        final res = await _generate(apiKey, item.prompt);
        await AIQueueStore.instance.updateStatus(item.id, 'completed', response: res.text);
      } catch (e) {
        await AIQueueStore.instance.updateStatus(item.id, 'failed', response: e.toString());
      }
    }
  }

  static Future<void> retryQueueItem(String queueId) async {
    final apiKey = await AIKeyService.getApiKey();
    if (apiKey == null || apiKey.isEmpty) return;
    await AIQueueStore.instance.fetchQueue();
    final items = AIQueueStore.instance.queue.where((i) => i.id == queueId).toList();
    if (items.isEmpty) return;
    final item = items.first;

    try {
      await AIQueueStore.instance.updateStatus(item.id, 'processing');
      final res = await _generate(apiKey, item.prompt);
      await AIQueueStore.instance.updateStatus(item.id, 'completed', response: res.text);
    } catch (e) {
      await AIQueueStore.instance.updateStatus(item.id, 'failed', response: e.toString());
    }
  }
}
