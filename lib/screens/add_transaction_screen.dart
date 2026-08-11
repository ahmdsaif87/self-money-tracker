import 'package:flutter/material.dart';
import '../stores/account_store.dart';
import '../stores/category_store.dart';
import '../stores/transaction_store.dart';
import '../stores/theme_store.dart';
import '../models/models.dart';
import '../theme/theme.dart';
import '../components/app_icon.dart';
import '../components/section_label.dart';
import '../components/sheet_drag.dart';
import '../components/draggable_sheet.dart';
import '../utils/amount.dart';
import '../utils/date.dart';

class AddTransactionScreen extends StatefulWidget {
  final VoidCallback onClose;
  final Transaction? editingTx;

  const AddTransactionScreen({
    super.key,
    required this.onClose,
    this.editingTx,
  });

  @override
  State<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends State<AddTransactionScreen>
    with SingleTickerProviderStateMixin {
  String _type = 'expense';
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  String? _selectedAccountId;
  String? _toAccountId;
  String? _selectedCategoryId;
  DateTime _date = DateTime.now();
  bool _isSaving = false;
  bool _formTouched = false;
  bool _closing = false;
  late final AnimationController _entranceCtrl;

  // Category modal
  bool _showAddCatModal = false;
  Category? _editingCategory;
  final _newCatNameController = TextEditingController();
  final _iconSearchController = TextEditingController();
  String _newCatIcon = 'tag';
  String _newCatColor = '#E06D53';
  bool _showMoreColors = false;

  static const _availableIcons = [
    'shopping-cart',
    'utensils',
    'file-text',
    'car',
    'shopping-bag',
    'briefcase',
    'laptop',
    'trending-up',
    'coffee',
    'house',
    'gift',
    'heart',
    'tv',
    'book',
    'zap',
    'smile',
    'star',
    'wrench',
    'shield',
    'tag',
    'dollar-sign',
    'film',
    'music',
    'package',
    'activity',
    'award',
    'phone',
    'camera',
    'wifi',
    'key',
    'scissors',
    'piggy-bank',
    'credit-card',
    'wallet',
  ];

  static const _recommendedColors = [
    '#E06D53',
    '#C8543B',
    '#D97C65',
    '#7FA98B',
    '#587D63',
    '#8C827A',
  ];
  static const _moreColors = [
    '#B84C34',
    '#F0907A',
    '#E58A75',
    '#97BC9F',
    '#A3C4AC',
    '#5C544D',
  ];

  @override
  void initState() {
    super.initState();
    _entranceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
      reverseDuration: const Duration(milliseconds: 200),
    )..forward();
    final tx = widget.editingTx;
    if (tx != null) {
      _type = tx.type;
      _amountController.text = tx.amount.round().toString();
      _selectedAccountId = tx.accountId;
      _toAccountId = tx.toAccountId;
      _selectedCategoryId = tx.categoryId;
      _noteController.text = tx.note ?? '';
      _date = parseLocalDate(tx.date);
      if (_date.millisecondsSinceEpoch == 0) _date = DateTime.now();
    } else {
      final accs = AccountStore.instance.accounts;
      if (accs.isNotEmpty) _selectedAccountId = accs.first.id;
    }
  }

  @override
  void dispose() {
    _entranceCtrl.dispose();
    _amountController.dispose();
    _noteController.dispose();
    _newCatNameController.dispose();
    _iconSearchController.dispose();
    super.dispose();
  }

  bool get _hasDraft {
    final tx = widget.editingTx;
    if (tx != null) {
      return parseRawAmount(_amountController.text) != tx.amount ||
          _noteController.text.trim() != (tx.note ?? '') ||
          _selectedAccountId != tx.accountId ||
          _selectedCategoryId != tx.categoryId ||
          _toAccountId != tx.toAccountId ||
          _type != tx.type ||
          toLocalDateKey(_date) != tx.date;
    }
    return parseRawAmount(_amountController.text) > 0 ||
        _noteController.text.trim().isNotEmpty;
  }

  void _closeSheet() {
    if (_closing) return;
    setState(() => _closing = true);
    _entranceCtrl.reverse().whenComplete(() {
      if (mounted) widget.onClose();
    });
  }

