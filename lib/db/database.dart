import 'dart:io' show Platform;
import 'package:sqflite/sqflite.dart' hide Transaction;
import 'package:sqflite_common_ffi/sqflite_ffi.dart' hide Transaction;
import 'package:path/path.dart' as p;
import '../models/models.dart';

/// Database client mirroring src/db/client.ts (Expo SQLite + drizzle).
/// Uses raw SQL (same schema as the RN app) so an existing money_tracker.db
/// would remain compatible.
class DB {
  DB._();
  static final DB instance = DB._();
  Database? _db;

  Database get db {
    final d = _db;
    if (d == null) throw StateError('Database not initialized. Call initDatabase() first.');
    return d;
  }

  Future<void> initDatabase() async {
    if (_db != null) return;
    // Desktop (Linux/macOS/Windows): sqflite_common_ffi required.
    if (!Platform.isAndroid && !Platform.isIOS) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }
    final dir = await getDatabasesPath();
    final path = p.join(dir, 'money_tracker.db');
    _db = await openDatabase(
      path,
      version: 2,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS accounts (
            id TEXT PRIMARY KEY NOT NULL,
            name TEXT NOT NULL,
            type TEXT NOT NULL,
            balance REAL NOT NULL DEFAULT 0,
            color TEXT DEFAULT '#7FA98B',
            icon TEXT DEFAULT 'wallet',
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL
          );
        ''');
        await db.execute('''
          CREATE TABLE IF NOT EXISTS categories (
            id TEXT PRIMARY KEY NOT NULL,
            name TEXT NOT NULL,
            type TEXT NOT NULL,
            icon TEXT NOT NULL,
            color TEXT DEFAULT '#E06D53',
            is_system INTEGER DEFAULT 1,
            created_at TEXT NOT NULL
          );
        ''');
        await db.execute('''
          CREATE TABLE IF NOT EXISTS transactions (
            id TEXT PRIMARY KEY NOT NULL,
            account_id TEXT NOT NULL,
            to_account_id TEXT,
            category_id TEXT,
            amount REAL NOT NULL,
            type TEXT NOT NULL,
            note TEXT,
            date TEXT NOT NULL,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL,
            FOREIGN KEY (account_id) REFERENCES accounts (id) ON DELETE CASCADE,
            FOREIGN KEY (category_id) REFERENCES categories (id)
          );
        ''');
        await db.execute('''
          CREATE TABLE IF NOT EXISTS ai_queue (
            id TEXT PRIMARY KEY NOT NULL,
            prompt TEXT NOT NULL,
            status TEXT NOT NULL DEFAULT 'pending',
            response TEXT,
            created_at TEXT NOT NULL
          );
        ''');
        await db.execute('''
          CREATE TABLE IF NOT EXISTS chat_messages (
            id TEXT PRIMARY KEY NOT NULL,
            sender TEXT NOT NULL,
            text TEXT NOT NULL,
            queued INTEGER DEFAULT 0,
            queue_id TEXT,
            state TEXT,
            payload TEXT,
            created_at TEXT NOT NULL
          );
        ''');
        await db.execute('''
          CREATE TABLE IF NOT EXISTS settings (
            key TEXT PRIMARY KEY NOT NULL,
            value TEXT NOT NULL
          );
        ''');
      },
      onUpgrade: (db, oldV, newV) async {
        // Migration: add to_account_id for transfers (pre-existing installs)
        final cols = await db.rawQuery('PRAGMA table_info(transactions)');
        final has = cols.any((c) => c['name'] == 'to_account_id');
        if (!has) {
          await db.execute('ALTER TABLE transactions ADD COLUMN to_account_id TEXT;');
        }
        
        final chatCols = await db.rawQuery('PRAGMA table_info(chat_messages)');
        final hasPayload = chatCols.any((c) => c['name'] == 'payload');
        if (!hasPayload) {
          await db.execute('ALTER TABLE chat_messages ADD COLUMN payload TEXT;');
        }
      },
    );
    await _seedDefaultCategories();
  }

  Future<void> _seedDefaultCategories() async {
    final count = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM categories'),
    );
    if (count != null && count > 0) return;

    final now = DateTime.now().toIso8601String();
    const defaults = [
      ['cat_groceries', 'Belanja Bulanan', 'expense', 'shopping-cart', '#E06D53'],
      ['cat_dining', 'Makan di Luar', 'expense', 'utensils', '#E58A75'],
      ['cat_bills', 'Tagihan & Utilitas', 'expense', 'file-text', '#C8543B'],
      ['cat_transport', 'Transportasi', 'expense', 'car', '#D97C65'],
      ['cat_shopping', 'Belanja', 'expense', 'shopping-bag', '#F0907A'],
      ['cat_health', 'Kesehatan', 'expense', 'heart', '#B84C34'],
      ['cat_entertainment', 'Hiburan', 'expense', 'film', '#587D63'],
      ['cat_other', 'Lainnya', 'expense', 'tag', '#8C827A'],
      ['cat_salary', 'Gaji', 'income', 'briefcase', '#7FA98B'],
      ['cat_freelance', 'Pekerjaan Lepas', 'income', 'laptop', '#97BC9F'],
      ['cat_investments', 'Hasil Investasi', 'income', 'trending-up', '#587D63'],
      ['cat_gift', 'Hadiah', 'income', 'gift', '#D97C65'],
    ];
    final batch = db.batch();
    for (final d in defaults) {
      batch.insert('categories', {
        'id': d[0],
        'name': d[1],
        'type': d[2],
        'icon': d[3],
        'color': d[4],
        'is_system': 1,
        'created_at': now,
      });
    }
    await batch.commit(noResult: true);
  }

  // ---- Settings helpers ----
  Future<String?> getSetting(String key) async {
    final rows = await db.query('settings', where: 'key = ?', whereArgs: [key], limit: 1);
    if (rows.isEmpty) return null;
    return rows.first['value'] as String?;
  }

  Future<void> setSetting(String key, String value) async {
    final existing = await getSetting(key);
    if (existing != null) {
      await db.update('settings', {'value': value}, where: 'key = ?', whereArgs: [key]);
    } else {
      await db.insert('settings', {'key': key, 'value': value});
    }
  }

  // ---- Queries ----
  Future<List<Account>> fetchAccounts() async {
    final rows = await db.query('accounts', orderBy: 'created_at ASC');
    return rows.map(Account.fromMap).toList();
  }

  Future<List<Category>> fetchCategories() async {
    final rows = await db.query('categories', orderBy: 'created_at ASC');
    return rows.map(Category.fromMap).toList();
  }

  Future<List<Transaction>> fetchTransactions() async {
    final rows = await db.query('transactions', orderBy: 'date DESC, created_at DESC');
    return rows.map(Transaction.fromMap).toList();
  }

  Future<List<AIQueueItem>> fetchAIQueue() async {
    final rows = await db.query('ai_queue', orderBy: 'created_at ASC');
    return rows.map(AIQueueItem.fromMap).toList();
  }

  Future<List<ChatMessage>> fetchChatMessages() async {
    final rows = await db.query('chat_messages', orderBy: 'created_at ASC');
    return rows.map(ChatMessage.fromMap).toList();
  }

  Future<void> wipeAll() async {
    final d = db;
    await d.delete('transactions');
    await d.delete('categories');
    await d.delete('accounts');
    await d.delete('ai_queue');
    await d.delete('chat_messages');
    await _seedDefaultCategories();
  }
}
