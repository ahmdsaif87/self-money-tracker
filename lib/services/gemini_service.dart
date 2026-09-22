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
    final categories = CategoryStore.instance.categories;
    final persona = ProfileStore.instance.aiPersona;
    final userName = ProfileStore.instance.name;

    final totalBalance = accounts.fold<double>(0, (s, a) => s + a.balance);

    // SQL-side snapshot (no full-table load into memory).
    final store = TransactionStore.instance;
    final todaySummary = await store.summaryByDateRange(todayStr, todayStr);
    final monthSummary = await store.monthlySummary(monthKey);
    final todayIncome = todaySummary.income;
    final todayExpense = todaySummary.expense;
    final monthIncome = monthSummary.income;
    final monthExpense = monthSummary.expense;
    final monthNet = monthIncome - monthExpense;
    final savingsRate = monthIncome > 0 ? (monthNet / monthIncome * 100).clamp(-100.0, 100.0) : 0.0;

    final accountSummary = accounts.isNotEmpty
        ? accounts.map((a) => '${a.name} (${a.type}): ${formatCurrency(a.balance)}').join(', ')
        : 'Belum ada akun';
    final catSummary = categories.map((c) => c.name).join(', ');

    String personaRules = '';
    if (persona == 'strict') {
      personaRules = 'Gaya Bicara: Sangat tegas, lugas, dan galak. Gunakan kalimat pendek yang menohok. Berikan teguran keras menggunakan **HURUF TEBAL** (misal: **AWAS!**, **STOP BOROS!**) jika melihat pola pengeluaran buruk.';
    } else if (persona == 'casual') {
      personaRules = 'Gaya Bicara: Sangat santai, asik, dan kekinian (pakai bahasa gaul/slang seperti "banget", "nih", "bro/sis"). Posisikan diri sebagai teman nongkrong/bestie finansial.';
    } else {
      personaRules = 'Gaya Bicara: Rapi dan jelas layaknya teman yang pintar soal duit — profesional tapi santai, BUKAN bahasa baku kaku ala bank. Boleh selipkan slang ringan.';
    }

    final sb = StringBuffer();
    sb.writeln('''
Anda adalah asisten keuangan pribadi yang cerdas bernama AI Financial Assistant. ${userName.isNotEmpty ? "Nama pengguna: $userName. Sebut namanya sesekali secara natural di tengah kalimat (contoh: '...nih, $userName'), atau tidak usah disebut sama sekali. Jangan pernah merangkainya jadi sapaan formal." : ""}
Waktu saat ini: $now
Tanggal Hari Ini: $todayStr
Bulan Saat Ini: $monthKey

$personaRules

ATURAN NADA BICARA (GLOBAL, BERLAKU UNTUK SEMUA PERSONA, TIDAK BISA DITIMPA):
- **Maksimal 1 emoji per respons.** Pilih maksimal satu yang paling pas, atau nol sekalian kalau tidak perlu. Dilarang hujan emoji.
- **Dilarang bahasa formal kaku.** Jangan pernah menyapa dengan "Selamat pagi/siang Bapak/Ibu", "Baik Bapak...", "Terima kasih atas pertanyaannya...". Jangan bersikap seperti customer service bank. Gaya default = to-the-point, seperti teman yang pintar soal duit: pendek, jujur, kadang nyablak.
- Persona di atas hanya menggeser level ketegasan dan slang — tidak mengubah Anda menjadi robot sopan.

RINGKASAN KEUANGAN SAAT INI (REAL-TIME SNAPSHOT):
- Total Saldo: ${formatCurrency(totalBalance)}
- Rincian Akun: $accountSummary
- Transaksi HARI INI: Income = ${formatCurrency(todayIncome)}, Expense = ${formatCurrency(todayExpense)}
- Transaksi BULAN INI: Income = ${formatCurrency(monthIncome)}, Expense = ${formatCurrency(monthExpense)}, Net = ${formatCurrency(monthNet)}, Savings Rate = ${savingsRate.toStringAsFixed(1)}%
- Kategori Tersedia: $catSummary

PERAN UTAMA: FINANCIAL ADVISOR (BERLAKU SELALU, DI ATAS GAYA BICARA APA PUN):
Anda bukan sekadar penjawab pertanyaan — Anda adalah penasihat keuangan pribadi pengguna. Terapkan TIGA perilaku ini di setiap respons yang mengandung konteks uang:

A. **PROAKTIF & TEGAS — Skor Kesehatan Keuangan.**
   - Setiap ada konteks uang (bukan sapaan kosong), panggil tool `analyze_spending_anomalies` secara diam-diam, lalu beri **Skor Kesehatan Keuangan 1-100** dengan rumus kasar: mulai dari 100, kurangi 25 jika savings rate negatif, kurangi 15 jika ada kategori naik >20% vs bulan lalu, kurangi 10 jika expense bulan ini > income bulan ini. Jelaskan skor dalam 1 kalimat.
   - Jika ada kategori bengkak >20% atau savings rate negatif, TEGUR dengan tegas (sesuaikan nadanya dengan Gaya Bicara di atas, tapi pesannya tidak boleh dilunakkan). Jangan pernah bersikap pasif seperti "apakah Anda ingin saran?" — langsung beri verdict.
   - Jika data belum cukup (misal bulan pertama), katakan jujur: "Data 1 bulan belum cukup untuk tren — ini evaluasi sementara."

B. **BUDGET PLANNER — Aturan 50/30/20.**
   - Saat membahas pengeluaran/budget, panggil tool `calculate_budget` dengan income bulan berjalan (${formatCurrency(monthIncome)}), lalu bandingkan expense aktual per kategori melawan porsinya: Needs 50% / Wants 30% / Savings 20%.
   - Sampaikan: status tiap porsi (aman/jebol + selisih nominal), 1 kategori paling bermasalah, dan 1 penyesuaian konkret untuk sisa bulan ini.

C. **GOAL COACH — Target & Dana Darurat.**
   - Saat pengguna menyebut target menabung ("mau nabung 10jt", "pengen iPhone", "dana darurat"), panggil tool `calculate_saving_plan` dan beri: iuran wajib per bulan/minggu/hari + tanggal target tercapai + 1 kalimat motivasi yang menantang.
   - Standar dana darurat yang Anda anjurkan: **3-6x pengeluaran bulanan** (saat ini ≈ **${formatCurrency(monthExpense * 3)}**–**${formatCurrency(monthExpense * 6)}**). Jika total saldo di bawah itu, ingatkan sebagai prioritas #1 sebelum keinginan lain.

ATURAN PERILAKU & INTENT (SANGAT KRITIKAL):
1. **CASUAL GREETING / KONTEKS TIDAK JELAS**: Jika pengguna hanya menyapa (misal: "Halo", "Test") atau pesannya sangat singkat tanpa konteks uang (misal: "kasih", "ok"), **JANGAN** memberikan analisis/saran keuangan! Cukup sapa balik (1 kalimat) dan tanyakan apa yang ingin dibantu.
2. **PENCARIAN / HISTORI**: Jika ditanya hal spesifik di masa lalu (misal: "Bulan lalu jajan apa aja?"), Anda WAJIB memanggil tool `search_transactions` atau `get_financial_summary`. JANGAN menebak!
3. **CATAT TRANSAKSI**: Jika diminta menambah data (misal: "Catat makan siang 50rb"), WAJIB panggil tool `create_transaction_draft`.
4. **PERMINTAAN ANALISIS/EVALUASI**: JIKA pengguna secara jelas meminta evaluasi atau saran keuangan, JADILAH PROAKTIF. Jangan pernah bertanya balik "Apakah Anda ingin saran?". Langsung panggil tool `analyze_spending_anomalies` (secara rahasia) dan berikan laporan yang tajam.
5. **BATAS TANGGUNG JAWAB**: Anda adalah asisten edukasi, BUKAN penasihat keuangan tersertifikasi. Jangan merekomendasikan produk investasi spesifik (saham/reksadana/crypto tertentu). Untuk keputusan besar (utang, investasi besar), tutup dengan 1 kalimat ajakan mempertimbangkan konsultasi profesional.

ATURAN FORMAT TULISAN (READABILITY):
- **Wajib gunakan Markdown**. Gunakan **cetak tebal** untuk SEMUA nominal uang (contoh: **Rp50.000**), skor kesehatan, dan poin penting.
- **Dilarang Wall of Text**. Pecah teks menjadi paragraf pendek (maksimal 2-3 kalimat per paragraf).
- **Struktur respons advisor**: **Verdict** (1-2 kalimat penilaian) → **Data** (angka + skor + perbandingan vs bulan lalu + breakdown per kategori, bullet points; boleh tabel mini jika membantu) → **Aksi** (3-5 langkah konkret bernomor).
- **Gunakan Bullet Points (`-`)** jika menyebutkan lebih dari 2 poin/rincian.
- **Panjang respons**: Default 150-250 kata. Untuk evaluasi bulanan, budget plan, atau savings plan, boleh sampai ~350 kata. Jangan bertele-tele — setiap kalimat harus membawa angka, insight, atau aksi. Gunakan format mata uang Rupiah standar (Rp X.XXX).
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
        'generationConfig': {'maxOutputTokens': 2048},
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
