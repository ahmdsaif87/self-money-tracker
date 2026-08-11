import 'package:flutter/material.dart';
import '../stores/transaction_store.dart';
import '../stores/category_store.dart';
import '../stores/theme_store.dart';
import '../theme/theme.dart';
import '../components/app_icon.dart';
import '../components/month_picker.dart';
import '../components/section_label.dart';
import '../components/sheet_drag.dart' show hexColor;
import '../components/skeleton.dart';
import '../utils/amount.dart';

class ReportsScreen extends StatefulWidget {
  final VoidCallback onOpenChat;

  const ReportsScreen({super.key, required this.onOpenChat});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  String _monthKey = _currentMonthKey();

  static String _currentMonthKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final dark = ThemeStore.instance.isDarkMode;
    final all = TransactionStore.instance.transactions;
    final categories = CategoryStore.instance.categories;

    final catMap = <String, dynamic>{for (final c in categories) c.id: c};
    final inMonth = all.where((t) => t.date.startsWith(_monthKey)).toList();

    final income = inMonth
        .where((t) => t.type == 'income')
        .fold<double>(0, (s, t) => s + t.amount);
    final expense = inMonth
        .where((t) => t.type == 'expense')
        .fold<double>(0, (s, t) => s + t.amount);
    final net = income - expense;

    // Category breakdown (expense + income separately)
    final byCat =
        <
          String,
          ({String name, double amount, String type, String color, String icon})
        >{};
    for (final tx in inMonth) {
      if (tx.type == 'transfer') continue;
      final cat = tx.categoryId != null ? catMap[tx.categoryId] : null;
      final name = cat?.name ?? 'Tanpa kategori';
      final color = cat?.color ?? '#E06D53';
      final icon = cat?.icon ?? 'tag';
      final ckey = tx.categoryId ?? 'none';
      final cur =
          byCat[ckey] ??
          (name: name, amount: 0.0, type: tx.type, color: color, icon: icon);
      byCat[ckey] = (
        name: cur.name,
        amount: cur.amount + tx.amount,
        type: tx.type,
        color: cur.color,
        icon: cur.icon,
      );
    }

    final catList = byCat.values.toList()
      ..sort((a, b) => b.amount.compareTo(a.amount));
    final maxCat = catList.isEmpty ? 0.0 : catList.first.amount;

    // Loading state: show skeleton
    if (TransactionStore.instance.isLoading && all.isEmpty) {
      return Scaffold(
        backgroundColor: ThemeColors.bg(dark),
        body: const SafeArea(child: SkeletonList(rows: 6)),
      );
    }

    return Scaffold(
      backgroundColor: ThemeColors.bg(dark),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Laporan',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: ThemeColors.textPrimary(dark),
                  ),
                ),
                Row(
                  children: [
                    // Chat AI button
                    GestureDetector(
                      onTap: widget.onOpenChat,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: ThemeColors.accentExpense(dark),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Row(
                          children: [
                            AppIcon('bot', size: 14, color: Colors.white),
                            SizedBox(width: 6),
                            Text(
                              'Chat AI',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => _pickMonth(context),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: ThemeColors.card(dark),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: ThemeColors.border(dark)),
                        ),
                        child: Row(
                          children: [
                            AppIcon(
                              'calendar',
                              size: 14,
                              color: ThemeColors.accentExpense(dark),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _monthLabel(_monthKey),
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: ThemeColors.textPrimary(dark),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Summary cards
            Row(
              children: [
                _SummaryCard(
                  label: 'Pemasukan',
                  amount: income,
                  color: ThemeColors.accentIncome(dark),
                  icon: 'arrow-down-left',
                  dark: dark,
                ),
                const SizedBox(width: 12),
                _SummaryCard(
                  label: 'Pengeluaran',
                  amount: expense,
                  color: ThemeColors.accentExpense(dark),
                  icon: 'arrow-up-right',
                  dark: dark,
                ),
              ],
            ),
            const SizedBox(height: 12),
            _NetCard(net: net, dark: dark),
            const SizedBox(height: 24),

            // Category breakdown
            SectionLabel(
              'Per Kategori',
              color: ThemeColors.textSecondary(dark),
            ),
            const SizedBox(height: 12),
            if (catList.isEmpty)
              Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: ThemeColors.card(dark),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: ThemeColors.border(dark)),
                ),
                child: Column(
                  children: [
                    AppIcon(
                      'chart-pie',
                      size: 40,
                      color: ThemeColors.textMuted(dark),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Belum ada transaksi bulan ini',
                      style: TextStyle(color: ThemeColors.textMuted(dark)),
                    ),
                  ],
                ),
              )
            else
              ...catList.map((c) {
                final width = maxCat == 0
                    ? 0.0
                    : (c.amount / maxCat * 100).clamp(5.0, 100.0);
                final color = hexColor(c.color);
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: ThemeColors.card(dark),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: ThemeColors.border(dark)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          AppIcon(c.icon, size: 16, color: color),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              c.name,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: ThemeColors.textPrimary(dark),
                              ),
                            ),
                          ),
                          Text(
                            'Rp ${formatCompact(c.amount)}',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: color,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: width / 100,
                          minHeight: 6,
                          backgroundColor: ThemeColors.border(dark),
                          valueColor: AlwaysStoppedAnimation<Color>(color),
                        ),
                      ),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  Future<void> _pickMonth(BuildContext context) async {
    final picked = await showMonthPickerDialog(context, _monthKey);
    if (picked != null && mounted) {
      setState(() => _monthKey = picked);
    }
  }

  String _monthLabel(String key) {
    final parts = key.split('-');
    final y = int.tryParse(parts[0]) ?? DateTime.now().year;
    final m = int.tryParse(parts[1]) ?? 1;
    const names = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'Mei',
      'Jun',
      'Jul',
      'Agu',
      'Sep',
      'Okt',
      'Nov',
      'Des',
    ];
    return '${names[m - 1]} $y';
  }
}

class _SummaryCard extends StatelessWidget {
  final String label;
  final double amount;
  final Color color;
  final String icon;
  final bool dark;

  const _SummaryCard({
    required this.label,
    required this.amount,
    required this.color,
    required this.icon,
    required this.dark,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: ThemeColors.card(dark),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: ThemeColors.border(dark)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppIcon(icon, size: 18, color: color),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: ThemeColors.textMuted(dark),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              formatCurrency(amount),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NetCard extends StatelessWidget {
  final double net;
  final bool dark;

  const _NetCard({required this.net, required this.dark});

  @override
  Widget build(BuildContext context) {
    final color = net >= 0
        ? ThemeColors.accentIncome(dark)
        : ThemeColors.accentExpense(dark);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ThemeColors.card(dark),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ThemeColors.border(dark)),
      ),
      child: Row(
        children: [
          AppIcon(
            net >= 0 ? 'trending-up' : 'trending-down',
            size: 18,
            color: color,
          ),
          const SizedBox(width: 10),
          Text(
            'Selisih',
            style: TextStyle(fontSize: 13, color: ThemeColors.textMuted(dark)),
          ),
          const Spacer(),
          Text(
            '${net >= 0 ? '+' : ''}${formatCurrency(net)}',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
