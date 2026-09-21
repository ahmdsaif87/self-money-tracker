import 'package:flutter/material.dart';
import '../db/database.dart';
import '../stores/chat_store.dart';
import '../stores/ai_queue_store.dart';
import '../stores/theme_store.dart';
import '../stores/account_store.dart';
import '../stores/category_store.dart';
import '../models/models.dart';
import '../theme/theme.dart';
import '../components/app_icon.dart';
import 'dart:convert';
import 'package:intl/intl.dart';
import '../services/gemini_service.dart';
import '../services/ai_key.dart';
import '../stores/transaction_store.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
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
  bool _hasApiKey = true;

  @override
  void initState() {
    super.initState();
    ChatStore.instance.load();
    AIQueueStore.instance.fetchQueue();
    _checkApiKey();
    _ensureConsent();
    _processQueue();
  }

  Future<void> _checkApiKey() async {
    final key = await AIKeyService.getApiKey();
    if (mounted) setState(() => _hasApiKey = key != null && key.isNotEmpty);
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
        title: const Text('Share Data with AI Assistant?'),
        content: const Text(
          'To answer your questions, the app shares a financial summary '
          '(total balance, accounts, and 3-month category breakdown) with Google Gemini.\n\n'
          'Your data is stored offline on your device and only sent when you ask a question.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Decline'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Accept'),
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
          0.0, // Karena reverse: true, titik 0.0 adalah yang paling bawah
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
      response = 'Encountered an issue reaching AI assistant. Please try again later.';
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

  Widget _buildTemplateChip(String label, String templateText, bool dark) {
    return GestureDetector(
      onTap: () {
        _inputController.text = templateText;
        _inputController.selection = TextSelection.fromPosition(
          TextPosition(offset: templateText.length),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: ThemeColors.secondaryCard(dark),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: ThemeColors.border(dark)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: ThemeColors.textSecondary(dark),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ThemeStore.instance,
      builder: (context, _) {
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
                              'AI Financial Assistant',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: ThemeColors.textPrimary(dark),
                              ),
                            ),
                            Text(
                              'Analyze your personal finances',
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
                    'Your financial summary is shared securely with Google for processing.',
                    style: TextStyle(
                      fontSize: 11,
                      color: ThemeColors.textMuted(dark),
                    ),
                  ),
                ),

                if (!_hasApiKey)
                  Container(
                    margin: const EdgeInsets.fromLTRB(20, 8, 20, 4),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade100,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.amber.shade400),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.key, color: Colors.amber.shade900, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Gemini API Key is not configured in Settings. Questions will be queued offline.',
                            style: TextStyle(fontSize: 11, color: Colors.amber.shade900, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),

                // Messages
                Expanded(
                  child: ListView.builder(
                    controller: _scrollController,
                    reverse: true, // Auto-scroll ke bawah saat dibuka
                    padding: const EdgeInsets.all(20),
                    itemCount: messages.length + (_isSending ? 1 : 0),
                    itemBuilder: (context, index) {
                      // Karena reverse, index 0 adalah pesan paling baru (atau typing bubble jika sedang mengirim)
                      if (_isSending && index == 0) {
                        return const Align(
                          alignment: Alignment.centerLeft,
                          child: _TypingBubble(),
                        );
                      }
                      
                      // Sesuaikan indeks: pesan terbaru ada di akhir list `messages`
                      // Jika _isSending true, item 0 adalah bubble, jadi pesan asli digeser 1 (index - 1)
                      final msgIndex = messages.length - 1 - (index - (_isSending ? 1 : 0));
                      final msg = messages[msgIndex];
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
                              MarkdownBody(
                                data: msg.text,
                                styleSheet: MarkdownStyleSheet(
                                  p: TextStyle(
                                    fontSize: 14,
                                    height: 1.4,
                                    color: isUser
                                        ? Colors.white
                                        : ThemeColors.textPrimary(dark),
                                  ),
                                  strong: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: isUser
                                        ? Colors.white
                                        : ThemeColors.textPrimary(dark),
                                  ),
                                  listBullet: TextStyle(
                                    color: isUser
                                        ? Colors.white
                                        : ThemeColors.textPrimary(dark),
                                  ),
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
                                                'Processing failed.',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: isUser
                                                      ? Colors.white70
                                                      : ThemeColors.textMuted(dark),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                'Retry',
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
                                              'Waiting for connection...',
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
                      // Quick Template Chips
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            _buildTemplateChip('+ Expense', 'Expense 50.000 for ', dark),
                            const SizedBox(width: 6),
                            _buildTemplateChip('+ Income', 'Income 1.000.000 for ', dark),
                            const SizedBox(width: 6),
                            _buildTemplateChip('+ Transfer', 'Transfer 100.000 from Cash to ', dark),
                          ],
                        ),
                      ),
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
                                  'Requires your permission to send data to AI assistant.',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: ThemeColors.textSecondary(dark),
                                  ),
                                ),
                              ),
                              GestureDetector(
                                onTap: _ensureConsent,
                                child: Text(
                                  'Accept',
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
                                hintText: 'Ask anything about your finances...',
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
      },
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
                    i * 0.2,
                    0.6 + (i * 0.2),
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
  late String? _selectedCategoryId;
  late String? _selectedAccountId;

  @override
  void initState() {
    super.initState();
    final type = widget.data['tx_type'] as String? ?? 'expense';
    _selectedCategoryId = widget.data['category_id'] as String?;
    if (_selectedCategoryId == null && type != 'transfer') {
      final cats = CategoryStore.instance.categories.where((c) => c.type == type).toList();
      _selectedCategoryId = cats.firstOrNull?.id;
    }

    _selectedAccountId = widget.data['account_id'] as String?;
    if (_selectedAccountId == null || _selectedAccountId!.isEmpty) {
      _selectedAccountId = AccountStore.instance.accounts.firstOrNull?.id;
    }
  }

  Future<void> _handleSave() async {
    setState(() => _isSaving = true);
    try {
      final type = widget.data['tx_type'] as String? ?? 'expense';
      final amount = (widget.data['amount'] as num?)?.toDouble() ?? 0.0;
      final categoryId = _selectedCategoryId;
      var accountId = _selectedAccountId;

      if (accountId == null || accountId.isEmpty) {
        final accs = AccountStore.instance.accounts;
        if (accs.isNotEmpty) accountId = accs.first.id;
      }

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

    final accounts = AccountStore.instance.accounts;
    final categories = CategoryStore.instance.categories.where((c) => c.type == type).toList();

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
                'Draft Transaction',
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
          const SizedBox(height: 8),

          // Interactive Selectors
          if (type != 'transfer') ...[
            DropdownButtonFormField<String>(
              initialValue: categories.any((c) => c.id == _selectedCategoryId) ? _selectedCategoryId : null,
              decoration: InputDecoration(
                labelText: 'Category',
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
              style: TextStyle(fontSize: 12, color: ThemeColors.textPrimary(dark)),
              items: categories.map((c) => DropdownMenuItem(
                value: c.id,
                child: Text(c.name, style: TextStyle(color: ThemeColors.textPrimary(dark))),
              )).toList(),
              onChanged: (val) => setState(() => _selectedCategoryId = val),
            ),
            const SizedBox(height: 8),
          ],

          DropdownButtonFormField<String>(
            initialValue: accounts.any((a) => a.id == _selectedAccountId) ? _selectedAccountId : null,
            decoration: InputDecoration(
              labelText: 'Account',
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
            style: TextStyle(fontSize: 12, color: ThemeColors.textPrimary(dark)),
            items: accounts.map((a) => DropdownMenuItem(
              value: a.id,
              child: Text(a.name, style: TextStyle(color: ThemeColors.textPrimary(dark))),
            )).toList(),
            onChanged: (val) => setState(() => _selectedAccountId = val),
          ),

          if (widget.data['note'] != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
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
                child: Text('Cancel', style: TextStyle(color: ThemeColors.textMuted(dark), fontSize: 12)),
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
                  : const Text('Save', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
