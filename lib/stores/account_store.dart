import 'package:flutter/foundation.dart';
import '../db/database.dart';
import '../models/models.dart' show Account;

/// Account store — mirrors src/store/useAccountStore.ts
class AccountStore extends ChangeNotifier {
  AccountStore._();
  static final AccountStore instance = AccountStore._();

  List<Account> _accounts = [];
  bool _isLoading = false;

  List<Account> get accounts => _accounts;
  bool get isLoading => _isLoading;

  Future<void> fetchAccounts() async {
    _isLoading = true;
    notifyListeners();
    try {
      _accounts = await DB.instance.fetchAccounts();
    } catch (e) {
      debugPrint('Error fetching accounts: $e');
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<Account> addAccount({
    required String name,
    required String type,
    required double balance,
    required String color,
    required String icon,
  }) async {
    final now = DateTime.now().toIso8601String();
    final newAcc = Account(
      id: 'acc_${DateTime.now().millisecondsSinceEpoch}_${_rand(5)}',
      name: name,
      type: type,
      balance: balance,
      color: color,
      icon: icon,
      createdAt: now,
      updatedAt: now,
    );
    await DB.instance.db.insert('accounts', newAcc.toMap());
    await fetchAccounts();
    return newAcc;
  }

  Future<void> updateAccount(
    String id, {
    String? name,
    String? type,
    double? balance,
    String? color,
    String? icon,
  }) async {
    final updates = <String, dynamic>{
      'updated_at': DateTime.now().toIso8601String(),
      'name': ?name,
      'type': ?type,
      'balance': ?balance,
      'color': ?color,
      'icon': ?icon,
    };
    await DB.instance.db.update(
      'accounts',
      updates,
      where: 'id = ?',
      whereArgs: [id],
    );
    await fetchAccounts();
  }

  Future<void> deleteAccount(String id) async {
    await DB.instance.db.delete('accounts', where: 'id = ?', whereArgs: [id]);
    await fetchAccounts();
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
