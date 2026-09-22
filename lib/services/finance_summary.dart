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
    // Accounts table is tiny (a handful of rows) — direct query is fine.
    final accRows = await db.query('accounts');
    final accList = accRows.map(Account.fromMap).toList();

    final totalBalance = accList.fold<double>(0, (sum, a) => sum + a.balance);

    // All transaction math happens in SQLite (SUM + GROUP BY per month).
    // Months are fetched concurrently; each month = 3 small aggregate queries.
    final now = DateTime.now();
    final keys = <String>[];
    for (var i = monthCount - 1; i >= 0; i--) {
      final d = DateTime(now.year, now.month - i, 1);
      keys.add('${d.year}-${d.month.toString().padLeft(2, '0')}');
    }
    final months = await Future.wait(keys.map((key) async {
      final results = await Future.wait([
        DB.instance.fetchMonthlySummary(key),
        DB.instance.fetchCategoryBreakdown(key, 'expense'),
        DB.instance.fetchCategoryBreakdown(key, 'income'),
      ]);
      final summary = results[0] as ({double income, double expense});
      final expCats = results[1]
          as List<({String key, String name, double amount, String type, String color, String icon})>;
      final incCats = results[2]
          as List<({String key, String name, double amount, String type, String color, String icon})>;
      // Both breakdowns arrive pre-sorted DESC by amount; merge preserving order.
      // Keep the legacy 'Tanpa kategori' label for uncategorized rows.
      String label(String name) => name == 'Uncategorized' ? 'Tanpa kategori' : name;
      final merged = <({String name, double amount, String type})>[
        for (final c in expCats) (name: label(c.name), amount: c.amount, type: c.type),
        for (final c in incCats) (name: label(c.name), amount: c.amount, type: c.type),
      ]..sort((a, b) => b.amount.compareTo(a.amount));
      return MonthlySummary(
        month: key,
        income: summary.income,
        expense: summary.expense,
        byCategory: merged,
      );
    }));

    return FinancialSummary(
      totalBalance: totalBalance,
      accounts: accList.map((a) => (name: a.name, balance: a.balance, type: a.type)).toList(),
      months: months,
    );
  }
}
