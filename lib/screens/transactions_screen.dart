import 'package:flutter/material.dart';
import '../stores/transaction_store.dart';
import '../stores/category_store.dart';
import '../stores/account_store.dart';
import '../stores/theme_store.dart';
import '../models/models.dart';
import '../theme/theme.dart';
import '../components/app_icon.dart';
import '../components/month_picker.dart';
import '../components/skeleton.dart';
import '../components/sheet_drag.dart' show hexColor;
import '../utils/amount.dart';
import '../utils/date.dart';

class TransactionsScreen extends StatefulWidget {
  final void Function(Transaction) onOpenTransaction;

  const TransactionsScreen({
    super.key,
    required this.onOpenTransaction,
  });

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  String _filter = 'semua'; // semua | expense | income | transfer
  String _monthKey = _currentMonthKey();
  String _search = '';
  bool _isFiltering = false;
  final _searchController = TextEditingController();

  static String _currentMonthKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _triggerFilterChange(VoidCallback action) async {
    setState(() {
      _isFiltering = true;
      action();
    });
    await Future.delayed(const Duration(milliseconds: 180));
    if (mounted) {
      setState(() {
        _isFiltering = false;
      });
    }
  }

  Future<void> _handleDeleteTx(Transaction tx) async {
    await TransactionStore.instance.deleteTransaction(tx.id);
    if (mounted) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Transaction deleted'),
          action: SnackBarAction(
            label: 'UNDO',
            onPressed: () async {
              await TransactionStore.instance.addTransaction(
                accountId: tx.accountId,
                toAccountId: tx.toAccountId,
                categoryId: tx.categoryId,
                amount: tx.amount,
                type: tx.type,
                note: tx.note,
                date: tx.date,
              );
            },
          ),
        ),
      );
    }
  }

  Future<void> _pickMonth() async {
    final picked = await showMonthPickerDialog(context, _monthKey);
    if (picked != null && mounted) {
      _triggerFilterChange(() => _monthKey = picked);
    }
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
              listenable: AccountStore.instance,
              builder: (context, _) {
                final dark = ThemeStore.instance.isDarkMode;
                final all = TransactionStore.instance.transactions;
                final categories = CategoryStore.instance.categories;
                final accounts = AccountStore.instance.accounts;

                final catMap = <String, Category>{for (final c in categories) c.id: c};
                final accMap = <String, Account>{for (final a in accounts) a.id: a};

                final inMonth = all.where((t) => t.date.startsWith(_monthKey)).toList();
                final q = _search.trim().toLowerCase();
                final searched = q.isEmpty
                    ? inMonth
                    : inMonth.where((t) {
                        final cat = t.categoryId != null ? catMap[t.categoryId] : null;
                        final acc = accMap[t.accountId];
                        return (t.note?.toLowerCase().contains(q) ?? false) ||
                            (cat?.name.toLowerCase().contains(q) ?? false) ||
                            (acc?.name.toLowerCase().contains(q) ?? false);
                      }).toList();
                final filtered = _filter == 'semua'
                    ? searched
                    : searched.where((t) => t.type == _filter).toList();

                final income = inMonth
                    .where((t) => t.type == 'income')
                    .fold<double>(0, (s, t) => s + t.amount);
                final expense = inMonth
                    .where((t) => t.type == 'expense')
                    .fold<double>(0, (s, t) => s + t.amount);

                final groups = <String, List<Transaction>>{};
                for (final tx in filtered) {
                  groups.putIfAbsent(tx.date, () => []).add(tx);
                }
                final sortedKeys = groups.keys.toList()..sort((a, b) => b.compareTo(a));

                final listItems = <dynamic>[
                  'header',
                  'month_selector',
                  'search',
                  'filters',
                  'summary',
                ];

                if (sortedKeys.isEmpty) {
                  listItems.add('empty');
                } else {
                  for (final dateKey in sortedKeys) {
                    listItems.add({'type': 'date_header', 'key': dateKey});
                    final txs = groups[dateKey]!;
                    for (final tx in txs) {
                      listItems.add({'type': 'tx', 'data': tx});
                    }
                  }
                }

                if ((TransactionStore.instance.isLoading && all.isEmpty) || _isFiltering) {
                  return Scaffold(
                    backgroundColor: ThemeColors.bg(dark),
                    body: const SafeArea(child: SkeletonList(rows: 7)),
                  );
                }

                return Scaffold(
                  backgroundColor: ThemeColors.bg(dark),
                  body: SafeArea(
                    child: RefreshIndicator(
                      onRefresh: () async {
                        await TransactionStore.instance.fetchTransactions();
                      },
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
                        itemCount: listItems.length,
                        itemBuilder: (context, index) {
                          final item = listItems[index];

                          if (item == 'header') {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Transactions',
                                    style: TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.w800,
                                      color: ThemeColors.textPrimary(dark),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }
                          
                          if (item == 'month_selector') {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: GestureDetector(
                                onTap: _pickMonth,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  decoration: BoxDecoration(
                                    color: ThemeColors.card(dark),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: ThemeColors.border(dark)),
                                  ),
                                  child: Row(
                                    children: [
                                      AppIcon('calendar', size: 18, color: ThemeColors.accentExpense(dark)),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          _monthLabel(_monthKey),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w700,
                                            color: ThemeColors.textPrimary(dark),
                                          ),
                                        ),
                                      ),
                                      AppIcon('chevron-down', size: 18, color: ThemeColors.textMuted(dark)),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }

                          if (item == 'search') {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                                decoration: BoxDecoration(
                                  color: ThemeColors.card(dark),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: ThemeColors.border(dark)),
                                ),
                                child: Row(
                                  children: [
                                    AppIcon('search', size: 18, color: ThemeColors.textMuted(dark)),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: TextField(
                                        controller: _searchController,
                                        onChanged: (v) => setState(() => _search = v),
                                        style: TextStyle(color: ThemeColors.textPrimary(dark), fontSize: 14),
                                        decoration: InputDecoration(
                                          hintText: 'Search notes, categories, accounts...',
                                          hintStyle: TextStyle(color: ThemeColors.textMuted(dark), fontSize: 14),
                                          border: InputBorder.none,
                                          isDense: true,
                                        ),
                                      ),
                                    ),
                                    if (_search.isNotEmpty)
                                      GestureDetector(
                                        onTap: () {
                                          _searchController.clear();
                                          setState(() => _search = '');
                                        },
                                        child: AppIcon('x', size: 16, color: ThemeColors.textMuted(dark)),
                                      ),
                                  ],
                                ),
                              ),
                            );
                          }

                          if (item == 'filters') {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: Row(
                                children: [
                                  _FilterChip(
                                    label: 'All',
                                    active: _filter == 'semua',
                                    onTap: () => _triggerFilterChange(() => _filter = 'semua'),
                                  ),
                                  const SizedBox(width: 8),
                                  _FilterChip(
                                    label: 'Income',
                                    active: _filter == 'income',
                                    onTap: () => _triggerFilterChange(() => _filter = 'income'),
                                  ),
                                  const SizedBox(width: 8),
                                  _FilterChip(
                                    label: 'Expense',
                                    active: _filter == 'expense',
                                    onTap: () => _triggerFilterChange(() => _filter = 'expense'),
                                  ),
                                  const SizedBox(width: 8),
                                  _FilterChip(
                                    label: 'Transfer',
                                    active: _filter == 'transfer',
                                    onTap: () => _triggerFilterChange(() => _filter = 'transfer'),
                                  ),
                                ],
                              ),
                            );
                          }

                          if (item == 'summary') {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 20),
                              child: Row(
                                children: [
                                  _SummaryBox(
                                    label: 'Income',
                                    amount: income,
                                    color: ThemeColors.accentIncome(dark),
                                    dark: dark,
                                  ),
                                  const SizedBox(width: 12),
                                  _SummaryBox(
                                    label: 'Expense',
                                    amount: expense,
                                    color: ThemeColors.accentExpense(dark),
                                    dark: dark,
                                  ),
                                ],
                              ),
                            );
                          }

                          if (item == 'empty') {
                            return Container(
                              padding: const EdgeInsets.all(36),
                              decoration: BoxDecoration(
                                color: ThemeColors.card(dark),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: ThemeColors.border(dark)),
                              ),
                              child: Column(
                                children: [
                                  AppIcon('inbox', size: 40, color: ThemeColors.textMuted(dark)),
                                  const SizedBox(height: 12),
                                  Text(
                                    'No transactions found for this month',
                                    style: TextStyle(color: ThemeColors.textMuted(dark), fontSize: 13),
                                  ),
                                ],
                              ),
                            );
                          }

                          final itemMap = item as Map<String, dynamic>;
                          if (itemMap['type'] == 'date_header') {
                            final dateKey = itemMap['key'] as String;
                            final txs = groups[dateKey]!;
                            final dayTotal = txs.fold<double>(
                              0,
                              (s, t) => s + (t.type == 'income' ? t.amount : t.type == 'transfer' ? 0 : -t.amount),
                            );
                            
                            return Padding(
                              padding: const EdgeInsets.only(top: 8, bottom: 8, left: 4, right: 4),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    _dateLabel(dateKey),
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                      color: ThemeColors.textSecondary(dark),
                                    ),
                                  ),
                                  Text(
                                    dayTotal >= 0 ? '+${formatCurrency(dayTotal)}' : formatCurrency(dayTotal),
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                      color: dayTotal >= 0 ? ThemeColors.accentIncome(dark) : ThemeColors.accentExpense(dark),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }

                          if (itemMap['type'] == 'tx') {
                            final tx = itemMap['data'] as Transaction;
                            return _TxRow(
                              tx: tx,
                              catMap: catMap,
                              accMap: accMap,
                              dark: dark,
                              onTap: () => widget.onOpenTransaction(tx),
                              onDismissed: _handleDeleteTx,
                            );
                          }

                          return const SizedBox.shrink();
                        },
                      ),
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

  String _monthLabel(String key) {
    final parts = key.split('-');
    final y = int.tryParse(parts[0]) ?? DateTime.now().year;
    final m = int.tryParse(parts[1]) ?? 1;
    const names = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return '${names[m - 1]} $y';
  }

  String _dateLabel(String key) {
    final d = parseLocalDate(key);
    const days = [
      'Mon',
      'Tue',
      'Wed',
      'Thu',
      'Fri',
      'Sat',
      'Sun',
    ];
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${days[d.weekday - 1]}, ${d.day} ${months[d.month - 1]}';
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final dark = ThemeStore.instance.isDarkMode;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: active
              ? ThemeColors.accentExpense(dark)
              : ThemeColors.card(dark),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: active
                ? ThemeColors.accentExpense(dark)
                : ThemeColors.border(dark),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: active ? FontWeight.bold : FontWeight.w600,
            color: active ? Colors.white : ThemeColors.textSecondary(dark),
          ),
        ),
      ),
    );
  }
}

