import '../db/database.dart';
import '../models/models.dart';

/// Monthly summary — mirrors src/services/financeSummary.ts
class MonthlySummary {
  final String month; // YYYY-MM
  final double income;
  final double expense;
  final List<({String name, double amount, String type})> byCategory;

  MonthlySummary({
    required this.month,
    required this.income,
    required this.expense,
    required this.byCategory,
  });
}

class FinancialSummary {
  final double totalBalance;
  final List<({String name, double balance, String type})> accounts;
  final List<MonthlySummary> months;

  FinancialSummary({
    required this.totalBalance,
    required this.accounts,
    required this.months,
  });
}

class FinanceSummaryService {
  static Future<FinancialSummary> buildFinancialSummary({int monthCount = 3}) async {
    final db = DB.instance.db;
    final accRows = await db.query('accounts');
    final catRows = await db.query('categories');
    final txRows = await db.query('transactions');

    final accList = accRows.map(Account.fromMap).toList();
    final catList = catRows.map(Category.fromMap).toList();
    final txList = txRows.map(Transaction.fromMap).toList();

    final catMap = <String, Category>{for (final c in catList) c.id: c};

    final totalBalance = accList.fold<double>(0, (sum, a) => sum + a.balance);

    final now = DateTime.now();
    final months = <MonthlySummary>[];
    for (var i = monthCount - 1; i >= 0; i--) {
      final d = DateTime(now.year, now.month - i, 1);
      final key = '${d.year}-${d.month.toString().padLeft(2, '0')}';
      final inMonth = txList.where((tx) => tx.date.startsWith(key)).toList();

      final income = inMonth.where((tx) => tx.type == 'income').fold<double>(0, (s, tx) => s + tx.amount);
      final expense = inMonth.where((tx) => tx.type == 'expense').fold<double>(0, (s, tx) => s + tx.amount);

      final byCat = <String, ({String name, double amount, String type})>{};
      for (final tx in inMonth) {
        if (tx.type == 'transfer') continue;
        final name = tx.categoryId != null
            ? (catMap[tx.categoryId]?.name ?? 'Tanpa kategori')
            : 'Tanpa kategori';
        final keyCat = tx.categoryId ?? 'none';
        final cur = byCat[keyCat] ?? (name: name, amount: 0.0, type: tx.type);
        byCat[keyCat] = (name: cur.name, amount: cur.amount + tx.amount, type: tx.type);
      }

      final list = byCat.values.toList()..sort((a, b) => b.amount.compareTo(a.amount));
      months.add(MonthlySummary(month: key, income: income, expense: expense, byCategory: list));
    }

    return FinancialSummary(
      totalBalance: totalBalance,
      accounts: accList.map((a) => (name: a.name, balance: a.balance, type: a.type)).toList(),
      months: months,
    );
  }
}
