import 'package:flutter/foundation.dart';
import '../db/database.dart';
import '../models/models.dart' show Transaction;
import 'account_store.dart';

/// Transaction store — mirrors src/store/useTransactionStore.ts
/// Keeps account balances in sync (delta apply on add/update/delete).
class TransactionStore extends ChangeNotifier {
  TransactionStore._();
  static final TransactionStore instance = TransactionStore._();

  List<Transaction> _transactions = [];
  bool _isLoading = false;

  List<Transaction> get transactions => _transactions;
  bool get isLoading => _isLoading;

  /// --- Paginated per-month cache (DB-level filtering, not in-memory). ---
  static const int monthPageSize = 30;
  final Map<String, List<Transaction>> _monthCache = {};
  final Map<String, int> _monthTotal = {};

  String _monthCacheKey(String monthKey, String? type, String? search) {
    final t = (type == null || type.isEmpty) ? 'semua' : type;
    final s = (search ?? '').trim().toLowerCase();
    return '$monthKey|$t|$s';
  }

  /// Fetch one page for a month filter straight from SQLite.
  /// Returns (items, total, hasMore). Results are cached per page-0 key
  /// and extended as further pages load.
  Future<({List<Transaction> items, int total, bool hasMore})> fetchMonthPage(
    String monthKey, {
    String? type,
    String? search,
    int limit = monthPageSize,
    int offset = 0,
  }) async {
    final items = await DB.instance.fetchTransactionsByMonth(
      monthKey,
      type: type,
      search: search,
      limit: limit,
      offset: offset,
    );
    final total = await DB.instance.countTransactionsByMonth(
      monthKey,
      type: type,
      search: search,
    );
    final hasMore = offset + items.length < total;
    final key = _monthCacheKey(monthKey, type, search);
    if (offset == 0) {
      _monthCache[key] = items;
    } else {
      final existing = _monthCache[key] ?? [];
      _monthCache[key] = [...existing, ...items];
    }
    _monthTotal[key] = total;
    return (items: items, total: total, hasMore: hasMore);
  }

  /// Cached items for a month filter (empty if not yet fetched).
  List<Transaction> cachedMonth(String monthKey, {String? type, String? search}) {
    return _monthCache[_monthCacheKey(monthKey, type, search)] ?? [];
  }

  int? cachedMonthTotal(String monthKey, {String? type, String? search}) {
    return _monthTotal[_monthCacheKey(monthKey, type, search)];
  }

  void _invalidateMonthCache() {
    _monthCache.clear();
    _monthTotal.clear();
  }

  /// Public hook for bulk writes that bypass add/update/delete
  /// (e.g. XLSX import) so paged month views don't go stale.
  void invalidateMonthCache() => _invalidateMonthCache();

  /// SQL-side search across all dates (for AI tools) — capped LIMIT.
  Future<List<Transaction>> searchTransactions(String keyword, {int limit = 10}) {
    return DB.instance.searchTransactions(keyword, limit: limit);
  }

  /// SQL-side match count for a keyword search (for AI tools).
  Future<int> countSearchTransactions(String keyword) {
    return DB.instance.countSearchTransactions(keyword);
  }

  /// SQL-side summary for an arbitrary date range (for AI tools).
  Future<({double income, double expense})> summaryByDateRange(
    String startDate,
    String endDate,
  ) {
    return DB.instance.fetchSummaryByDateRange(startDate, endDate);
  }

  /// SQL-side per-category breakdown for an arbitrary date range (for AI tools).
  Future<List<({String key, String name, double amount, String type, String color, String icon})>>
      categoryBreakdownByDateRange(String startDate, String endDate) {
    return DB.instance.fetchCategoryBreakdownByDateRange(startDate, endDate);
  }

  /// SQL-side aggregations (no Dart fold over the full table).
  Future<({double income, double expense})> monthlySummary(String monthKey) {
    return DB.instance.fetchMonthlySummary(monthKey);
  }

  Future<List<({String key, String name, double amount, String type, String color, String icon})>>
      categoryBreakdown(String monthKey, String type) {
    return DB.instance.fetchCategoryBreakdown(monthKey, type);
  }

  Future<List<({String key, double income, double expense})>> monthlyTrends(
    String endMonthKey, [
    int count = 6,
  ]) {
    return DB.instance.fetchMonthlyTrends(endMonthKey, count);
  }

  double _deltaForAccount(Transaction tx, String accountId) {
    if (tx.type == 'income') return tx.accountId == accountId ? tx.amount : 0;
    if (tx.type == 'expense') return tx.accountId == accountId ? -tx.amount : 0;
    if (tx.type == 'transfer') {
      if (tx.accountId == accountId) return -tx.amount;
      if (tx.toAccountId == accountId) return tx.amount;
      return 0;
    }
    return 0;
  }

