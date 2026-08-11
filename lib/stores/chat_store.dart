import 'package:flutter/foundation.dart';
import '../db/database.dart';
import '../models/models.dart' show AIQueueItem, ChatMessage;
import 'ai_queue_store.dart';

/// Chat store — mirrors src/store/useChatStore.ts
class ChatStore extends ChangeNotifier {
  ChatStore._();
  static final ChatStore instance = ChatStore._();

  List<ChatMessage> _messages = [];
  bool _isLoading = false;

  List<ChatMessage> get messages => _messages;
  bool get isLoading => _isLoading;

  static const welcomeMessage = ChatMessage(
    id: 'msg_welcome',
    sender: 'ai',
    text:
        'Halo! Saya asisten keuangan Anda. Tanyakan ringkasan pengeluaran, analisis kategori, atau saldo Anda.',
  );

  Future<void> load() async {
    _isLoading = true;
    notifyListeners();
    try {
      final msgs = await DB.instance.fetchChatMessages();
      _messages = msgs.isNotEmpty ? msgs : [welcomeMessage];
    } catch (e) {
      debugPrint('Error loading chat messages: $e');
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<void> add(ChatMessage msg) async {
    _messages = [..._messages, msg];
    notifyListeners();
    try {
      await DB.instance.db.insert('chat_messages', {
        ...msg.toMap(),
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('Chat message save error: $e');
    }
  }

  Future<void> addMany(List<ChatMessage> msgs) async {
    final createdAt = DateTime.now().toIso8601String();
    final batch = DB.instance.db.batch();
    for (final m in msgs) {
      batch.insert('chat_messages', {...m.toMap(), 'created_at': createdAt});
    }
    await batch.commit(noResult: true);
    _messages = [..._messages, ...msgs];
    notifyListeners();
  }

  Future<void> update(String id, {String? state, String? payload}) async {
    final Map<String, dynamic> updates = {};
    if (state != null) updates['state'] = state;
    if (payload != null) updates['payload'] = payload;
    
    if (updates.isEmpty) return;
    
    await DB.instance.db.update(
      'chat_messages',
      updates,
      where: 'id = ?',
      whereArgs: [id],
    );
    _messages = _messages
        .map((m) => m.id == id ? m.copyWith(state: state, payload: payload) : m)
        .toList();
    notifyListeners();
  }

  /// Reflect the AI queue's latest status into queued chat messages.
  /// Completed queue items replace the placeholder text with the real answer.
  Future<void> reflectQueueState() async {
    final queue = AIQueueStore.instance.queue;
    final qMap = <String, AIQueueItem>{for (final q in queue) q.id: q};
    var changed = false;
    final updated = _messages.map((m) {
      if (!m.queued || m.queueId == null) return m;
      final item = qMap[m.queueId];
      if (item == null || item.status == m.state) return m;
      changed = true;
      if (item.status == 'completed') {
        return ChatMessage(
          id: m.id,
          sender: m.sender,
          text: item.response ?? m.text,
          queued: false,
          queueId: m.queueId,
          state: 'completed',
        );
      }
      return m.copyWith(state: item.status);
    }).toList();
    if (changed) {
      for (final m in updated) {
        await DB.instance.db.update(
          'chat_messages',
          m.toMap(),
          where: 'id = ?',
          whereArgs: [m.id],
        );
      }
      _messages = updated;
      notifyListeners();
    }
  }

  Future<void> clearAll() async {
    await DB.instance.db.delete('chat_messages');
    _messages = [welcomeMessage];
    notifyListeners();
  }
}
