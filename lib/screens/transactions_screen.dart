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

  Future<void> _pickMonth() async {
    final picked = await showMonthPickerDialog(context, _monthKey);
    if (picked != null && mounted) {
      setState(() => _monthKey = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
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

    // Group by date (descending)
    final groups = <String, List<Transaction>>{};
    for (final tx in filtered) {
      groups.putIfAbsent(tx.date, () => []).add(tx);
    }
    final sortedKeys = groups.keys.toList()..sort((a, b) => b.compareTo(a));

    // Loading state: show skeleton list
    if (TransactionStore.instance.isLoading && all.isEmpty) {
      return Scaffold(
        backgroundColor: ThemeColors.bg(dark),
        body: const SafeArea(child: SkeletonList(rows: 7)),
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
                  'Riwayat Transaksi',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: ThemeColors.textPrimary(dark),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Month selector
            GestureDetector(
              onTap: _pickMonth,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
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
                      size: 16,
                      color: ThemeColors.accentExpense(dark),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _monthLabel(_monthKey),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: ThemeColors.textPrimary(dark),
                        ),
                      ),
                    ),
                    AppIcon(
                      'chevron-down',
                      size: 16,
                      color: ThemeColors.textMuted(dark),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Search field
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: ThemeColors.card(dark),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: ThemeColors.border(dark)),
              ),
              child: Row(
                children: [
                  AppIcon(
                    'search',
                    size: 18,
                    color: ThemeColors.textMuted(dark),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      onChanged: (v) => setState(() => _search = v),
                      style: TextStyle(color: ThemeColors.textPrimary(dark)),
                      decoration: InputDecoration(
                        hintText: 'Cari catatan, kategori, akun...',
                        hintStyle: TextStyle(
                          color: ThemeColors.textMuted(dark),
                        ),
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
                      child: AppIcon(
                        'x',
                        size: 16,
                        color: ThemeColors.textMuted(dark),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Filter chips
            Row(
              children: [
                _FilterChip(
                  label: 'Semua',
                  active: _filter == 'semua',
                  onTap: () => setState(() => _filter = 'semua'),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'Masuk',
                  active: _filter == 'income',
                  onTap: () => setState(() => _filter = 'income'),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'Keluar',
                  active: _filter == 'expense',
                  onTap: () => setState(() => _filter = 'expense'),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'Transfer',
                  active: _filter == 'transfer',
                  onTap: () => setState(() => _filter = 'transfer'),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Summary row
            Row(
              children: [
                _SummaryBox(
                  label: 'Pemasukan',
                  amount: income,
                  color: ThemeColors.accentIncome(dark),
                  dark: dark,
                ),
                const SizedBox(width: 12),
                _SummaryBox(
                  label: 'Pengeluaran',
                  amount: expense,
                  color: ThemeColors.accentExpense(dark),
                  dark: dark,
                ),
              ],
            ),
            const SizedBox(height: 20),

            if (sortedKeys.isEmpty)
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
                      'inbox',
                      size: 40,
                      color: ThemeColors.textMuted(dark),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Tidak ada transaksi di bulan ini',
                      style: TextStyle(color: ThemeColors.textMuted(dark)),
                    ),
                  ],
                ),
              )
            else
              ...sortedKeys.map((dateKey) {
                final txs = groups[dateKey]!;
                final dayTotal = txs.fold<double>(
                  0,
                  (s, t) => s + (t.type == 'income' ? t.amount : -t.amount),
                );
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
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
                            dayTotal >= 0
                                ? '+${formatCurrency(dayTotal)}'
                                : formatCurrency(dayTotal),
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: dayTotal >= 0
                                  ? ThemeColors.accentIncome(dark)
                                  : ThemeColors.accentExpense(dark),
                            ),
                          ),
                        ],
                      ),
                    ),
                    ...txs.map(
                      (tx) => _TxRow(
                        tx: tx,
                        catMap: catMap,
                        accMap: accMap,
                        dark: dark,
                        onTap: () => widget.onOpenTransaction(tx),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                );
              }),
          ],
        ),
      ),
    );
  }

  String _monthLabel(String key) {
    final parts = key.split('-');
    final y = int.tryParse(parts[0]) ?? DateTime.now().year;
    final m = int.tryParse(parts[1]) ?? 1;
    const names = [
      'Januari',
      'Februari',
      'Maret',
      'April',
      'Mei',
      'Juni',
      'Juli',
      'Agustus',
      'September',
      'Oktober',
      'November',
      'Desember',
    ];
    return '${names[m - 1]} $y';
  }

  String _dateLabel(String key) {
    final d = parseLocalDate(key);
    const days = [
      'Senin',
      'Selasa',
      'Rabu',
      'Kamis',
      'Jumat',
      'Sabtu',
      'Minggu',
    ];
    const months = [
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
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: active
              ? ThemeColors.accentExpense(dark)
              : ThemeColors.card(dark),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: active
                ? ThemeColors.accentExpense(dark)
                : ThemeColors.border(dark),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
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

  const _TxRow({
    required this.tx,
    required this.catMap,
    required this.accMap,
    required this.dark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isIncome = tx.type == 'income';
    final isTransfer = tx.type == 'transfer';
    final color = isTransfer
        ? ThemeColors.accentWarning(dark)
        : isIncome
        ? ThemeColors.accentIncome(dark)
        : ThemeColors.accentExpense(dark);
    final cat = tx.categoryId != null ? catMap[tx.categoryId] : null;
    final icon = isTransfer ? 'arrow-right-left' : (cat?.icon ?? 'tag');
    final label = isTransfer
        ? 'Transfer'
        : (cat?.name ?? (isIncome ? 'Pemasukan' : 'Pengeluaran'));
    final sign = isIncome
        ? '+'
        : isTransfer
        ? ''
        : '-';
    final acc = accMap[tx.accountId];

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ThemeColors.card(dark),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ThemeColors.border(dark)),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: AppIcon(icon, size: 18, color: color),
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
                        fontSize: 11,
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
                      fontSize: 10,
                      color: ThemeColors.textMuted(dark),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
