import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../stores/account_store.dart';
import '../stores/category_store.dart';
import '../stores/transaction_store.dart';
import '../stores/theme_store.dart';
import '../models/models.dart';
import '../theme/theme.dart';
import '../components/sheet_drag.dart' show hexColor;
import '../components/app_date_picker.dart';
import '../components/app_picker_field.dart';
import '../utils/amount.dart';
import '../utils/date.dart';

/// Clean, beautifully styled transaction modal sheet.
class AddTransactionScreen extends StatefulWidget {
  final VoidCallback onClose;
  final Transaction? editingTx;

  const AddTransactionScreen({
    super.key,
    required this.onClose,
    this.editingTx,
  });

  static Future<void> show(BuildContext context, {Transaction? editingTx}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => AddTransactionScreen(
        onClose: () => Navigator.of(ctx).pop(),
        editingTx: editingTx,
      ),
    );
  }

  @override
  State<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends State<AddTransactionScreen> {
  String _type = 'expense';
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  String? _selectedAccountId;
  String? _toAccountId;
  String? _selectedCategoryId;
  DateTime _date = DateTime.now();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final tx = widget.editingTx;
    if (tx != null) {
      _type = tx.type;
      _amountController.text = formatWithDots(tx.amount.round().toString());
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
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _onAmountChanged(String val) {
    final formatted = formatWithDots(val);
    if (formatted != val) {
      _amountController.value = TextEditingValue(
        text: formatted,
        selection: TextSelection.collapsed(offset: formatted.length),
      );
    }
    setState(() {});
  }

  bool get _isAmountValid => parseRawAmount(_amountController.text) > 0;
  bool get _isFromValid => _selectedAccountId != null && _selectedAccountId!.isNotEmpty;
  bool get _isToValid => _type != 'transfer' || (_toAccountId != null && _toAccountId != _selectedAccountId);
  bool get _isCategoryValid => _type == 'transfer' || (_selectedCategoryId != null && _selectedCategoryId!.isNotEmpty);
  bool get _isFormValid => _isAmountValid && _isFromValid && _isToValid && _isCategoryValid;

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
          note: _noteController.text.trim().isEmpty ? null : _noteController.text.trim(),
          date: dateStr,
        );
      } else {
        await TransactionStore.instance.addTransaction(
          accountId: _selectedAccountId!,
          toAccountId: _toAccountId,
          categoryId: _type == 'transfer' ? null : _selectedCategoryId,
          amount: amount,
          type: _type,
          note: _noteController.text.trim().isEmpty ? null : _noteController.text.trim(),
          date: dateStr,
        );
      }
      widget.onClose();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Maaf, terjadi kesalahan saat menyimpan transaksi. Silakan coba beberapa saat lagi.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _handleDelete() async {
    final tx = widget.editingTx;
    if (tx == null) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Transaction?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await TransactionStore.instance.deleteTransaction(tx.id);
      widget.onClose();
    }
  }

  Future<void> _pickDate() async {
    FocusScope.of(context).unfocus();
    final picked = await AppDatePickerSheet.show(
      context,
      initialDate: _date,
    );
    if (picked != null && mounted) {
      setState(() => _date = picked);
    }
  }

  Widget _buildTypeTab(String value, String label, Color activeColor, bool dark) {
    final isSelected = _type == value;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          FocusScope.of(context).unfocus();
          setState(() {
            _type = value;
            _selectedCategoryId = null;
            _toAccountId = null;
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 10),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected ? activeColor : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                color: isSelected ? Colors.white : ThemeColors.textSecondary(dark),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ThemeStore.instance,
      builder: (context, _) {
        final dark = ThemeStore.instance.isDarkMode;
        final bg = ThemeColors.card(dark);
        final textPrimary = ThemeColors.textPrimary(dark);
        final accounts = AccountStore.instance.accounts;
        final categories = CategoryStore.instance.categories.where((c) => c.type == _type).toList();

        final accountPickerItems = accounts.map((a) {
          final color = a.type == 'cash'
              ? Colors.amber
              : (a.type == 'savings' ? Colors.purple : Colors.blue);
          return AppPickerItem<String>(
            id: a.id,
            title: a.name,
            subtitle: formatCurrency(a.balance),
            color: color,
          );
        }).toList();

        final categoryPickerItems = categories.map((c) {
          return AppPickerItem<String>(
            id: c.id,
            title: c.name,
            color: hexColor(c.color),
          );
        }).toList();

        return Container(
          decoration: BoxDecoration(
            color: bg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 12,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Drag handle
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 14),
                    decoration: BoxDecoration(
                      color: ThemeColors.border(dark),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                // Header Title
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      widget.editingTx == null ? 'Add Transaction' : 'Edit Transaction',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textPrimary),
                    ),
                    IconButton(
                      icon: Icon(Icons.close, size: 20, color: ThemeColors.textMuted(dark)),
                      onPressed: widget.onClose,
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Custom 3-Tab Type Selector
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: ThemeColors.secondaryCard(dark),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: ThemeColors.border(dark)),
                  ),
                  child: Row(
                    children: [
                      _buildTypeTab('expense', 'Expense', ThemeColors.accentExpense(dark), dark),
                      _buildTypeTab('income', 'Income', ThemeColors.accentIncome(dark), dark),
                      _buildTypeTab('transfer', 'Transfer', ThemeColors.accentWarning(dark), dark),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Amount Input with thousand separator dots
                TextField(
                  controller: _amountController,
                  keyboardType: TextInputType.number,
                  autofocus: widget.editingTx == null,
                  onChanged: _onAmountChanged,
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: textPrimary),
                  decoration: InputDecoration(
                    prefixText: 'Rp ',
                    prefixStyle: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: ThemeColors.accentExpense(dark)),
                    labelText: 'Amount',
                    labelStyle: TextStyle(color: ThemeColors.textMuted(dark), fontSize: 13),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: ThemeColors.accentExpense(dark), width: 1.5),
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Account selection (From Account)
                AppPickerField<String>(
                  label: _type == 'transfer' ? 'From Account' : 'Account',
                  selectedValue: _selectedAccountId,
                  items: accountPickerItems,
                  placeholder: 'Select Account',
                  onChanged: (val) => setState(() => _selectedAccountId = val),
                ),
                const SizedBox(height: 12),

                // Transfer To Account (if type is transfer)
                if (_type == 'transfer') ...[
                  AppPickerField<String>(
                    label: 'To Account',
                    selectedValue: _toAccountId,
                    items: accountPickerItems.where((a) => a.id != _selectedAccountId).toList(),
                    placeholder: 'Select Destination Account',
                    onChanged: (val) => setState(() => _toAccountId = val),
                  ),
                  const SizedBox(height: 12),
                ],

                // Category Selector (if type is not transfer)
                if (_type != 'transfer') ...[
                  AppPickerField<String>(
                    label: 'Category',
                    selectedValue: _selectedCategoryId,
                    items: categoryPickerItems,
                    placeholder: 'Select Category',
                    onChanged: (val) => setState(() => _selectedCategoryId = val),
                  ),
                  const SizedBox(height: 12),
                ],

                // Custom Date Picker Field
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Date',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: ThemeColors.textMuted(dark),
                      ),
                    ),
                    const SizedBox(height: 6),
                    InkWell(
                      onTap: _pickDate,
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: dark ? const Color(0xFF2C2C2E) : const Color(0xFFF2F2F7),
                          border: Border.all(color: ThemeColors.border(dark)),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.calendar_today_rounded, size: 18, color: ThemeColors.accentExpense(dark)),
                            const SizedBox(width: 12),
                            Text(
                              DateFormat('EEEE, d MMMM yyyy').format(_date),
                              style: TextStyle(color: textPrimary, fontSize: 14, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Note Input
                TextField(
                  controller: _noteController,
                  style: TextStyle(color: textPrimary, fontSize: 14),
                  decoration: InputDecoration(
                    labelText: 'Note (Optional)',
                    labelStyle: TextStyle(color: ThemeColors.textMuted(dark), fontSize: 13),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
                const SizedBox(height: 20),

                // Submit Button & Delete Option
                ElevatedButton(
                  onPressed: _isFormValid && !_isSaving ? _handleSave : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ThemeColors.accentExpense(dark),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : Text(
                          widget.editingTx == null ? 'Save Transaction' : 'Update Transaction',
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                ),

                if (widget.editingTx != null) ...[
                  const SizedBox(height: 6),
                  TextButton(
                    onPressed: _handleDelete,
                    style: TextButton.styleFrom(foregroundColor: Colors.red),
                    child: const Text('Delete Transaction', style: TextStyle(fontSize: 13)),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
