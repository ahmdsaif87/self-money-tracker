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
