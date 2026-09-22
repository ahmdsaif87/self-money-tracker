import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../stores/transaction_store.dart';
import '../stores/theme_store.dart';
import '../theme/theme.dart';
import '../components/app_icon.dart';
import '../components/month_picker.dart';
import '../components/section_label.dart';
import '../components/sheet_drag.dart' show hexColor;
import '../components/skeleton.dart';
import '../utils/amount.dart';
import 'add_transaction_screen.dart';

class ReportsScreen extends StatefulWidget {
  final VoidCallback onOpenChat;

  const ReportsScreen({super.key, required this.onOpenChat});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

typedef _CatTotal = ({String name, double amount, String type, String color, String icon});
typedef _Trend = ({String key, String label, double income, double expense});

class _ReportsScreenState extends State<ReportsScreen> {
  String _monthKey = _currentMonthKey();
  String _chartType = 'expense'; // 'expense' or 'income'
  int _touchedPieIndex = -1;

  // SQL-side state: no full-table load, no Dart fold over all rows.
  double _income = 0;
  double _expense = 0;
  List<_CatTotal> _expenseCats = [];
  List<_CatTotal> _incomeCats = [];
  List<_Trend> _trends = [];
  bool _isLoading = true;
  int _requestId = 0;

  static String _currentMonthKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}';
  }

  @override
  void initState() {
    super.initState();
    TransactionStore.instance.addListener(_onStoreChanged);
    _load();
  }

  @override
  void dispose() {
    TransactionStore.instance.removeListener(_onStoreChanged);
    super.dispose();
  }

  void _onStoreChanged() => _load();

  Future<void> _load() async {
    final id = ++_requestId;
    final monthKey = _monthKey;
    // Keep old numbers on screen while refreshing (no skeleton flash).
    try {
      final store = TransactionStore.instance;
      final results = await Future.wait([
        store.monthlySummary(monthKey),
        store.categoryBreakdown(monthKey, 'expense'),
        store.categoryBreakdown(monthKey, 'income'),
        store.monthlyTrends(monthKey, 6),
      ]);
      if (!mounted || id != _requestId) return;
      final summary = results[0] as ({double income, double expense});
      final expCats =
          results[1] as List<({String key, String name, double amount, String type, String color, String icon})>;
      final incCats =
          results[2] as List<({String key, String name, double amount, String type, String color, String icon})>;
      final trends = results[3] as List<({String key, double income, double expense})>;
      setState(() {
        _income = summary.income;
        _expense = summary.expense;
        _expenseCats = [for (final c in expCats) (name: c.name, amount: c.amount, type: c.type, color: c.color, icon: c.icon)];
        _incomeCats = [for (final c in incCats) (name: c.name, amount: c.amount, type: c.type, color: c.color, icon: c.icon)];
        _trends = [for (final t in trends) (key: t.key, label: _monthShortLabel(t.key), income: t.income, expense: t.expense)];
        _touchedPieIndex = -1;
        _isLoading = false;
      });
    } catch (_) {
      if (mounted && id == _requestId) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickMonth(BuildContext context) async {
    final picked = await showMonthPickerDialog(context, _monthKey);
    if (picked != null && mounted) {
      setState(() {
        _monthKey = picked;
        _isLoading = _trends.isEmpty;
      });
      await _load();
    }
  }

  String _monthLabel(String key) {
    final parts = key.split('-');
    final y = int.tryParse(parts[0]) ?? DateTime.now().year;
    final m = int.tryParse(parts[1]) ?? 1;
    const names = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return '${names[m - 1]} $y';
  }

  String _monthShortLabel(String key) {
    final parts = key.split('-');
    final m = int.tryParse(parts[1]) ?? 1;
    const shortNames = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return shortNames[m - 1];
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ThemeStore.instance,
      builder: (context, _) {
                final dark = ThemeStore.instance.isDarkMode;
                final income = _income;
                final expense = _expense;
                final net = income - expense;

                final expenseCats = _expenseCats;
                final incomeCats = _incomeCats;

                final activeCats = _chartType == 'expense' ? expenseCats : incomeCats;
                final activeTotal = _chartType == 'expense' ? expense : income;

                // 6-month trend comes from a single SQL GROUP BY (see _load).
                final monthlyTrends = _trends;

                if (_isLoading && monthlyTrends.isEmpty) {
                  return Scaffold(
                    backgroundColor: ThemeColors.bg(dark),
                    body: const SafeArea(child: SkeletonList(rows: 5)),
                  );
                }

                return Scaffold(
                  backgroundColor: ThemeColors.bg(dark),
                  body: SafeArea(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
                      children: [
                        // Header Title & Ask AI Button
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Financial Reports',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                color: ThemeColors.textPrimary(dark),
                              ),
                            ),
                            GestureDetector(
                              onTap: widget.onOpenChat,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: ThemeColors.accentExpense(dark).withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: ThemeColors.accentExpense(dark).withValues(alpha: 0.3)),
                                ),
                                child: Row(
                                  children: [
                                    AppIcon('sparkles', size: 16, color: ThemeColors.accentExpense(dark)),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Ask AI',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: ThemeColors.accentExpense(dark),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Month Selector
                        GestureDetector(
                          onTap: () => _pickMonth(context),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: ThemeColors.card(dark),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: ThemeColors.border(dark)),
                            ),
                            child: Row(
                              children: [
                                AppIcon('calendar', size: 16, color: ThemeColors.accentExpense(dark)),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _monthLabel(_monthKey),
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: ThemeColors.textPrimary(dark),
                                    ),
                                  ),
                                ),
                                AppIcon('chevron-down', size: 16, color: ThemeColors.textMuted(dark)),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // KPI Summary Cards
                        Row(
                          children: [
                            _SummaryCard(
                              label: 'Total Income',
                              amount: income,
                              color: ThemeColors.accentIncome(dark),
                              icon: 'arrow-down-left',
                              dark: dark,
                            ),
                            const SizedBox(width: 12),
                            _SummaryCard(
                              label: 'Total Expenses',
                              amount: expense,
                              color: ThemeColors.accentExpense(dark),
                              icon: 'arrow-up-right',
                              dark: dark,
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _NetSavingsCard(income: income, expense: expense, net: net, dark: dark),
                        const SizedBox(height: 24),

                        // Category Breakdown Interactive Donut Chart
                        SectionLabel('Category Breakdown', color: ThemeColors.textSecondary(dark)),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: ThemeColors.card(dark),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: ThemeColors.border(dark)),
                          ),
                          child: Column(
                            children: [
                              // Toggle Switcher (Expenses vs Income)
                              Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: ThemeColors.secondaryCard(dark),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: GestureDetector(
                                        onTap: () => setState(() {
                                          _chartType = 'expense';
                                          _touchedPieIndex = -1;
                                        }),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(vertical: 8),
                                          decoration: BoxDecoration(
                                            color: _chartType == 'expense' ? ThemeColors.expense.withValues(alpha: 0.2) : Colors.transparent,
                                            borderRadius: BorderRadius.circular(10),
                                            border: _chartType == 'expense' ? Border.all(color: ThemeColors.expense) : null,
                                          ),
                                          child: Center(
                                            child: Text(
                                              'Expenses',
                                              style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: _chartType == 'expense' ? FontWeight.bold : FontWeight.w500,
                                                color: _chartType == 'expense' ? ThemeColors.expense : ThemeColors.textMuted(dark),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: GestureDetector(
                                        onTap: () => setState(() {
                                          _chartType = 'income';
                                          _touchedPieIndex = -1;
                                        }),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(vertical: 8),
                                          decoration: BoxDecoration(
                                            color: _chartType == 'income' ? ThemeColors.income.withValues(alpha: 0.2) : Colors.transparent,
                                            borderRadius: BorderRadius.circular(10),
                                            border: _chartType == 'income' ? Border.all(color: ThemeColors.income) : null,
                                          ),
                                          child: Center(
                                            child: Text(
                                              'Income',
                                              style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: _chartType == 'income' ? FontWeight.bold : FontWeight.w500,
                                                color: _chartType == 'income' ? ThemeColors.income : ThemeColors.textMuted(dark),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 20),

                              // Donut Chart Graphic & Center Stack
                              if (activeCats.isEmpty)
                                _emptyBox(dark, 'No $_chartType recorded for this month')
                              else ...[
                                SizedBox(
                                  height: 200,
                                  child: Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      PieChart(
                                        PieChartData(
                                          pieTouchData: PieTouchData(
                                            touchCallback: (FlTouchEvent event, pieTouchResponse) {
                                              setState(() {
                                                if (!event.isInterestedForInteractions ||
                                                    pieTouchResponse == null ||
                                                    pieTouchResponse.touchedSection == null) {
                                                  _touchedPieIndex = -1;
                                                  return;
                                                }
                                                _touchedPieIndex = pieTouchResponse.touchedSection!.touchedSectionIndex;
                                              });
                                            },
                                          ),
                                          borderData: FlBorderData(show: false),
                                          sectionsSpace: 3,
                                          centerSpaceRadius: 55,
                                          sections: List.generate(activeCats.length, (i) {
                                            final isTouched = i == _touchedPieIndex;
                                            final cat = activeCats[i];
                                            final pct = activeTotal > 0 ? (cat.amount / activeTotal * 100) : 0.0;
                                            final color = hexColor(cat.color);
                                            final radius = isTouched ? 30.0 : 22.0;

                                            return PieChartSectionData(
                                              color: color,
                                              value: cat.amount,
                                              title: isTouched ? '${pct.toStringAsFixed(1)}%' : '',
                                              radius: radius,
                                              titleStyle: const TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.white,
                                              ),
                                            );
                                          }),
                                        ),
                                      ),
                                      // Center Label Inside Donut Hole
                                      Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            _touchedPieIndex >= 0 && _touchedPieIndex < activeCats.length
                                                ? activeCats[_touchedPieIndex].name
                                                : (_chartType == 'expense' ? 'Total Spent' : 'Total Income'),
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: ThemeColors.textMuted(dark),
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            formatCurrency(
                                              _touchedPieIndex >= 0 && _touchedPieIndex < activeCats.length
                                                  ? activeCats[_touchedPieIndex].amount
                                                  : activeTotal,
                                            ),
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w800,
                                              color: _touchedPieIndex >= 0 && _touchedPieIndex < activeCats.length
                                                  ? hexColor(activeCats[_touchedPieIndex].color)
                                                  : ThemeColors.textPrimary(dark),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 16),

                                // Detailed Category Breakdown Rows
                                ListView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: activeCats.length,
                                  itemBuilder: (context, index) {
                                    return _CatRow(
                                      cat: activeCats[index],
                                      total: activeTotal,
                                      dark: dark,
                                    );
                                  },
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        // 6-Month Comparison Bar Chart
                        SectionLabel('6-Month Trend Overview', color: ThemeColors.textSecondary(dark)),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: ThemeColors.card(dark),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: ThemeColors.border(dark)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Legend Row
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  _LegendDot(color: ThemeColors.income, label: 'Income', dark: dark),
                                  const SizedBox(width: 16),
                                  _LegendDot(color: ThemeColors.expense, label: 'Expense', dark: dark),
                                ],
                              ),
                              const SizedBox(height: 16),
                              SizedBox(
                                height: 220,
                                child: BarChart(
                                  BarChartData(
                                    alignment: BarChartAlignment.spaceAround,
                                    maxY: _calcMaxY(monthlyTrends),
                                    barTouchData: BarTouchData(
                                      enabled: true,
                                      touchTooltipData: BarTouchTooltipData(
                                        getTooltipColor: (_) => dark ? const Color(0xFF2C2C2E) : Colors.white,
                                        getTooltipItem: (group, groupIndex, rod, rodIndex) {
                                          final isIncome = rodIndex == 0;
                                          final label = isIncome ? 'Income' : 'Expense';
                                          return BarTooltipItem(
                                            '$label\n${formatCurrency(rod.toY)}',
                                            TextStyle(
                                              color: isIncome ? ThemeColors.income : ThemeColors.expense,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12,
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                    titlesData: FlTitlesData(
                                      show: true,
                                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                      leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                      bottomTitles: AxisTitles(
                                        sideTitles: SideTitles(
                                          showTitles: true,
                                          getTitlesWidget: (double value, TitleMeta meta) {
                                            final idx = value.toInt();
                                            if (idx >= 0 && idx < monthlyTrends.length) {
                                              return Padding(
                                                padding: const EdgeInsets.only(top: 8.0),
                                                child: Text(
                                                  monthlyTrends[idx].label,
                                                  style: TextStyle(
                                                    color: ThemeColors.textMuted(dark),
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              );
                                            }
                                            return const SizedBox.shrink();
                                          },
                                        ),
                                      ),
                                    ),
                                    gridData: const FlGridData(show: false),
                                    borderData: FlBorderData(show: false),
                                    barGroups: List.generate(monthlyTrends.length, (idx) {
                                      final item = monthlyTrends[idx];
                                      return BarChartGroupData(
                                        x: idx,
                                        barRods: [
                                          BarChartRodData(
                                            toY: item.income,
                                            color: ThemeColors.income,
                                            width: 10,
                                            borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                                          ),
                                          BarChartRodData(
                                            toY: item.expense,
                                            color: ThemeColors.expense,
                                            width: 10,
                                            borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                                          ),
                                        ],
                                      );
                                    }),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
      },
    );
  }

  double _calcMaxY(List<({String key, String label, double income, double expense})> trends) {
    double maxVal = 100000;
    for (final t in trends) {
      if (t.income > maxVal) maxVal = t.income;
      if (t.expense > maxVal) maxVal = t.expense;
    }
    return maxVal * 1.15;
  }

  Widget _emptyBox(bool dark, String msg) {
    final isExpense = msg.toLowerCase().contains('expense');
    final accent = isExpense ? ThemeColors.accentExpense(dark) : ThemeColors.accentIncome(dark);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
      decoration: BoxDecoration(
        color: ThemeColors.secondaryCard(dark),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ThemeColors.border(dark).withValues(alpha: 0.6)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isExpense ? Icons.shopping_bag_outlined : Icons.savings_outlined,
              size: 26,
              color: accent,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            msg,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: ThemeColors.textPrimary(dark),
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Add a transaction to see your breakdown chart here.',
            textAlign: TextAlign.center,
            style: TextStyle(color: ThemeColors.textMuted(dark), fontSize: 12, height: 1.5),
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: () => AddTransactionScreen.show(context),
            icon: const Icon(Icons.add_rounded, size: 16),
            label: const Text('Add Transaction', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
            style: OutlinedButton.styleFrom(
              foregroundColor: accent,
              side: BorderSide(color: accent.withValues(alpha: 0.5)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
          ),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  final bool dark;

  const _LegendDot({required this.color, required this.label, required this.dark});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: ThemeColors.textMuted(dark)),
        ),
      ],
    );
  }
}

class _CatRow extends StatelessWidget {
  final ({String name, double amount, String type, String color, String icon}) cat;
  final double total;
  final bool dark;

  const _CatRow({required this.cat, required this.total, required this.dark});

  @override
  Widget build(BuildContext context) {
    final pct = total > 0 ? (cat.amount / total) : 0.0;
    final catColor = hexColor(cat.color);
    final pctText = '${(pct * 100).toStringAsFixed(1)}%';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ThemeColors.secondaryCard(dark),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: catColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: AppIcon(cat.icon, size: 16, color: catColor),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      cat.name,
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: ThemeColors.textPrimary(dark)),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      pctText,
                      style: TextStyle(fontSize: 11, color: ThemeColors.textMuted(dark), fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
              Text(
                formatCurrency(cat.amount),
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: catColor),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct.clamp(0.0, 1.0),
              minHeight: 5,
              backgroundColor: ThemeColors.border(dark),
              valueColor: AlwaysStoppedAnimation<Color>(catColor),
            ),
          ),
        ],
      ),
    );
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
        padding: const EdgeInsets.all(14),
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
            Text(label, style: TextStyle(fontSize: 11, color: ThemeColors.textMuted(dark))),
            const SizedBox(height: 4),
            Text(
              formatCurrency(amount),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: color),
            ),
          ],
        ),
      ),
    );
  }
}

class _NetSavingsCard extends StatelessWidget {
  final double income;
  final double expense;
  final double net;
  final bool dark;

  const _NetSavingsCard({
    required this.income,
    required this.expense,
    required this.net,
    required this.dark,
  });

  @override
  Widget build(BuildContext context) {
    final savingsRate = income > 0 ? (net / income * 100).clamp(-100.0, 100.0) : 0.0;
    final isPositive = net >= 0;
    final color = isPositive ? ThemeColors.accentIncome(dark) : ThemeColors.accentExpense(dark);

    String statusLabel = 'High Expense';
    if (savingsRate >= 30) {
      statusLabel = 'Excellent Savings';
    } else if (savingsRate >= 15) {
      statusLabel = 'Healthy Savings';
    } else if (savingsRate > 0) {
      statusLabel = 'Moderate Savings';
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ThemeColors.card(dark),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ThemeColors.border(dark)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              AppIcon(isPositive ? 'trending-up' : 'trending-down', size: 18, color: color),
              const SizedBox(width: 10),
              Text('Net Savings', style: TextStyle(fontSize: 13, color: ThemeColors.textMuted(dark))),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${isPositive ? '+' : ''}${formatCurrency(net)}',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: color),
              ),
              if (income > 0)
                Text(
                  'Rate: ${savingsRate.toStringAsFixed(1)}%',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: ThemeColors.textMuted(dark)),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
