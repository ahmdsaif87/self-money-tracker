import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
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
  String _chartType = 'expense'; // 'expense' or 'income'
  int _touchedPieIndex = -1;

  static String _currentMonthKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}';
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

  List<String> _getLast6MonthKeys(String currentKey) {
    final parts = currentKey.split('-');
    final y = int.parse(parts[0]);
    final m = int.parse(parts[1]);
    final result = <String>[];
    for (int i = 5; i >= 0; i--) {
      final dt = DateTime(y, m - i, 1);
      result.add('${dt.year}-${dt.month.toString().padLeft(2, '0')}');
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ThemeStore.instance,
      builder: (context, _) {
        return ListenableBuilder(
          listenable: TransactionStore.instance,
          builder: (context, _) {
            return ListenableBuilder(
              listenable: CategoryStore.instance,
              builder: (context, _) {
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

                final byCat = <String, ({String name, double amount, String type, String color, String icon})>{};
                for (final tx in inMonth) {
                  if (tx.type == 'transfer') continue;
                  final cat = tx.categoryId != null ? catMap[tx.categoryId] : null;
                  final name = cat?.name ?? 'Uncategorized';
                  final color = cat?.color ?? '#E06D53';
                  final icon = cat?.icon ?? 'tag';
                  final ckey = tx.categoryId ?? 'none';
                  final cur = byCat[ckey] ?? (name: name, amount: 0.0, type: tx.type, color: color, icon: icon);
                  byCat[ckey] = (
                    name: name,
                    amount: cur.amount + tx.amount,
                    type: tx.type,
                    color: color,
                    icon: icon,
                  );
                }

                final catList = byCat.values.toList()..sort((a, b) => b.amount.compareTo(a.amount));
                final expenseCats = catList.where((c) => c.type == 'expense').toList();
                final incomeCats = catList.where((c) => c.type == 'income').toList();

                final activeCats = _chartType == 'expense' ? expenseCats : incomeCats;
                final activeTotal = _chartType == 'expense' ? expense : income;

                // 6-Month Historical Data calculation
                final last6Keys = _getLast6MonthKeys(_monthKey);
                final monthlyTrends = last6Keys.map((mKey) {
                  final txs = all.where((t) => t.date.startsWith(mKey)).toList();
                  final inc = txs.where((t) => t.type == 'income').fold<double>(0, (s, t) => s + t.amount);
                  final exp = txs.where((t) => t.type == 'expense').fold<double>(0, (s, t) => s + t.amount);
                  return (key: mKey, label: _monthShortLabel(mKey), income: inc, expense: exp);
                }).toList();

                if (TransactionStore.instance.isLoading && all.isEmpty) {
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
          },
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
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: ThemeColors.secondaryCard(dark),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Center(
        child: Text(msg, style: TextStyle(color: ThemeColors.textMuted(dark), fontSize: 13)),
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
