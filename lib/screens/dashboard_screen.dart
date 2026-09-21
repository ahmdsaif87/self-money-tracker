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
    if (hour < 11) return 'Good morning';
    if (hour < 15) return 'Good afternoon';
    if (hour < 19) return 'Good evening';
    return 'Good night';
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
                final accounts = AccountStore.instance.accounts;
                final transactions = TransactionStore.instance.transactions;
                final categories = CategoryStore.instance.categories;

                final totalBalance = accounts.fold<double>(0, (s, a) => s + a.balance);

                final now = DateTime.now();
                final monthKey = '${now.year}-${now.month.toString().padLeft(2, '0')}';
                final todayKey = '$monthKey-${now.day.toString().padLeft(2, '0')}';

                final monthTxs = transactions
                    .where((t) => t.date.startsWith(monthKey))
                    .toList();
                final income = monthTxs
                    .where((t) => t.type == 'income')
                    .fold<double>(0, (s, t) => s + t.amount);
                final expense = monthTxs
                    .where((t) => t.type == 'expense')
                    .fold<double>(0, (s, t) => s + t.amount);

                final todayTxs = monthTxs.where((t) => t.date == todayKey).toList();
                final todayIncome = todayTxs
                    .where((t) => t.type == 'income')
                    .fold<double>(0, (s, t) => s + t.amount);
                final todayExpense = todayTxs
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
                    child: RefreshIndicator(
                      onRefresh: () async {
                        await TransactionStore.instance.fetchTransactions();
                        await AccountStore.instance.fetchAccounts();
                      },
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
                                              ? 'Dashboard'
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
                                  'Total Balance',
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
                                      label: 'Income',
                                      amount: income,
                                      color: const Color(0xFFE4F0E6),
                                    ),
                                    const SizedBox(width: 12),
                                    _BalancePill(
                                      icon: 'arrow-up-right',
                                      label: 'Expense',
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
                          SectionLabel('Accounts', color: ThemeColors.textSecondary(dark)),
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

                          // Today's Summary
                          SectionLabel('Today\'s Summary', color: ThemeColors.textSecondary(dark)),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              _SummaryCard(
                                label: 'Income',
                                amount: todayIncome,
                                color: ThemeColors.accentIncome(dark),
                                icon: 'arrow-down-left',
                                dark: dark,
                              ),
                              const SizedBox(width: 12),
                              _SummaryCard(
                                label: 'Expense',
                                amount: todayExpense,
                                color: ThemeColors.accentExpense(dark),
                                icon: 'arrow-up-right',
                                dark: dark,
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),

                          // Recent transactions
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              SectionLabel(
                                'Recent Transactions',
                                color: ThemeColors.textSecondary(dark),
                              ),
                              GestureDetector(
                                onTap: widget.onAddTransaction,
                                child: Text(
                                  '+ Add New',
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
                            GestureDetector(
                              onTap: widget.onAddTransaction,
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
                                decoration: BoxDecoration(
                                  color: ThemeColors.card(dark),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: ThemeColors.accentExpense(dark).withValues(alpha: 0.3),
                                    width: 2,
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: ThemeColors.accentExpense(dark).withValues(alpha: 0.1),
                                        shape: BoxShape.circle,
                                      ),
                                      child: AppIcon(
                                        'plus',
                                        size: 32,
                                        color: ThemeColors.accentExpense(dark),
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'Tambah Transaksi Pertama',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: ThemeColors.textPrimary(dark),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Mulai catat pemasukan atau pengeluaranmu hari ini.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: ThemeColors.textMuted(dark),
                                      ),
                                    ),
                                  ],
                                ),
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
                                  : (cat?.name ?? (isIncome ? 'Income' : 'Expense'));
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
                  ),
                );
              },
            );
          },
        );
      },
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
