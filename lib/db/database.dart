import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show Platform;
import 'package:sqflite/sqflite.dart' hide Transaction;
import 'package:sqflite_common_ffi/sqflite_ffi.dart' hide Transaction;
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';
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
    if (kIsWeb) {
      databaseFactory = databaseFactoryFfiWeb;
    } else if (!Platform.isAndroid && !Platform.isIOS) {
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
        // Perf indexes: month filtering (date prefix), type grouping, ordering.
        await db.execute('CREATE INDEX IF NOT EXISTS idx_tx_date ON transactions(date);');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_tx_type_date ON transactions(type, date);');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_tx_account ON transactions(account_id);');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_tx_category ON transactions(category_id);');
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

        // Perf indexes for existing installs (safe: IF NOT EXISTS).
        await db.execute('CREATE INDEX IF NOT EXISTS idx_tx_date ON transactions(date);');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_tx_type_date ON transactions(type, date);');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_tx_account ON transactions(account_id);');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_tx_category ON transactions(category_id);');
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
      ['cat_groceries', 'Groceries', 'expense', 'shopping-cart', '#E06D53'],
      ['cat_dining', 'Dining Out', 'expense', 'utensils', '#E58A75'],
      ['cat_bills', 'Bills & Utilities', 'expense', 'file-text', '#C8543B'],
      ['cat_transport', 'Transport', 'expense', 'car', '#D97C65'],
      ['cat_shopping', 'Shopping', 'expense', 'shopping-bag', '#F0907A'],
      ['cat_health', 'Health & Medical', 'expense', 'heart', '#B84C34'],
      ['cat_entertainment', 'Entertainment', 'expense', 'film', '#587D63'],
      ['cat_other', 'Other Expenses', 'expense', 'tag', '#8C827A'],
      ['cat_salary', 'Salary', 'income', 'briefcase', '#7FA98B'],
      ['cat_freelance', 'Freelance', 'income', 'laptop', '#97BC9F'],
      ['cat_investments', 'Investments', 'income', 'trending-up', '#587D63'],
      ['cat_gift', 'Gifts & Rewards', 'income', 'gift', '#D97C65'],
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

  /// --- Perf-optimized queries: filter/aggregate in SQLite, not in Dart. ---

  /// Fetch one month (YYYY-MM) with optional type + search, paginated.
  /// Search matches note / category name / account name via JOINs.
  Future<List<Transaction>> fetchTransactionsByMonth(
    String monthKey, {
    String? type, // 'expense' | 'income' | 'transfer' | null = all
    String? search,
    int? limit,
    int? offset,
  }) async {
    final where = <String>['t.date LIKE ?'];
    final args = <Object?>['$monthKey-%'];
    if (type != null && type.isNotEmpty && type != 'semua') {
      where.add('t.type = ?');
      args.add(type);
    }
    final q = search?.trim().toLowerCase();
    if (q != null && q.isNotEmpty) {
      where.add('('
          'LOWER(t.note) LIKE ? OR '
          'LOWER(c.name) LIKE ? OR '
          'LOWER(a.name) LIKE ?'
          ')');
      final like = '%$q%';
      args.addAll([like, like, like]);
    }
    final rows = await db.rawQuery('''
      SELECT t.* FROM transactions t
      LEFT JOIN categories c ON c.id = t.category_id
      LEFT JOIN accounts a ON a.id = t.account_id
      WHERE ${where.join(' AND ')}
      ORDER BY t.date DESC, t.created_at DESC
      ${limit != null ? 'LIMIT ?' : ''}
      ${offset != null ? 'OFFSET ?' : ''}
    ''', [
      ...args,
      ...?limit == null ? null : [limit],
      ...?offset == null ? null : [offset],
    ]);
    return rows.map(Transaction.fromMap).toList();
  }

  /// Count rows for a month filter (for pagination hasMore).
  Future<int> countTransactionsByMonth(
    String monthKey, {
    String? type,
    String? search,
  }) async {
    final where = <String>['t.date LIKE ?'];
    final args = <Object?>['$monthKey-%'];
    if (type != null && type.isNotEmpty && type != 'semua') {
      where.add('t.type = ?');
      args.add(type);
    }
    final q = search?.trim().toLowerCase();
    if (q != null && q.isNotEmpty) {
      where.add('('
          'LOWER(t.note) LIKE ? OR '
          'LOWER(c.name) LIKE ? OR '
          'LOWER(a.name) LIKE ?'
          ')');
      final like = '%$q%';
      args.addAll([like, like, like]);
    }
    final rows = await db.rawQuery('''
      SELECT COUNT(*) AS cnt FROM transactions t
      LEFT JOIN categories c ON c.id = t.category_id
      LEFT JOIN accounts a ON a.id = t.account_id
      WHERE ${where.join(' AND ')}
    ''', args);
    if (rows.isEmpty) return 0;
    return (rows.first['cnt'] as num?)?.toInt() ?? 0;
  }

  /// Monthly income/expense totals via SQL SUM (no Dart fold over thousands of rows).
  Future<({double income, double expense})> fetchMonthlySummary(String monthKey) async {
    final rows = await db.rawQuery('''
      SELECT type, SUM(amount) AS total FROM transactions
      WHERE date LIKE ? AND type IN ('income', 'expense')
      GROUP BY type
    ''', ['$monthKey-%']);
    double income = 0, expense = 0;
    for (final r in rows) {
      final total = (r['total'] as num?)?.toDouble() ?? 0;
      if (r['type'] == 'income') {
        income = total;
      } else if (r['type'] == 'expense') {
        expense = total;
      }
    }
    return (income: income, expense: expense);
  }

  /// Per-category totals for a month + type (for donut breakdown).
  Future<List<({String key, String name, double amount, String type, String color, String icon})>>
      fetchCategoryBreakdown(String monthKey, String type) async {
    final rows = await db.rawQuery('''
      SELECT
        COALESCE(t.category_id, 'none') AS ckey,
        COALESCE(c.name, 'Uncategorized') AS cname,
        COALESCE(c.color, '#E06D53') AS ccolor,
        COALESCE(c.icon, 'tag') AS cicon,
        SUM(t.amount) AS total
      FROM transactions t
      LEFT JOIN categories c ON c.id = t.category_id
      WHERE t.date LIKE ? AND t.type = ?
      GROUP BY ckey
      ORDER BY total DESC
    ''', ['$monthKey-%', type]);
    return rows
        .map((r) => (
              key: r['ckey'] as String,
              name: r['cname'] as String,
              amount: (r['total'] as num?)?.toDouble() ?? 0,
              type: type,
              color: r['ccolor'] as String,
              icon: r['cicon'] as String,
            ))
        .toList();
  }

  /// N-month income/expense trend ending at [endMonthKey] (YYYY-MM), 1 query.
  Future<List<({String key, double income, double expense})>> fetchMonthlyTrends(
    String endMonthKey,
    int count,
  ) async {
    // Compute month keys in Dart (cheap), aggregate in one SQL GROUP BY.
    final parts = endMonthKey.split('-');
    final y = int.parse(parts[0]);
    final m = int.parse(parts[1]);
    final keys = <String>[];
    for (int i = count - 1; i >= 0; i--) {
      final dt = DateTime(y, m - i, 1);
      keys.add('${dt.year}-${dt.month.toString().padLeft(2, '0')}');
    }
    final placeholders = List.filled(keys.length, '?').join(',');
    final prefixArgs = keys.map((k) => '$k-%').toList();
    final rows = await db.rawQuery('''
      SELECT SUBSTR(date, 1, 7) AS mkey, type, SUM(amount) AS total
      FROM transactions
      WHERE type IN ('income', 'expense')
        AND (${keys.map((_) => 'date LIKE ?').join(' OR ')})
      GROUP BY mkey, type
    ''', prefixArgs);
    // Avoid unused-var lint if query shape changes.
    assert(placeholders.isNotEmpty);
    final map = <String, ({double income, double expense})>{for (final k in keys) k: (income: 0, expense: 0)};
    for (final r in rows) {
      final k = r['mkey'] as String?;
      if (k == null || !map.containsKey(k)) continue;
      final total = (r['total'] as num?)?.toDouble() ?? 0;
      final cur = map[k]!;
      if (r['type'] == 'income') {
        map[k] = (income: total, expense: cur.expense);
      } else if (r['type'] == 'expense') {
        map[k] = (income: cur.income, expense: total);
      }
    }
    return [for (final k in keys) (key: k, income: map[k]!.income, expense: map[k]!.expense)];
  }

  /// Keyword search across ALL dates (for AI tools) — capped with LIMIT.
  /// Matches note / category name / account name via JOINs.
  Future<List<Transaction>> searchTransactions(String keyword, {int limit = 10}) async {
    final q = keyword.trim().toLowerCase();
    final safeLimit = limit.clamp(1, 50);
    if (q.isEmpty) {
      final rows = await db.query(
        'transactions',
        orderBy: 'date DESC, created_at DESC',
        limit: safeLimit,
      );
      return rows.map(Transaction.fromMap).toList();
    }
    final like = '%$q%';
    final rows = await db.rawQuery('''
      SELECT t.* FROM transactions t
      LEFT JOIN categories c ON c.id = t.category_id
      LEFT JOIN accounts a ON a.id = t.account_id
      WHERE LOWER(t.note) LIKE ? OR LOWER(c.name) LIKE ? OR LOWER(a.name) LIKE ?
      ORDER BY t.date DESC, t.created_at DESC
      LIMIT ?
    ''', [like, like, like, safeLimit]);
    return rows.map(Transaction.fromMap).toList();
  }

  /// Count matches for a keyword search across all dates (for AI tools).
  Future<int> countSearchTransactions(String keyword) async {
    final q = keyword.trim().toLowerCase();
    if (q.isEmpty) {
      final rows = await db.rawQuery('SELECT COUNT(*) AS cnt FROM transactions');
      if (rows.isEmpty) return 0;
      return (rows.first['cnt'] as num?)?.toInt() ?? 0;
    }
    final like = '%$q%';
    final rows = await db.rawQuery('''
      SELECT COUNT(*) AS cnt FROM transactions t
      LEFT JOIN categories c ON c.id = t.category_id
      LEFT JOIN accounts a ON a.id = t.account_id
      WHERE LOWER(t.note) LIKE ? OR LOWER(c.name) LIKE ? OR LOWER(a.name) LIKE ?
    ''', [like, like, like]);
    if (rows.isEmpty) return 0;
    return (rows.first['cnt'] as num?)?.toInt() ?? 0;
  }

  /// Income/expense totals for an arbitrary date range (YYYY-MM-DD, inclusive).
  Future<({double income, double expense})> fetchSummaryByDateRange(
    String startDate,
    String endDate,
  ) async {
    final rows = await db.rawQuery('''
      SELECT type, SUM(amount) AS total FROM transactions
      WHERE date >= ? AND date <= ? AND type IN ('income', 'expense')
      GROUP BY type
    ''', [startDate, endDate]);
    double income = 0, expense = 0;
    for (final r in rows) {
      final total = (r['total'] as num?)?.toDouble() ?? 0;
      if (r['type'] == 'income') {
        income = total;
      } else if (r['type'] == 'expense') {
        expense = total;
      }
    }
    return (income: income, expense: expense);
  }

  /// Per-category totals for an arbitrary date range (YYYY-MM-DD, inclusive).
  Future<List<({String key, String name, double amount, String type, String color, String icon})>>
      fetchCategoryBreakdownByDateRange(String startDate, String endDate) async {
    final rows = await db.rawQuery('''
      SELECT
        COALESCE(t.category_id, 'none') AS ckey,
        COALESCE(c.name, 'Uncategorized') AS cname,
        COALESCE(c.color, '#E06D53') AS ccolor,
        COALESCE(c.icon, 'tag') AS cicon,
        t.type AS ttype,
        SUM(t.amount) AS total
      FROM transactions t
      LEFT JOIN categories c ON c.id = t.category_id
      WHERE t.date >= ? AND t.date <= ? AND t.type IN ('income', 'expense')
      GROUP BY ckey, ttype
      ORDER BY total DESC
    ''', [startDate, endDate]);
    return rows
        .map((r) => (
              key: r['ckey'] as String,
              name: r['cname'] as String,
              amount: (r['total'] as num?)?.toDouble() ?? 0,
              type: r['ttype'] as String,
              color: r['ccolor'] as String,
              icon: r['cicon'] as String,
            ))
        .toList();
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