  void _requestClose() {
    if (widget.editingTx == null && _hasDraft && !_isSaving) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Buang transaksi?'),
          content: const Text(
            'Transaksi yang belum selesai akan hilang. Lanjutkan membuangnya?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Lanjut Mengisi'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                _closeSheet();
              },
              child: const Text('Buang'),
            ),
          ],
        ),
      );
    } else {
      _closeSheet();
    }
  }

  void _switchType(String next) {
    setState(() {
      _type = next;
      if (next == 'transfer') {
        _selectedCategoryId = null;
      } else {
        _toAccountId = null;
        if (_selectedCategoryId != null) {
          final cat = CategoryStore.instance.categories
              .where((c) => c.id == _selectedCategoryId)
              .firstOrNull;
          if (cat == null || cat.type != next) _selectedCategoryId = null;
        }
      }
      _formTouched = true;
    });
  }

  bool get _isAmountValid => parseRawAmount(_amountController.text) > 0;
  bool get _isFromValid =>
      _selectedAccountId != null && _selectedAccountId!.isNotEmpty;
  bool get _isToValid =>
      _type != 'transfer' ||
      (_toAccountId != null && _toAccountId != _selectedAccountId);
  bool get _isCategoryValid =>
      _type == 'transfer' ||
      (_selectedCategoryId != null && _selectedCategoryId!.isNotEmpty);
  bool get _isFormValid =>
      _isAmountValid && _isFromValid && _isToValid && _isCategoryValid;

  String get _validationHint {
    if (!_isAmountValid) return 'Masukkan nominal lebih dari 0.';
    if (!_isFromValid) return 'Pilih akun.';
    if (!_isToValid) {
      if (_type == 'transfer' && AccountStore.instance.accounts.length < 2) {
        return 'Butuh minimal 2 akun untuk transfer. Tambahkan akun di Pengaturan.';
      }
      return 'Pilih akun tujuan yang berbeda.';
    }
    return 'Pilih kategori.';
  }

  Future<void> _handleSave() async {
    if (!_isFormValid || _isSaving) return;
    setState(() => _isSaving = true);
    try {
      final amount = parseRawAmount(_amountController.text);
      final dateStr = toLocalDateKey(_date);
      final tx = widget.editingTx;
      if (tx != null) {
        await TransactionStore.instance.updateTransaction(
          tx.id,
          accountId: _selectedAccountId!,
          toAccountId: _toAccountId,
          categoryId: _type == 'transfer' ? null : _selectedCategoryId,
          amount: amount,
          type: _type,
          note: _noteController.text.trim().isEmpty
              ? null
              : _noteController.text.trim(),
          date: dateStr,
        );
      } else {
        await TransactionStore.instance.addTransaction(
          accountId: _selectedAccountId!,
          toAccountId: _toAccountId,
          categoryId: _type == 'transfer' ? null : _selectedCategoryId,
          amount: amount,
          type: _type,
          note: _noteController.text.trim().isEmpty
              ? null
              : _noteController.text.trim(),
          date: dateStr,
        );
      }
      if (mounted) _closeSheet();
    } catch (e) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Gagal Menyimpan'),
            content: Text('Transaksi tidak tersimpan. $e'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _handleDelete() {
    final tx = widget.editingTx;
    if (tx == null) return;
    final isTransfer = tx.type == 'transfer';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Transaksi'),
        content: Text(
          isTransfer
              ? 'Transaksi transfer ini akan dihapus, dan saldo kedua akun akan dikembalikan. Lanjutkan?'
              : 'Transaksi ini akan dihapus dan saldo akun akan dikembalikan. Lanjutkan?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await TransactionStore.instance.deleteTransaction(tx.id);
              if (mounted) _closeSheet();
            },
            child: const Text('Hapus', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  // ---- Category modal helpers ----
  void _openNewCategory() {
    setState(() {
      _editingCategory = null;
      _newCatNameController.clear();
      _newCatIcon = 'tag';
      _newCatColor = '#E06D53';
      _showMoreColors = false;
      _iconSearchController.clear();
      _showAddCatModal = true;
    });
  }

  void _openEditCategory(Category cat) {
    setState(() {
      _editingCategory = cat;
      _newCatNameController.text = cat.name;
      _newCatIcon = cat.icon;
      _newCatColor = cat.color;
      _showMoreColors = false;
      _iconSearchController.clear();
      _showAddCatModal = true;
    });
  }

  Future<void> _handleSaveCategory() async {
    final name = _newCatNameController.text.trim();
    if (name.isEmpty) {
      _showAlert('Nama Diperlukan', 'Masukkan nama kategori.');
      return;
    }
    final catType =
        _editingCategory?.type ?? (_type == 'income' ? 'income' : 'expense');
    final categories = CategoryStore.instance.categories;
    final isDuplicate = categories.any(
      (c) =>
          c.id != _editingCategory?.id &&
          c.type == catType &&
          c.name.toLowerCase() == name.toLowerCase(),
    );
    if (isDuplicate) {
      _showAlert('Kategori Sudah Ada', 'Kategori "$name" sudah tersedia.');
      return;
    }

    if (_editingCategory != null) {
      await CategoryStore.instance.updateCategory(
        _editingCategory!.id,
        name: name,
        icon: _newCatIcon,
        color: _newCatColor,
      );
    } else {
      final created = await CategoryStore.instance.addCategory(
        name: name,
        type: catType,
        icon: _newCatIcon,
        color: _newCatColor,
      );
      setState(() => _selectedCategoryId = created.id);
    }
    if (mounted) setState(() => _showAddCatModal = false);
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

  String _formatDateDisplay(DateTime d) {
    const days = ['Min', 'Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab'];
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
    return '${days[d.weekday % 7]}, ${d.day} ${months[d.month - 1]} ${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final dark = ThemeStore.instance.isDarkMode;
    final accounts = AccountStore.instance.accounts;
    final categories = CategoryStore.instance.categories;

    final cardBg = ThemeColors.card(dark);
    final chipBg = dark
        ? const Color(0xFF2A2724)
        : ThemeColors.lightSecondaryCard;
    final border = ThemeColors.border(dark);
    final textPrimary = ThemeColors.textPrimary(dark);
    final textSecondary = ThemeColors.textSecondary(dark);
    final textMuted = ThemeColors.textMuted(dark);
    final dangerText = dark
        ? const Color(0xFFF0907A)
        : ThemeColors.dangerDefault;

    final accent = _type == 'income'
        ? ThemeColors.accentIncome(dark)
        : _type == 'transfer'
        ? ThemeColors.accentWarning(dark)
        : ThemeColors.accentExpense(dark);
    final accentFill = _type == 'income'
        ? ThemeColors.fillIncome
        : _type == 'transfer'
        ? ThemeColors.fillWarning
        : ThemeColors.fillExpense;

    final filteredCategories = _type == 'transfer'
        ? <Category>[]
        : categories.where((c) => c.type == _type).toList();

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _requestClose();
      },
      child: Scaffold(
        backgroundColor: Colors.black54,
        body: SafeArea(
          child: Stack(
            children: [
              Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  // Dim backdrop
                  Expanded(
                    flex: 1,
                    child: GestureDetector(
                      onTap: _requestClose,
                      child: Container(color: Colors.transparent),
                    ),
                  ),
                  // Sheet
                  Flexible(
                    flex: 12,
                    child: FadeTransition(
                      opacity: _entranceCtrl,
                      child: SlideTransition(
                        position:
                            Tween<Offset>(
                              begin: const Offset(0, 1),
                              end: Offset.zero,
                            ).animate(
                              CurvedAnimation(
                                parent: _entranceCtrl,
                                curve: Curves.easeOutCubic,
                              ),
                            ),
                        child: DraggableSheet(
                          scrollable: true,
                          onDismiss: _requestClose,
                          child: Container(
                            constraints: BoxConstraints(
                              maxHeight:
                                  MediaQuery.of(context).size.height * 0.92,
                            ),
                            decoration: BoxDecoration(
                              color: dark
                                  ? const Color(0xFF1D1B19)
                                  : const Color(0xFFFBF8F3),
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(36),
                              ),
                              border: Border(top: BorderSide(color: border)),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 48,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: dark
                                        ? const Color(0xFF3D3936)
                                        : const Color(0xFFE8DED1),
                                    borderRadius: BorderRadius.circular(99),
                                  ),
                                ),
                                Flexible(
                                  child: SingleChildScrollView(
                                    padding: const EdgeInsets.fromLTRB(
                                      24,
                                      16,
                                      24,
                                      24,
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        // Header
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              widget.editingTx != null
                                                  ? 'Ubah Transaksi'
                                                  : 'Tambah Transaksi',
                                              style: TextStyle(
                                                fontSize: 24,
                                                fontWeight: FontWeight.w800,
                                                color: textPrimary,
                                              ),
                                            ),
                                            GestureDetector(
                                              onTap: _requestClose,
                                              child: Container(
                                                padding: const EdgeInsets.all(
                                                  10,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: dark
                                                      ? const Color(0xFF2A2724)
                                                      : ThemeColors
                                                            .lightSecondaryCard,
                                                  shape: BoxShape.circle,
                                                ),
                                                child: AppIcon(
                                                  'x',
                                                  size: 18,
                                                  color: textPrimary,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 20),

                                        // Type selector
                                        Container(
                                          padding: const EdgeInsets.all(6),
                                          decoration: BoxDecoration(
                                            color: dark
                                                ? const Color(0xFF282522)
                                                : const Color(0xFFEFE8DF),
                                            borderRadius: BorderRadius.circular(
                                              999,
                                            ),
                                          ),
                                          child: Row(
                                            children: [
                                              _TypeOption(
                                                key_: 'expense',
                                                label: 'Pengeluaran',
                                                icon: 'arrow-up-right',
                                                fill: ThemeColors.fillExpense,
                                                active: _type == 'expense',
                                                onTap: () =>
                                                    _switchType('expense'),
                                                muted: textMuted,
                                              ),
                                              _TypeOption(
                                                key_: 'income',
                                                label: 'Pemasukan',
                                                icon: 'arrow-down-left',
                                                fill: ThemeColors.fillIncome,
                                                active: _type == 'income',
                                                onTap: () =>
                                                    _switchType('income'),
                                                muted: textMuted,
                                              ),
                                              _TypeOption(
                                                key_: 'transfer',
                                                label: 'Transfer',
                                                icon: 'arrow-right-left',
                                                fill: ThemeColors.fillWarning,
                                                active: _type == 'transfer',
                                                onTap: () =>
                                                    _switchType('transfer'),
                                                muted: textMuted,
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(height: 20),

                                        // Amount input
                                        Container(
                                          padding: const EdgeInsets.all(24),
                                          decoration: BoxDecoration(
                                            color: dark
                                                ? const Color(0xFF242220)
                                                : Colors.white,
                                            borderRadius: BorderRadius.circular(
                                              24,
                                            ),
                                            border: Border.all(color: border),
                                          ),
                                          child: Column(
                                            children: [
                                              SectionLabel(
                                                'Nominal (IDR)',
                                                color: textSecondary,
                                              ),
                                              const SizedBox(height: 8),
                                              TextField(
                                                controller: _amountController,
                                                keyboardType:
                                                    TextInputType.number,
                                                textAlign: TextAlign.center,
                                                onChanged: (v) {
                                                  setState(() {
                                                    _formTouched = true;
                                                    final formatted =
                                                        formatWithDots(v);
                                                    if (formatted != v) {
                                                      _amountController
                                                          .value = TextEditingValue(
                                                        text: formatted,
                                                        selection:
                                                            TextSelection.collapsed(
                                                              offset: formatted
                                                                  .length,
                                                            ),
                                                      );
                                                    }
                                                  });
                                                },
                                                style: TextStyle(
                                                  fontSize: 36,
                                                  fontWeight: FontWeight.w800,
                                                  color: accent,
                                                ),
                                                decoration: InputDecoration(
                                                  hintText: '0',
                                                  hintStyle: TextStyle(
                                                    color: textMuted,
                                                  ),
                                                  border: InputBorder.none,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(height: 20),

                                        // Transfer accounts or account+category
                                        if (_type == 'transfer')
                                          _TransferSection(
                                            accounts: accounts,
                                            selectedAccountId:
                                                _selectedAccountId,
                                            toAccountId: _toAccountId,
                                            onSelectFrom: (id) => setState(() {
                                              _selectedAccountId = id;
                                              if (_toAccountId == id) {
                                                _toAccountId = null;
                                              }
                                              _formTouched = true;
                                            }),
                                            onSelectTo: (id) => setState(() {
                                              _toAccountId = id;
                                              _formTouched = true;
                                            }),
                                            chipBg: chipBg,
                                            border: border,
                                            accent: accent,
                                            muted: textMuted,
                                            textPrimary: textPrimary,
                                            dangerText: dangerText,
                                            dark: dark,
                                          )
                                        else ...[
                                          // Account select
                                          SectionLabel(
                                            'Pilih Akun',
                                            color: textSecondary,
                                          ),
                                          const SizedBox(height: 10),
                                          SizedBox(
                                            height: 56,
                                            child: ListView(
                                              scrollDirection: Axis.horizontal,
                                              children: accounts.map((acc) {
                                                final isSelected =
                                                    _selectedAccountId ==
                                                    acc.id;
                                                return GestureDetector(
                                                  onTap: () => setState(() {
                                                    _selectedAccountId = acc.id;
                                                    _formTouched = true;
                                                  }),
                                                  child: Container(
                                                    margin:
                                                        const EdgeInsets.only(
                                                          right: 10,
                                                        ),
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 16,
                                                          vertical: 12,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            16,
                                                          ),
                                                      border: Border.all(
                                                        color: isSelected
                                                            ? accent
                                                            : border,
                                                      ),
                                                      color: isSelected
                                                          ? hexA(
                                                              '#E06D53',
                                                              0.15,
                                                            )
                                                          : chipBg,
                                                    ),
                                                    child: Row(
                                                      children: [
                                                        AppIcon(
                                                          acc.icon,
                                                          size: 18,
                                                          color: isSelected
                                                              ? accent
                                                              : textMuted,
                                                        ),
                                                        const SizedBox(
                                                          width: 8,
                                                        ),
                                                        Text(
                                                          acc.name,
                                                          style: TextStyle(
                                                            fontSize: 14,
                                                            fontWeight:
                                                                FontWeight.w800,
                                                            color: isSelected
                                                                ? accent
                                                                : textPrimary,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                );
                                              }).toList(),
                                            ),
                                          ),
                                          const SizedBox(height: 20),

                                          // Category grid
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              SectionLabel(
                                                'Kategori',
                                                color: textSecondary,
                                              ),
                                              Row(
                                                children: [
                                                  if (_selectedCategoryId !=
                                                      null)
                                                    GestureDetector(
                                                      onTap: () {
                                                        final cat = categories
                                                            .where(
                                                              (c) =>
                                                                  c.id ==
                                                                  _selectedCategoryId,
                                                            )
                                                            .firstOrNull;
                                                        if (cat != null) {
                                                          _openEditCategory(
                                                            cat,
                                                          );
                                                        }
                                                      },
                                                      child: Padding(
                                                        padding:
                                                            const EdgeInsets.only(
                                                              right: 12,
                                                            ),
                                                        child: Row(
                                                          children: [
                                                            AppIcon(
                                                              'pencil',
                                                              size: 14,
                                                              color:
                                                                  ThemeColors.accentExpense(
                                                                    dark,
                                                                  ),
                                                            ),
                                                            const SizedBox(
                                                              width: 4,
                                                            ),
                                                            Text(
                                                              'Ubah',
                                                              style: TextStyle(
                                                                fontSize: 12,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w700,
                                                                color:
                                                                    ThemeColors.accentExpense(
                                                                      dark,
                                                                    ),
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    ),
                                                  GestureDetector(
                                                    onTap: _openNewCategory,
                                                    child: Row(
                                                      children: [
                                                        AppIcon(
                                                          'circle-plus',
                                                          size: 16,
                                                          color:
                                                              ThemeColors.accentExpense(
                                                                dark,
                                                              ),
                                                        ),
                                                        const SizedBox(
                                                          width: 4,
                                                        ),
                                                        Text(
                                                          '+ Kategori Baru',
                                                          style: TextStyle(
                                                            fontSize: 12,
                                                            fontWeight:
                                                                FontWeight.w700,
                                                            color:
                                                                ThemeColors.accentExpense(
                                                                  dark,
                                                                ),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 12),
                                          GridView.count(
                                            crossAxisCount: 3,
                                            shrinkWrap: true,
                                            physics:
                                                const NeverScrollableScrollPhysics(),
                                            mainAxisSpacing: 10,
                                            crossAxisSpacing: 10,
                                            children: filteredCategories.map((
                                              cat,
                                            ) {
                                              final isSelected =
                                                  _selectedCategoryId == cat.id;
                                              return GestureDetector(
                                                onTap: () => setState(() {
                                                  _selectedCategoryId = cat.id;
                                                  _formTouched = true;
                                                }),
                                                onLongPress: () =>
                                                    _openEditCategory(cat),
                                                child: Container(
                                                  padding: const EdgeInsets.all(
                                                    12,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          16,
                                                        ),
                                                    border: Border.all(
                                                      color: isSelected
                                                          ? accent
                                                          : border,
                                                    ),
                                                    color: isSelected
                                                        ? hexA(
                                                            _type == 'income'
                                                                ? '#7FA98B'
                                                                : '#E06D53',
                                                            0.15,
                                                          )
                                                        : cardBg,
                                                  ),
                                                  child: Column(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .center,
                                                    children: [
                                                      AppIcon(
                                                        cat.icon,
                                                        size: 24,
                                                        color: isSelected
                                                            ? accent
                                                            : hexColor(
                                                                cat.color,
                                                              ),
                                                      ),
                                                      const SizedBox(height: 4),
                                                      Text(
                                                        cat.name,
                                                        maxLines: 1,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                        textAlign:
                                                            TextAlign.center,
                                                        style: TextStyle(
                                                          fontSize: 11,
                                                          fontWeight:
                                                              FontWeight.w800,
                                                          color: isSelected
                                                              ? accent
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
                                        const SizedBox(height: 20),

                                        // Note & date
                                        Container(
                                          padding: const EdgeInsets.all(16),
                                          decoration: BoxDecoration(
                                            color: dark
                                                ? const Color(0xFF242220)
                                                : Colors.white,
                                            borderRadius: BorderRadius.circular(
                                              16,
                                            ),
                                            border: Border.all(color: border),
                                          ),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              SectionLabel(
                                                'Catatan / Deskripsi',
                                                color: textSecondary,
                                              ),
                                              const SizedBox(height: 8),
                                              TextField(
                                                controller: _noteController,
                                                onChanged: (_) => setState(
                                                  () => _formTouched = true,
                                                ),
                                                style: TextStyle(
                                                  color: textPrimary,
                                                ),
                                                decoration: InputDecoration(
                                                  hintText:
                                                      'Contoh: Belanja bulanan, gaji, dll.',
                                                  hintStyle: TextStyle(
                                                    color: textMuted,
                                                  ),
                                                  enabledBorder:
                                                      UnderlineInputBorder(
                                                        borderSide: BorderSide(
                                                          color: border,
                                                        ),
                                                      ),
                                                  focusedBorder:
                                                      UnderlineInputBorder(
                                                        borderSide: BorderSide(
                                                          color: accent,
                                                        ),
                                                      ),
                                                ),
                                              ),
                                              const SizedBox(height: 16),
                                              SectionLabel(
                                                'Tanggal Transaksi',
                                                color: textSecondary,
                                              ),
                                              const SizedBox(height: 8),
                                              GestureDetector(
                                                onTap: () async {
                                                  final picked =
                                                      await showDatePicker(
                                                        context: context,
                                                        initialDate: _date,
                                                        firstDate: DateTime(
                                                          2000,
                                                        ),
                                                        lastDate: DateTime.now()
                                                            .add(
                                                              const Duration(
                                                                days: 365,
                                                              ),
                                                            ),
                                                      );
                                                  if (picked != null) {
                                                    setState(
                                                      () => _date = picked,
                                                    );
                                                  }
                                                },
                                                child: Container(
                                                  padding: const EdgeInsets.all(
                                                    12,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          12,
                                                        ),
                                                    border: Border.all(
                                                      color: border,
                                                    ),
                                                    color: dark
                                                        ? const Color(
                                                            0xFF2A2724,
                                                          )
                                                        : const Color(
                                                            0xFFF4EFEA,
                                                          ),
                                                  ),
                                                  child: Row(
                                                    children: [
                                                      AppIcon(
                                                        'calendar',
                                                        size: 18,
                                                        color:
                                                            ThemeColors.accentExpense(
                                                              dark,
                                                            ),
                                                      ),
                                                      const SizedBox(width: 10),
                                                      Expanded(
                                                        child: Text(
                                                          _formatDateDisplay(
                                                            _date,
                                                          ),
                                                          style: TextStyle(
                                                            fontSize: 16,
                                                            fontWeight:
                                                                FontWeight.w700,
                                                            color: textPrimary,
                                                          ),
                                                        ),
                                                      ),
                                                      Text(
                                                        'Ubah',
                                                        style: TextStyle(
                                                          fontSize: 12,
                                                          fontWeight:
                                                              FontWeight.w700,
                                                          color:
                                                              ThemeColors.accentExpense(
                                                                dark,
                                                              ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(height: 16),

                                        // Validation hint
                                        if (_formTouched && !_isFormValid)
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              bottom: 12,
                                            ),
                                            child: Text(
                                              _validationHint,
                                              style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w600,
                                                color: dangerText,
                                              ),
                                            ),
                                          ),

                                        // Submit
                                        ElevatedButton(
                                          onPressed: _isFormValid && !_isSaving
                                              ? _handleSave
                                              : null,
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: _isFormValid
                                                ? accentFill
                                                : (dark
                                                      ? const Color(0xFF3D3936)
                                                      : const Color(
                                                          0xFFD8CFC5,
                                                        )),
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 16,
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(16),
                                            ),
                                          ),
                                          child: Text(
                                            _isSaving
                                                ? 'Menyimpan...'
                                                : widget.editingTx != null
                                                ? 'Simpan Perubahan'
                                                : 'Simpan Transaksi',
                                            style: TextStyle(
                                              color: !_isFormValid && !dark
                                                  ? const Color(0xFF5C544D)
                                                  : Colors.white,
                                              fontSize: 18,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                        ),

                                        // Delete
                                        if (widget.editingTx != null)
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              top: 12,
                                            ),
                                            child: OutlinedButton(
                                              onPressed: _handleDelete,
                                              style: OutlinedButton.styleFrom(
                                                foregroundColor: dangerText,
                                                side: BorderSide(
                                                  color: dangerText,
                                                ),
                                                backgroundColor: dark
                                                    ? const Color(0x1AB84C34)
                                                    : const Color(0xFFF5E7E2),
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      vertical: 16,
                                                    ),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(16),
                                                ),
                                              ),
                                              child: const Text(
                                                'Hapus Transaksi',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w800,
                                                  fontSize: 14,
                                                ),
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              // Category modal overlay
              if (_showAddCatModal) _buildCategoryModal(),
            ],
          ),
        ),
      ),
    );
  } // ============ Modal: Tambah/Ubah Kategori ============

  Widget _buildCategoryModal() {
    final dark = ThemeStore.instance.isDarkMode;
    final cardBg = ThemeColors.card(dark);
    final textPrimary = ThemeColors.textPrimary(dark);
    final textSecondary = ThemeColors.textSecondary(dark);
    final textMuted = ThemeColors.textMuted(dark);
    final expenseAccent = ThemeColors.accentExpense(dark);
    final editing = _editingCategory;
    final catType = editing?.type ?? (_type == 'income' ? 'income' : 'expense');

    final filteredIcons = _availableIcons
        .where((ic) => ic.contains(_iconSearchController.text.toLowerCase()))
        .toList();

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: cardBg,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${editing != null ? 'Ubah Kategori' : 'Tambah Kategori'} (${catType == 'income' ? 'Pemasukan' : 'Pengeluaran'})',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: textPrimary,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => setState(() => _showAddCatModal = false),
                    child: AppIcon('x', size: 20, color: textPrimary),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _newCatNameController,
                style: TextStyle(color: textPrimary),
                decoration: InputDecoration(
                  hintText: 'Nama Kategori (contoh: Kopi, Hobi)',
                  hintStyle: TextStyle(color: textMuted),
                  filled: true,
                  fillColor: dark
                      ? const Color(0xFF191817)
                      : const Color(0xFFF4EFEA),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Pilih Icon',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _iconSearchController,
                onChanged: (_) => setState(() {}),
                style: TextStyle(color: textPrimary),
                decoration: InputDecoration(
                  hintText: 'Cari icon...',
                  hintStyle: TextStyle(color: textMuted),
                  filled: true,
                  fillColor: dark
                      ? const Color(0xFF191817)
                      : const Color(0xFFF4EFEA),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 48,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: filteredIcons.map((ic) {
                    final selected = _newCatIcon == ic;
                    return GestureDetector(
                      onTap: () => setState(() => _newCatIcon = ic),
                      child: Container(
                        width: 44,
                        height: 44,
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: selected
                                ? expenseAccent
                                : (dark
                                      ? const Color(0xFF3D3936)
                                      : const Color(0xFFEAE3DA)),
                          ),
                          color: selected
                              ? hexA('#E06D53', 0.2)
                              : (dark
                                    ? const Color(0xFF191817)
                                    : const Color(0xFFF4EFEA)),
                        ),
                        child: AppIcon(
                          ic,
                          size: 22,
                          color: selected ? expenseAccent : textMuted,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Pilih Warna Accent',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _recommendedColors.map((col) {
                  final selected = _newCatColor == col;
                  return GestureDetector(
                    onTap: () => setState(() => _newCatColor = col),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: hexColor(col),
                        shape: BoxShape.circle,
                      ),
                      child: selected
                          ? const AppIcon(
                              'check',
                              size: 16,
                              color: Colors.white,
                            )
                          : null,
                    ),
                  );
                }).toList(),
              ),
              if (_showMoreColors) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _moreColors.map((col) {
                    final selected = _newCatColor == col;
                    return GestureDetector(
                      onTap: () => setState(() => _newCatColor = col),
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: hexColor(col),
                          shape: BoxShape.circle,
                        ),
                        child: selected
                            ? const AppIcon(
                                'check',
                                size: 16,
                                color: Colors.white,
                              )
                            : null,
                      ),
                    );
                  }).toList(),
                ),
              ],
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () => setState(() => _showMoreColors = !_showMoreColors),
                child: Text(
                  _showMoreColors ? 'Sembunyikan warna lain' : 'Warna lain +',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: expenseAccent,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _handleSaveCategory,
                style: ElevatedButton.styleFrom(
                  backgroundColor: ThemeColors.fillExpense,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: Text(
                  editing != null ? 'Simpan Perubahan' : 'Simpan Kategori Baru',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
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

class _TypeOption extends StatelessWidget {
  final String key_;
  final String label;
  final String icon;
  final Color fill;
  final bool active;
  final VoidCallback onTap;
  final Color muted;

  const _TypeOption({
    required this.key_,
    required this.label,
    required this.icon,
    required this.fill,
    required this.active,
    required this.onTap,
    required this.muted,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: active ? fill : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AppIcon(icon, size: 18, color: active ? Colors.white : muted),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: active ? Colors.white : muted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TransferSection extends StatelessWidget {
  final List<Account> accounts;
  final String? selectedAccountId;
  final String? toAccountId;
  final ValueChanged<String> onSelectFrom;
  final ValueChanged<String> onSelectTo;
  final Color chipBg;
  final Color border;
  final Color accent;
  final Color muted;
  final Color textPrimary;
  final Color dangerText;
  final bool dark;

  const _TransferSection({
    required this.accounts,
    required this.selectedAccountId,
    required this.toAccountId,
    required this.onSelectFrom,
    required this.onSelectTo,
    required this.chipBg,
    required this.border,
    required this.accent,
    required this.muted,
    required this.textPrimary,
    required this.dangerText,
    required this.dark,
  });

  Widget _chip(
    Account acc,
    String? selectedId,
    ValueChanged<String> onSelect, {
    bool disabled = false,
  }) {
    final isSelected = selectedId == acc.id;
    return GestureDetector(
      onTap: disabled ? null : () => onSelect(acc.id),
      child: Container(
        margin: const EdgeInsets.only(right: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isSelected ? accent : border),
          color: isSelected ? hexA('#E06D53', 0.15) : chipBg,
        ),
        child: Opacity(
          opacity: disabled ? 0.4 : 1,
          child: Row(
            children: [
              AppIcon(acc.icon, size: 18, color: isSelected ? accent : muted),
              const SizedBox(width: 8),
              Text(
                acc.name,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: isSelected ? accent : textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sameSelected =
        toAccountId != null && toAccountId == selectedAccountId;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionLabel('Dari Akun', color: ThemeColors.textSecondary(dark)),
        const SizedBox(height: 10),
        SizedBox(
          height: 56,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: accounts
                .map((acc) => _chip(acc, selectedAccountId, onSelectFrom))
                .toList(),
          ),
        ),
        const SizedBox(height: 20),
        SectionLabel('Ke Akun', color: ThemeColors.textSecondary(dark)),
        const SizedBox(height: 10),
        SizedBox(
          height: 56,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: accounts
                .map(
                  (acc) => _chip(
                    acc,
                    toAccountId,
                    onSelectTo,
                    disabled: acc.id == selectedAccountId,
                  ),
                )
                .toList(),
          ),
        ),
        if (sameSelected)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Akun asal dan tujuan harus berbeda.',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: dangerText,
              ),
            ),
          ),
      ],
    );
  }
}
