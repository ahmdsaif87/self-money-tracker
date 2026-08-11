import 'package:flutter/material.dart';
import '../stores/account_store.dart';
import '../stores/profile_store.dart';
import '../stores/theme_store.dart';
import '../theme/theme.dart';
import '../components/app_icon.dart';
import '../components/section_label.dart';
import '../components/sheet_drag.dart' show hexA;
import '../utils/amount.dart';

class OnboardingScreen extends StatefulWidget {
  final VoidCallback onComplete;
  const OnboardingScreen({super.key, required this.onComplete});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _nameController = TextEditingController();
  final _balanceController = TextEditingController();
  String _type = 'cash';

  static const _accountTypes = [
    (key: 'cash', label: 'Tunai', icon: 'wallet'),
    (key: 'bank', label: 'Bank', icon: 'banknote'),
    (key: 'ewallet', label: 'E-Wallet', icon: 'credit-card'),
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _balanceController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      _showAlert('Nama Diperlukan', 'Masukkan nama akun pertama Anda.');
      return;
    }
    final typeDef = _accountTypes.firstWhere(
      (t) => t.key == _type,
      orElse: () => _accountTypes.first,
    );
    final numBalance = parseRawAmount(_balanceController.text);
    await AccountStore.instance.addAccount(
      name: name,
      type: _type,
      balance: numBalance,
      color: typeDef.key == 'bank' ? '#7FA98B' : '#E06D53',
      icon: typeDef.icon,
    );
    if (ProfileStore.instance.name.isEmpty) {
      await ProfileStore.instance.save(name, null);
    }
    if (mounted) widget.onComplete();
  }

  void _showAlert(String title, String msg) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(msg),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dark = ThemeStore.instance.isDarkMode;
    final cardBg = ThemeColors.card(dark);
    final secondaryCard = ThemeColors.secondaryCard(dark);
    final border = ThemeColors.border(dark);
    final textPrimary = ThemeColors.textPrimary(dark);
    final textSecondary = ThemeColors.textSecondary(dark);
    final textMuted = ThemeColors.textMuted(dark);
    final expenseAccent = ThemeColors.accentExpense(dark);

    return Scaffold(
      backgroundColor: ThemeColors.bg(dark),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 48),
              Column(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: expenseAccent.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: AppIcon('wallet', size: 32, color: expenseAccent),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Selamat Datang di Money Tracker',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tambahkan akun pertama Anda untuk mulai mencatat arus kas secara offline.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: textMuted),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SectionLabel('Nama Akun', color: textSecondary),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        hintText: 'contoh: Dompet, Bank BCA, GoPay',
                        hintStyle: TextStyle(color: textMuted),
                        filled: true,
                        fillColor: secondaryCard,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      style: TextStyle(fontSize: 16, color: textPrimary),
                    ),
                    const SizedBox(height: 16),
                    SectionLabel('Saldo Awal (IDR)', color: textSecondary),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _balanceController,
                      keyboardType: TextInputType.number,
                      onChanged: (v) {
                        final formatted = formatWithDots(v);
                        if (formatted != v) {
                          _balanceController.value = TextEditingValue(
                            text: formatted,
                            selection: TextSelection.collapsed(
                              offset: formatted.length,
                            ),
                          );
                        }
                      },
                      decoration: InputDecoration(
                        hintText: '0',
                        hintStyle: TextStyle(color: textMuted),
                        filled: true,
                        fillColor: secondaryCard,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      style: TextStyle(fontSize: 16, color: textPrimary),
                    ),
                    const SizedBox(height: 16),
                    SectionLabel('Jenis Akun', color: textSecondary),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _accountTypes.map((item) {
                        final selected = _type == item.key;
                        return GestureDetector(
                          onTap: () => setState(() => _type = item.key),
                          child: Container(
                            width:
                                (MediaQuery.of(context).size.width -
                                    24 * 2 -
                                    8) /
                                2,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: selected ? expenseAccent : border,
                              ),
                              color: selected
                                  ? hexA('#E06D53', 0.1)
                                  : secondaryCard,
                            ),
                            child: Row(
                              children: [
                                AppIcon(
                                  item.icon,
                                  size: 18,
                                  color: selected ? expenseAccent : textMuted,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  item.label,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: selected
                                        ? FontWeight.w800
                                        : FontWeight.w500,
                                    color: selected
                                        ? expenseAccent
                                        : textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _handleSave,
                style: ElevatedButton.styleFrom(
                  backgroundColor: ThemeColors.fillExpense,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text(
                  'Mulai',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
