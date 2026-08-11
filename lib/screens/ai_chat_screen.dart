import 'package:flutter/material.dart';
import '../db/database.dart';
import '../stores/chat_store.dart';
import '../stores/ai_queue_store.dart';
import '../stores/theme_store.dart';
import '../models/models.dart';
import '../theme/theme.dart';
import '../components/app_icon.dart';
import 'dart:convert';
import 'package:intl/intl.dart';
import '../services/gemini_service.dart';
import '../stores/transaction_store.dart';

class AIChatScreen extends StatefulWidget {
  const AIChatScreen({super.key});

  @override
  State<AIChatScreen> createState() => _AIChatScreenState();
}

class _AIChatScreenState extends State<AIChatScreen> {
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();
  bool _isSending = false;
  bool _consentLoaded = false;
  bool _consentAccepted = false;

  @override
  void initState() {
    super.initState();
    ChatStore.instance.load();
    AIQueueStore.instance.fetchQueue();
    _ensureConsent();
    _processQueue();
  }

  Future<void> _ensureConsent() async {
    final existing = await DB.instance.getSetting('ai_consent');
    if (existing == 'accepted') {
      if (mounted) {
        setState(() {
          _consentAccepted = true;
          _consentLoaded = true;
        });
      }
      return;
    }
    if (!mounted) return;
    final agreed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Kirim Data ke Asisten AI?'),
        content: const Text(
          'Untuk menjawab pertanyaan, aplikasi mengirim ringkasan keuangan Anda '
          '(total saldo, akun, dan kategori 3 bulan terakhir) ke Google Gemini.\n\n'
          'Data tersimpan offline di perangkat Anda dan hanya dikirim saat Anda bertanya.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Tolak'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Setujui'),
          ),
        ],
      ),
    );
    if (agreed == true) {
      await DB.instance.setSetting('ai_consent', 'accepted');
    }
    if (mounted) {
      setState(() {
        _consentAccepted = agreed == true;
        _consentLoaded = true;
      });
    }
  }

  Future<void> _processQueue() async {
    await GeminiService.syncPendingAIQueue();
    await ChatStore.instance.reflectQueueState();
    if (mounted) setState(() {});
  }

  Future<void> _retryMessage(ChatMessage msg) async {
    if (msg.queueId == null || _isSending) return;
    setState(() => _isSending = true);
    await GeminiService.retryQueueItem(msg.queueId!);
    await ChatStore.instance.reflectQueueState();
    if (mounted) setState(() => _isSending = false);
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _handleSend() async {
    final text = _inputController.text.trim();
    if (text.isEmpty || _isSending) return;
    if (!_consentAccepted) {
      await _ensureConsent();
      if (!_consentAccepted || !mounted) return;
    }

    _inputController.clear();
    setState(() => _isSending = true);

    final userMsg = ChatMessage(id: _id(), sender: 'user', text: text);
    try {
      await ChatStore.instance.add(userMsg);
    } catch (_) {}

    if (!mounted) return;
    _scrollToBottom();

    var response = '';
    var queued = false;
    String? queueId;
    String? payload;

    try {
      final recentHistory = ChatStore.instance.messages.length > 10
          ? ChatStore.instance.messages.sublist(ChatStore.instance.messages.length - 10)
          : ChatStore.instance.messages;

      final history = recentHistory.map((m) => {
        'role': m.sender == 'user' ? 'user' : 'model',
        'parts': [{'text': m.text}],
      }).toList();

      final result = await GeminiService.processAIChatPrompt(text, history: history);
      response = result.response;
      queued = result.queued;
      queueId = result.queueId;
      payload = result.payload;
    } catch (e) {
      debugPrint('AI prompt error: $e');
      response = 'Terjadi kendala saat menghubungi asisten AI. Coba lagi nanti.';
    }

    if (!mounted) return;
    final aiMsg = ChatMessage(
      id: _id(),
      sender: 'ai',
      text: response,
      queued: queued,
      queueId: queueId,
      state: queued ? 'pending' : 'completed',
      payload: payload,
    );
    try {
      await ChatStore.instance.add(aiMsg);
    } catch (_) {}
    if (mounted) {
      _isSending = false;
      setState(() {});
      _scrollToBottom();
    }
  }

  String _id() =>
      'msg_${DateTime.now().millisecondsSinceEpoch}_${(DateTime.now().microsecondsSinceEpoch % 10000)}';

  @override
  Widget build(BuildContext context) {
    final dark = ThemeStore.instance.isDarkMode;
    final messages = ChatStore.instance.messages;

    return Scaffold(
      backgroundColor: ThemeColors.bg(dark),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.of(context).maybePop(),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: ThemeColors.card(dark),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: ThemeColors.border(dark)),
                      ),
                      child: AppIcon(
                        'arrow-left',
                        size: 20,
                        color: ThemeColors.textPrimary(dark),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: ThemeColors.accentExpense(
                        dark,
                      ).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: AppIcon(
                      'sparkles',
                      size: 20,
                      color: ThemeColors.accentExpense(dark),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Asisten AI',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: ThemeColors.textPrimary(dark),
                          ),
                        ),
                        Text(
                          'Analisis keuangan Anda',
                          style: TextStyle(
                            fontSize: 12,
                            color: ThemeColors.textMuted(dark),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: ThemeColors.border(dark)),

            // Privacy disclosure
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: Text(
                'Ringkasan keuangan Anda dikirim ke Google untuk diproses.',
                style: TextStyle(
                  fontSize: 11,
                  color: ThemeColors.textMuted(dark),
                ),
              ),
            ),

            // Messages
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(20),
                itemCount: messages.length + (_isSending ? 1 : 0),
                itemBuilder: (context, i) {
                  if (i >= messages.length) {
                    return const Align(
                      alignment: Alignment.centerLeft,
                      child: _TypingBubble(),
                    );
                  }
                  final msg = messages[i];
                  final isUser = msg.sender == 'user';
                  
                  Map<String, dynamic>? payloadObj;
                  if (msg.payload != null) {
                    try { payloadObj = jsonDecode(msg.payload!); } catch (_) {}
                  }
                  
                  return Align(
                    alignment: isUser
                        ? Alignment.centerRight
                        : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      constraints: BoxConstraints(
                        maxWidth: MediaQuery.of(context).size.width * 0.78,
                      ),
                      decoration: BoxDecoration(
                        color: isUser
                            ? ThemeColors.fillExpense
                            : ThemeColors.card(dark),
                        borderRadius: BorderRadius.only(
                          topLeft: const Radius.circular(16),
                          topRight: const Radius.circular(16),
                          bottomLeft: Radius.circular(isUser ? 16 : 4),
                          bottomRight: Radius.circular(isUser ? 4 : 16),
                        ),
                        border: isUser
                            ? null
                            : Border.all(color: ThemeColors.border(dark)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            msg.text,
                            style: TextStyle(
                              fontSize: 14,
                              height: 1.4,
                              color: isUser
                                  ? Colors.white
                                  : ThemeColors.textPrimary(dark),
                            ),
                          ),
                          if (msg.queued)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: msg.state == 'failed'
                                  ? GestureDetector(
                                      onTap: () => _retryMessage(msg),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            'Gagal diproses.',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: isUser
                                                  ? Colors.white70
                                                  : ThemeColors.textMuted(dark),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            'Coba Lagi',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w800,
                                              color: isUser
                                                  ? Colors.white
                                                  : ThemeColors.accentExpense(
                                                      dark,
                                                    ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    )
                                  : Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const SizedBox(
                                          width: 12,
                                          height: 12,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Menunggu koneksi...',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: isUser
                                                ? Colors.white70
                                                : ThemeColors.textMuted(dark),
                                          ),
                                        ),
                                      ],
                                    ),
                            ),
                          if (payloadObj != null && payloadObj['type'] == 'draft_tx')
                            _DraftTransactionCard(
                              msgId: msg.id,
                              data: payloadObj['data'] as Map<String, dynamic>,
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            // Input bar
            Container(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
              decoration: BoxDecoration(
                color: ThemeColors.card(dark),
                border: Border(
                  top: BorderSide(color: ThemeColors.border(dark)),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_consentLoaded && !_consentAccepted)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          AppIcon(
                            'circle-alert',
                            size: 14,
                            color: ThemeColors.accentWarning(dark),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Butuh izin Anda untuk mengirim data ke asisten AI.',
                              style: TextStyle(
                                fontSize: 11,
                                color: ThemeColors.textSecondary(dark),
                              ),
                            ),
                          ),
                          GestureDetector(
                            onTap: _ensureConsent,
                            child: Text(
                              'Setujui',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: ThemeColors.accentExpense(dark),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _inputController,
                          onSubmitted: (_) => _handleSend(),
                          style: TextStyle(
                            color: ThemeColors.textPrimary(dark),
                          ),
                          decoration: InputDecoration(
                            hintText: 'Tanya soal keuangan Anda...',
                            hintStyle: TextStyle(
                              color: ThemeColors.textMuted(dark),
                            ),
                            filled: true,
                            fillColor: ThemeColors.secondaryCard(dark),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      GestureDetector(
                        onTap: _isSending ? null : _handleSend,
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: _isSending
                                ? ThemeColors.border(dark)
                                : ThemeColors.fillExpense,
                            shape: BoxShape.circle,
                          ),
                          child: AppIcon('send', size: 20, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TypingBubble extends StatefulWidget {
  const _TypingBubble();

  @override
  State<_TypingBubble> createState() => _TypingBubbleState();
}

class _TypingBubbleState extends State<_TypingBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = ThemeStore.instance.isDarkMode;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: ThemeColors.card(dark),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
          bottomLeft: Radius.circular(4),
          bottomRight: Radius.circular(16),
        ),
        border: Border.all(color: ThemeColors.border(dark)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(3, (i) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: FadeTransition(
              opacity: Tween<double>(begin: 0.25, end: 1).animate(
                CurvedAnimation(
                  parent: _controller,
                  curve: Interval(
                    i / 3,
                    (i + 2) / 3,
                    curve: Curves.easeInOut,
                  ),
                ),
              ),
              child: Container(
                width: 7,
                height: 7,
                decoration: const BoxDecoration(
                  color: Color(0xFFE06D53),
                  shape: BoxShape.circle,
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _DraftTransactionCard extends StatefulWidget {
  final String msgId;
  final Map<String, dynamic> data;

  const _DraftTransactionCard({required this.msgId, required this.data});

  @override
  State<_DraftTransactionCard> createState() => _DraftTransactionCardState();
}

class _DraftTransactionCardState extends State<_DraftTransactionCard> {
  bool _isSaving = false;
  bool _saved = false;

  Future<void> _handleSave() async {
    setState(() => _isSaving = true);
    try {
      final type = widget.data['tx_type'] as String? ?? 'expense';
      final amount = (widget.data['amount'] as num?)?.toDouble() ?? 0.0;
      final categoryId = widget.data['category_id'] as String?;
      final accountId = widget.data['account_id'] as String?;
      final note = widget.data['note'] as String?;
      final date = DateFormat('yyyy-MM-dd').format(DateTime.now());

      if (accountId != null) {
        await TransactionStore.instance.addTransaction(
          accountId: accountId,
          categoryId: categoryId,
          amount: amount,
          type: type,
          note: note,
          date: date,
        );
        setState(() => _saved = true);
        await ChatStore.instance.update(widget.msgId, payload: null);
      }
    } catch (e) {
      debugPrint('Save error: $e');
    }
    if (mounted) setState(() => _isSaving = false);
  }
  
  void _handleCancel() {
    ChatStore.instance.update(widget.msgId, payload: null);
  }

  @override
  Widget build(BuildContext context) {
    if (_saved) return const SizedBox.shrink();
    final dark = ThemeStore.instance.isDarkMode;
    final type = widget.data['tx_type'] as String? ?? 'expense';
    final amount = (widget.data['amount'] as num?)?.toDouble() ?? 0.0;
    final catName = widget.data['category_name_fallback'] as String? ?? 'Unknown';
    
    final fmt = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp', decimalDigits: 0);

    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ThemeColors.bg(dark),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ThemeColors.border(dark)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AppIcon(type == 'income' ? 'arrow-down-left' : 'arrow-up-right', 
                  size: 16, 
                  color: type == 'income' ? ThemeColors.accentIncome(dark) : ThemeColors.accentExpense(dark)),
              const SizedBox(width: 8),
              Text(
                'Draft Transaksi',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: ThemeColors.textPrimary(dark),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            fmt.format(amount),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: ThemeColors.textPrimary(dark),
            ),
          ),
          Text(
            catName,
            style: TextStyle(
              fontSize: 12,
              color: ThemeColors.textSecondary(dark),
            ),
          ),
          if (widget.data['note'] != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                widget.data['note'],
                style: TextStyle(
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                  color: ThemeColors.textMuted(dark),
                ),
              ),
            ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: _isSaving ? null : _handleCancel,
                child: Text('Batal', style: TextStyle(color: ThemeColors.textMuted(dark), fontSize: 12)),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _isSaving ? null : _handleSave,
                style: ElevatedButton.styleFrom(
                  backgroundColor: ThemeColors.fillExpense,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  minimumSize: Size.zero,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: _isSaving 
                  ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Simpan', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