  Future<void> _applyBalanceChanges(Map<String, double> amounts) async {
    final ids = amounts.keys.toList();
    if (ids.isEmpty) return;
    final placeholders = List.filled(ids.length, '?').join(',');
    final rows = await DB.instance.db.query(
      'accounts',
      where: 'id IN ($placeholders)',
      whereArgs: ids,
    );
    for (final row in rows) {
      final accId = row['id'] as String;
      final delta = amounts[accId] ?? 0;
      final newBalance = ((row['balance'] as num).toDouble() + delta).roundToDouble();
      await DB.instance.db.update(
        'accounts',
        {'balance': newBalance, 'updated_at': DateTime.now().toIso8601String()},
        where: 'id = ?',
        whereArgs: [accId],
      );
    }
  }

  Future<void> fetchTransactions() async {
    _isLoading = true;
    notifyListeners();
    try {
      _transactions = await DB.instance.fetchTransactions().then(
            (list) => list.map((t) => Transaction.fromMap(t.toMap())).toList(),
          );
    } catch (e) {
      debugPrint('Error fetching transactions: $e');
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<Transaction> addTransaction({
    required String accountId,
    String? toAccountId,
    String? categoryId,
    required double amount,
    required String type,
    String? note,
    required String date,
  }) async {
    final now = DateTime.now().toIso8601String();
    final newTx = Transaction(
      id: 'tx_${DateTime.now().millisecondsSinceEpoch}_${_rand(5)}',
      accountId: accountId,
      toAccountId: type == 'transfer' ? toAccountId : null,
      categoryId: type == 'transfer' ? null : categoryId,
      amount: amount,
      type: type,
      note: note,
      date: date,
      createdAt: now,
      updatedAt: now,
    );
    await DB.instance.db.insert('transactions', newTx.toMap());

    final amounts = <String, double>{};
    final affected = <String>[newTx.accountId];
    if (newTx.type == 'transfer' && newTx.toAccountId != null) affected.add(newTx.toAccountId!);
    for (final id in affected) {
      amounts[id] = _deltaForAccount(newTx, id);
    }
    await _applyBalanceChanges(amounts);

    _invalidateMonthCache();
    await fetchTransactions();
    await AccountStore.instance.fetchAccounts();
    return newTx;
  }

  Future<void> updateTransaction(
    String id, {
    required String accountId,
    String? toAccountId,
    String? categoryId,
    required double amount,
    required String type,
    String? note,
    required String date,
  }) async {
    final rows = await DB.instance.db.query('transactions', where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return;
    final existing = Transaction.fromMap(rows.first);

    final next = Transaction(
      id: id,
      accountId: accountId,
      toAccountId: type == 'transfer' ? toAccountId : null,
      categoryId: type == 'transfer' ? null : categoryId,
      amount: amount,
      type: type,
      note: note,
      date: date,
      createdAt: existing.createdAt,
      updatedAt: DateTime.now().toIso8601String(),
    );

    // Revert old effect, then apply new effect on every affected account.
    final affectedIds = <String>{};
    for (final accId in [existing.accountId, existing.toAccountId, next.accountId, next.toAccountId]) {
      if (accId != null) affectedIds.add(accId);
    }
    final amounts = <String, double>{};
    for (final accId in affectedIds) {
      amounts[accId] = -_deltaForAccount(existing, accId) + _deltaForAccount(next, accId);
    }
    await _applyBalanceChanges(amounts);

    await DB.instance.db.update(
      'transactions',
      {
        'account_id': next.accountId,
        'to_account_id': next.toAccountId,
        'category_id': next.categoryId,
        'amount': next.amount,
        'type': next.type,
        'note': next.note,
        'date': next.date,
        'updated_at': next.updatedAt,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
    _invalidateMonthCache();
    await fetchTransactions();
    await AccountStore.instance.fetchAccounts();
  }

  Future<void> deleteTransaction(String id) async {
    final rows = await DB.instance.db.query('transactions', where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isNotEmpty) {
      final existing = Transaction.fromMap(rows.first);
      final affectedIds = <String>{existing.accountId};
      if (existing.toAccountId != null) affectedIds.add(existing.toAccountId!);
      final amounts = <String, double>{};
      for (final accId in affectedIds) {
        amounts[accId] = -_deltaForAccount(existing, accId);
      }
      await _applyBalanceChanges(amounts);
    }
    await DB.instance.db.delete('transactions', where: 'id = ?', whereArgs: [id]);
    _invalidateMonthCache();
    await fetchTransactions();
    await AccountStore.instance.fetchAccounts();
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