class _SummaryBox extends StatelessWidget {
  final String label;
  final double amount;
  final Color color;
  final bool dark;

  const _SummaryBox({
    required this.label,
    required this.amount,
    required this.color,
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
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: ThemeColors.textMuted(dark),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              formatCurrency(amount),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 16,
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

class _TxRow extends StatelessWidget {
  final Transaction tx;
  final Map<String, Category> catMap;
  final Map<String, Account> accMap;
  final bool dark;
  final VoidCallback onTap;
  final Function(Transaction) onDismissed;

  const _TxRow({
    required this.tx,
    required this.catMap,
    required this.accMap,
    required this.dark,
    required this.onTap,
    required this.onDismissed,
  });

  @override
  Widget build(BuildContext context) {
    final isIncome = tx.type == 'income';
    final isTransfer = tx.type == 'transfer';
    final cat = tx.categoryId != null ? catMap[tx.categoryId] : null;
    final color = cat != null
        ? hexColor(cat.color)
        : isTransfer
        ? ThemeColors.accentWarning(dark)
        : isIncome
        ? ThemeColors.accentIncome(dark)
        : ThemeColors.accentExpense(dark);
    final icon = isTransfer ? 'arrow-right-left' : (cat?.icon ?? 'tag');
    final label = isTransfer
        ? 'Transfer'
        : (cat?.name ?? (isIncome ? 'Income' : 'Expense'));
    final sign = isIncome
        ? '+'
        : isTransfer
        ? ''
        : '-';
    final acc = accMap[tx.accountId];

    return Dismissible(
      key: Key(tx.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: Colors.red.shade400,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (_) => onDismissed(tx),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: ThemeColors.card(dark),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: ThemeColors.border(dark)),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: AppIcon(icon, size: 20, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: ThemeColors.textPrimary(dark),
                      ),
                    ),
                    if (tx.note != null && tx.note!.isNotEmpty)
                      Text(
                        tx.note!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: ThemeColors.textMuted(dark),
                        ),
                      ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '$sign${formatCurrency(tx.amount)}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: color,
                    ),
                  ),
                  if (acc != null)
                    Text(
                      acc.name,
                      style: TextStyle(
                        fontSize: 11,
                        color: ThemeColors.textMuted(dark),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
