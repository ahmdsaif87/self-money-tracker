import 'package:flutter/material.dart';
import 'dart:io';
import '../stores/account_store.dart';
import '../stores/category_store.dart';
import '../stores/transaction_store.dart';
import '../stores/theme_store.dart';
import '../stores/profile_store.dart';
import '../models/models.dart';
import '../theme/theme.dart';
import '../components/app_icon.dart';
import '../components/section_label.dart';
import '../components/sheet_drag.dart' show hexColor;
import '../components/skeleton.dart';
import '../utils/amount.dart';

class DashboardScreen extends StatefulWidget {
  final VoidCallback onAddTransaction;
  final void Function(Transaction) onOpenTransaction;

  const DashboardScreen({
    super.key,
    required this.onAddTransaction,
    required this.onOpenTransaction,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 11) return 'Selamat pagi';
    if (hour < 15) return 'Selamat siang';
    if (hour < 19) return 'Selamat sore';
    return 'Selamat malam';
  }

  @override
  Widget build(BuildContext context) {
    final dark = ThemeStore.instance.isDarkMode;
    final accounts = AccountStore.instance.accounts;
    final transactions = TransactionStore.instance.transactions;
    final categories = CategoryStore.instance.categories;

    final totalBalance = accounts.fold<double>(0, (s, a) => s + a.balance);

    final now = DateTime.now();
    final monthKey = '${now.year}-${now.month.toString().padLeft(2, '0')}';
    final monthTxs = transactions
        .where((t) => t.date.startsWith(monthKey))
        .toList();
    final income = monthTxs
        .where((t) => t.type == 'income')
        .fold<double>(0, (s, t) => s + t.amount);
    final expense = monthTxs
        .where((t) => t.type == 'expense')
        .fold<double>(0, (s, t) => s + t.amount);

    final recent = transactions.take(5).toList();

    final catMap = <String, Category>{for (final c in categories) c.id: c};
    final accMap = <String, Account>{for (final a in accounts) a.id: a};

    // Loading state: show skeleton
    if (TransactionStore.instance.isLoading && transactions.isEmpty) {
      return Scaffold(
        backgroundColor: ThemeColors.bg(dark),
        body: const SafeArea(child: SkeletonDashboard()),
      );
    }

    return Scaffold(
      backgroundColor: ThemeColors.bg(dark),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
          children: [
            // Header
            ListenableBuilder(
              listenable: ProfileStore.instance,
              builder: (context, _) {
                final photoUri = ProfileStore.instance.photoUri;
                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _greeting(),
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: ThemeColors.textSecondary(dark),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            ProfileStore.instance.name.isEmpty
                                ? 'Beranda'
                                : ProfileStore.instance.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              color: ThemeColors.textPrimary(dark),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: ThemeColors.accentExpense(
                          dark,
                        ).withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                        border: Border.all(color: ThemeColors.border(dark)),
                        image: photoUri != null
                            ? DecorationImage(
                                image: FileImage(File(photoUri)),
                                fit: BoxFit.cover,
                              )
                            : null,
                      ),
                      child: photoUri == null
                          ? AppIcon(
                              'user',
                              size: 22,
                              color: ThemeColors.accentExpense(dark),
                            )
                          : null,
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 20),

            // Total balance card
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFB84C34), Color(0xFFE06D53)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Total Saldo',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white.withValues(alpha: 0.85),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    formatCurrency(totalBalance),
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      _BalancePill(
                        icon: 'arrow-down-left',
                        label: 'Pemasukan',
                        amount: income,
                        color: const Color(0xFFE4F0E6),
                      ),
                      const SizedBox(width: 12),
                      _BalancePill(
                        icon: 'arrow-up-right',
                        label: 'Pengeluaran',
                        amount: expense,
                        color: Colors.white,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Accounts list
            SectionLabel('Akun', color: ThemeColors.textSecondary(dark)),
            const SizedBox(height: 10),
            ...accounts.map(
              (a) => Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: ThemeColors.card(dark),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: ThemeColors.border(dark)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: hexColor(a.color).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: AppIcon(
                        a.icon,
                        size: 20,
                        color: hexColor(a.color),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        a.name,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: ThemeColors.textPrimary(dark),
                        ),
                      ),
                    ),
                    Text(
                      formatCurrency(a.balance),
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: ThemeColors.textPrimary(dark),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 8),

            // Recent transactions
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                SectionLabel(
                  'Transaksi Terbaru',
                  color: ThemeColors.textSecondary(dark),
                ),
                GestureDetector(
                  onTap: widget.onAddTransaction,
                  child: Text(
                    '+ Tambah',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: ThemeColors.accentExpense(dark),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            if (recent.isEmpty)
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
                      'receipt-text',
                      size: 40,
                      color: ThemeColors.textMuted(dark),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Belum ada transaksi',
                      style: TextStyle(color: ThemeColors.textMuted(dark)),
                    ),
                  ],
                ),
              )
            else
              ...recent.map((tx) {
                final acc = accMap[tx.accountId];
                final cat = tx.categoryId != null
                    ? catMap[tx.categoryId]
                    : null;
                final isIncome = tx.type == 'income';
                final isTransfer = tx.type == 'transfer';
                final color = isTransfer
                    ? ThemeColors.accentWarning(dark)
                    : isIncome
                    ? ThemeColors.accentIncome(dark)
                    : ThemeColors.accentExpense(dark);
                final icon = isTransfer
                    ? 'arrow-right-left'
                    : (cat?.icon ?? 'tag');
                final label = isTransfer
                    ? 'Transfer'
                    : (cat?.name ?? (isIncome ? 'Pemasukan' : 'Pengeluaran'));
                final sign = isIncome
                    ? '+'
                    : isTransfer
                    ? ''
                    : '-';

                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: ThemeColors.card(dark),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: ThemeColors.border(dark)),
                  ),
                  child: InkWell(
                    onTap: () => widget.onOpenTransaction(tx),
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
                );
              }),
          ],
        ),
      ),
    );
  }
}

class _BalancePill extends StatelessWidget {
  final String icon;
  final String label;
  final double amount;
  final Color color;

  const _BalancePill({
    required this.icon,
    required this.label,
    required this.amount,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF7E2E1E),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            AppIcon(icon, size: 16, color: color),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 10,
                      color: Color(0xFFF2E4DC),
                    ),
                  ),
                  Text(
                    formatCurrency(amount),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: color,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
