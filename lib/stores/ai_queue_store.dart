import 'package:flutter/foundation.dart';
import '../db/database.dart';
import '../models/models.dart';

/// AI queue store — mirrors src/store/useAIQueueStore.ts
class AIQueueStore extends ChangeNotifier {
  AIQueueStore._();
  static final AIQueueStore instance = AIQueueStore._();

  List<AIQueueItem> _queue = [];

  List<AIQueueItem> get queue => _queue;

  Future<void> fetchQueue() async {
    try {
      _queue = await DB.instance.fetchAIQueue();
      notifyListeners();
    } catch (e) {
      debugPrint('Error fetching AI queue: $e');
    }
  }

  Future<AIQueueItem> addToQueue(String prompt) async {
    final newItem = AIQueueItem(
      id: 'ai_${DateTime.now().millisecondsSinceEpoch}_${_rand(5)}',
      prompt: prompt,
      status: 'pending',
      response: null,
      createdAt: DateTime.now().toIso8601String(),
    );
    await DB.instance.db.insert('ai_queue', newItem.toMap());
    await fetchQueue();
    return newItem;
  }

  Future<void> updateStatus(String id, String status, {String? response}) async {
    await DB.instance.db.update(
      'ai_queue',
      {'status': status, 'response': response},
      where: 'id = ?',
      whereArgs: [id],
    );
    await fetchQueue();
  }

  String _rand(int n) {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final r = StringBuffer();
    for (var i = 0; i < n; i++) {
      r.write(chars[DateTime.now().microsecondsSinceEpoch % chars.length]);
    }
    return r.toString();
  }
}
