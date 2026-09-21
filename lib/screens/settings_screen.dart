import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:image_picker/image_picker.dart';
import '../stores/account_store.dart';
import '../stores/category_store.dart';
import '../stores/profile_store.dart';
import '../stores/theme_store.dart';
import '../models/models.dart';
import '../theme/theme.dart';
import '../components/app_icon.dart';
import '../components/sheet_drag.dart' show hexColor;
import '../services/ai_key.dart';
import '../services/export_import_service.dart';
import '../utils/amount.dart';
import 'categories_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _profileNameCtrl = TextEditingController();
  final _apiKeyCtrl = TextEditingController();
  bool _hasApiKey = false;
  bool _isExporting = false;
  bool _isImporting = false;

  @override
  void initState() {
    super.initState();
    _profileNameCtrl.text = ProfileStore.instance.name;
    _checkApiKey();
  }

  @override
  void dispose() {
    _profileNameCtrl.dispose();
    _apiKeyCtrl.dispose();
    super.dispose();
  }

  Future<void> _checkApiKey() async {
    final key = await AIKeyService.getApiKey();
    if (mounted) setState(() => _hasApiKey = key != null && key.isNotEmpty);
  }

  Future<void> _saveProfileName() async {
    await ProfileStore.instance.save(_profileNameCtrl.text.trim(), ProfileStore.instance.photoUri);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile name updated')),
      );
    }
  }

  Future<void> _pickProfilePhoto() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      await ProfileStore.instance.save(ProfileStore.instance.name, image.path);
      if (mounted) setState(() {});
    }
  }

  Future<void> _saveApiKey() async {
    final key = _apiKeyCtrl.text.trim();
    if (key.isNotEmpty) {
      await AIKeyService.setApiKey(key);
      _apiKeyCtrl.clear();
      await _checkApiKey();
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('API Key saved successfully')),
        );
      }
    }
  }

  Future<void> _showApiKeyDialog() async {
    final dark = ThemeStore.instance.isDarkMode;
    final bg = const Color(0xFF1C1C1E);
    final textPrimary = ThemeColors.textPrimary(dark);
    final textMuted = ThemeColors.textMuted(dark);
    final accent = ThemeColors.accentExpense(dark);

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 16,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: dark ? Colors.white24 : Colors.black26,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: AppIcon('sparkles', size: 20, color: accent),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Gemini AI API Key',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textPrimary),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close, color: textMuted),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Enter your Gemini API Key from Google AI Studio to activate the AI Financial Assistant.',
              style: TextStyle(fontSize: 13, color: textMuted, height: 1.4),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _apiKeyCtrl,
              style: TextStyle(color: textPrimary, fontSize: 14),
              decoration: InputDecoration(
                labelText: 'API Key',
                labelStyle: TextStyle(color: textMuted, fontSize: 13),
                hintText: 'AIzaSy...',
                hintStyle: TextStyle(color: textMuted.withValues(alpha: 0.5)),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: accent, width: 1.5),
                ),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _saveApiKey,
              style: ElevatedButton.styleFrom(
                backgroundColor: accent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: const Text('Save Key', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            ),
            if (_hasApiKey) ...[
              const SizedBox(height: 8),
              TextButton(
                onPressed: () async {
                  await AIKeyService.clearApiKey();
                  await _checkApiKey();
                  if (ctx.mounted) Navigator.pop(ctx);
                },
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Remove Key', style: TextStyle(fontSize: 13)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _showAIPersonaDialog() async {
    final dark = ThemeStore.instance.isDarkMode;
    final bg = const Color(0xFF1C1C1E);
    final textPrimary = ThemeColors.textPrimary(dark);
    final textMuted = ThemeColors.textMuted(dark);
    final accent = ThemeColors.accentExpense(dark);

    String selectedPersona = ProfileStore.instance.aiPersona;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Container(
          decoration: BoxDecoration(
            color: dark ? bg : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 16,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: dark ? Colors.white24 : Colors.black26,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: AppIcon('user', size: 20, color: accent),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'AI Assistant Persona',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textPrimary),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: textMuted),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Choose how your AI Financial Assistant talks to you.',
                style: TextStyle(fontSize: 13, color: textMuted, height: 1.4),
              ),
              const SizedBox(height: 16),
              ...['professional', 'casual', 'strict'].map((persona) {
                final isSelected = selectedPersona == persona;
                String title = persona == 'strict' ? 'Strict & Firm' : (persona == 'casual' ? 'Casual & Friendly' : 'Professional');
                String desc = persona == 'strict' 
                    ? 'AI will be strict, direct, and won\'t hesitate to warn you if you overspend.' 
                    : (persona == 'casual' 
                        ? 'AI will talk like a close friend, using casual and relaxed language.' 
                        : 'AI will act as a polite and formal bank advisor.');
                return GestureDetector(
                  onTap: () {
                    setModalState(() => selectedPersona = persona);
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isSelected ? accent.withValues(alpha: 0.1) : ThemeColors.secondaryCard(dark),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: isSelected ? accent : ThemeColors.border(dark)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: textPrimary)),
                              const SizedBox(height: 4),
                              Text(desc, style: TextStyle(fontSize: 12, color: textMuted)),
                            ],
                          ),
                        ),
                        if (isSelected)
                          Icon(Icons.check_circle, color: accent)
                        else
                          Icon(Icons.circle_outlined, color: textMuted),
                      ],
                    ),
                  ),
                );
              }),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () async {
                  await ProfileStore.instance.savePersona(selectedPersona);
                  if (ctx.mounted) Navigator.pop(ctx);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: accent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('Save Selection', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleExport() async {
    if (_isExporting) return;
    setState(() => _isExporting = true);
    try {
      final data = await ExportImportService.generateXLSXData();
      final path = await ExportImportService.saveBackupFile(data.bytes);
      await ExportImportService.shareFile(data.bytes);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export successful${path != null ? ': $path' : ''}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<void> _handleImport() async {
    if (_isImporting) return;
    setState(() => _isImporting = true);
    try {
      final base64Data = await ExportImportService.pickBackupFileBase64();
      if (base64Data == null) {
        setState(() => _isImporting = false);
        return;
      }

      if (!mounted) return;
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Import Backup (.xlsx)?'),
          content: const Text(
            'This action will replace your current financial data with the backup contents. Are you sure you want to proceed?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber.shade800,
                foregroundColor: Colors.white,
              ),
              child: const Text('Replace Data'),
            ),
          ],
        ),
      );

      if (confirm == true) {
        final result = await ExportImportService.importXLSXReplace(base64Data);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result.message),
              backgroundColor: result.success ? Colors.green.shade700 : Colors.red.shade700,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Import error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isImporting = false);
    }
  }

  Future<void> _showAccountDialog([Account? acc]) async {
    final dark = ThemeStore.instance.isDarkMode;
    final bg = ThemeColors.card(dark);
    final textPrimary = ThemeColors.textPrimary(dark);
    final textMuted = ThemeColors.textMuted(dark);
    final accent = ThemeColors.accentExpense(dark);

    final nameCtrl = TextEditingController(text: acc?.name ?? '');
    final balanceCtrl = TextEditingController(
      text: acc != null ? formatWithDots(acc.balance.round().toString()) : '0',
    );
    String type = acc?.type ?? 'cash';
    String icon = acc?.icon ?? (type == 'bank' ? 'banknote' : (type == 'ewallet' ? 'credit-card' : 'wallet'));
    String color = acc?.color ?? (type == 'bank' ? '#7FA98B' : '#E06D53');

    const accountTypes = [
      (key: 'cash', label: 'Cash', icon: 'wallet'),
      (key: 'bank', label: 'Bank', icon: 'banknote'),
      (key: 'ewallet', label: 'E-Wallet', icon: 'credit-card'),
      (key: 'savings', label: 'Savings', icon: 'piggy-bank'),
    ];

    const colorOptions = ['#E06D53', '#7FA98B', '#E0A75A', '#4A90E2', '#8E44AD'];

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Container(
              decoration: BoxDecoration(
                color: bg,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 16,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 36,
                        height: 4,
                        decoration: BoxDecoration(
                          color: ThemeColors.border(dark),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          acc == null ? 'Add Account' : 'Edit Account',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textPrimary),
                        ),
                        IconButton(
                          icon: Icon(Icons.close, size: 20, color: textMuted),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Account Name Input
                    TextField(
                      controller: nameCtrl,
                      style: TextStyle(color: textPrimary, fontSize: 15),
                      decoration: InputDecoration(
                        labelText: 'Account Name',
                        labelStyle: TextStyle(color: textMuted, fontSize: 13),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Initial Balance Input with thousand separator dot formatting
                    TextField(
                      controller: balanceCtrl,
                      keyboardType: TextInputType.number,
                      style: TextStyle(color: textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
                      onChanged: (v) {
                        final formatted = formatWithDots(v);
                        if (formatted != v) {
                          balanceCtrl.value = TextEditingValue(
                            text: formatted,
                            selection: TextSelection.collapsed(offset: formatted.length),
                          );
                        }
                      },
                      decoration: InputDecoration(
                        prefixText: 'Rp ',
                        prefixStyle: TextStyle(color: accent, fontSize: 18, fontWeight: FontWeight.bold),
                        labelText: 'Initial Balance (Rp)',
                        labelStyle: TextStyle(color: textMuted, fontSize: 13),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Account Type selector chips
                    Text('Account Type', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: textMuted)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: accountTypes.map((item) {
                        final selected = type == item.key;
                        return GestureDetector(
                          onTap: () {
                            setModalState(() {
                              type = item.key;
                              icon = item.icon;
                              if (type == 'bank') color = '#7FA98B';
                              if (type == 'savings') color = '#8E44AD';
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: selected ? accent.withValues(alpha: 0.15) : ThemeColors.secondaryCard(dark),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: selected ? accent : ThemeColors.border(dark)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                AppIcon(item.icon, size: 16, color: selected ? accent : textMuted),
                                const SizedBox(width: 6),
                                Text(
                                  item.label,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                                    color: selected ? accent : textPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),

                    // Color theme options
                    Text('Color Badge', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: textMuted)),
                    const SizedBox(height: 8),
                    Row(
                      children: colorOptions.map((cHex) {
                        final cColor = hexColor(cHex);
                        final selected = color.toUpperCase() == cHex.toUpperCase();
                        return GestureDetector(
                          onTap: () => setModalState(() => color = cHex),
                          child: Container(
                            width: 32,
                            height: 32,
                            margin: const EdgeInsets.only(right: 10),
                            decoration: BoxDecoration(
                              color: cColor,
                              shape: BoxShape.circle,
                              border: selected ? Border.all(color: textPrimary, width: 2.5) : null,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 24),

                    // Action buttons
                    ElevatedButton(
                      onPressed: () async {
                        final name = nameCtrl.text.trim();
                        final balance = parseRawAmount(balanceCtrl.text);
                        if (name.isNotEmpty) {
                          if (acc != null) {
                            await AccountStore.instance.updateAccount(
                              acc.id,
                              name: name,
                              balance: balance,
                              type: type,
                              icon: icon,
                              color: color,
                            );
                          } else {
                            await AccountStore.instance.addAccount(
                              name: name,
                              balance: balance,
                              type: type,
                              icon: icon,
                              color: color,
                            );
                          }
                          if (ctx.mounted) Navigator.pop(ctx);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: Text(
                        acc == null ? 'Create Account' : 'Save Account',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                    ),
                    if (acc != null) ...[
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: () async {
                          await AccountStore.instance.deleteAccount(acc.id);
                          if (ctx.mounted) Navigator.pop(ctx);
                        },
                        style: TextButton.styleFrom(foregroundColor: Colors.red),
                        child: const Text('Delete Account', style: TextStyle(fontSize: 13)),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        ThemeStore.instance,
        AccountStore.instance,
        CategoryStore.instance,
      ]),
      builder: (context, _) {
        final dark = ThemeStore.instance.isDarkMode;
        final textPrimary = ThemeColors.textPrimary(dark);
        final photoUri = ProfileStore.instance.photoUri;
        final accounts = AccountStore.instance.accounts;
        final categories = CategoryStore.instance.categories;

        return Scaffold(
          backgroundColor: ThemeColors.bg(dark),
          appBar: AppBar(
            title: Text('Settings', style: TextStyle(color: textPrimary, fontWeight: FontWeight.bold)),
            backgroundColor: Colors.transparent,
            elevation: 0,
          ),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
              children: [
                // Profile Card
                Card(
                  color: ThemeColors.card(dark),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: _pickProfilePhoto,
                          child: CircleAvatar(
                            radius: 28,
                            backgroundColor: ThemeColors.expense.withValues(alpha: 0.15),
                            backgroundImage: photoUri != null ? FileImage(File(photoUri)) : null,
                            child: photoUri == null ? const AppIcon('user', size: 28, color: ThemeColors.expense) : null,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextField(
                            controller: _profileNameCtrl,
                            decoration: const InputDecoration(
                              labelText: 'User Name',
                              border: InputBorder.none,
                            ),
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textPrimary),
                            onSubmitted: (_) => _saveProfileName(),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.check),
                          onPressed: _saveProfileName,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Theme Settings
                Card(
                  color: ThemeColors.card(dark),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: SwitchListTile(
                    title: Text('Dark Mode', style: TextStyle(color: textPrimary, fontWeight: FontWeight.w600)),
                    secondary: const AppIcon('moon', size: 22, color: ThemeColors.expense),
                    value: dark,
                    onChanged: (val) => ThemeStore.instance.toggleDarkMode(),
                  ),
                ),
                const SizedBox(height: 16),

                // Accounts Header & Section
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Financial Accounts', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textPrimary)),
                    TextButton.icon(
                      onPressed: () => _showAccountDialog(),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Add'),
                    ),
                  ],
                ),
                ...accounts.map(
                  (acc) => Card(
                    color: ThemeColors.card(dark),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: hexColor(acc.color).withValues(alpha: 0.15),
                        child: AppIcon(acc.icon, size: 20, color: hexColor(acc.color)),
                      ),
                      title: Text(acc.name, style: TextStyle(fontWeight: FontWeight.bold, color: textPrimary)),
                      subtitle: Text(formatCurrency(acc.balance)),
                      trailing: const Icon(Icons.edit, size: 18),
                      onTap: () => _showAccountDialog(acc),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Services & Data Backup Section
                Text('Services & Preferences', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textPrimary)),
                const SizedBox(height: 8),
                Card(
                  color: ThemeColors.card(dark),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Column(
                    children: [
                      ListTile(
                        leading: const AppIcon('tag', size: 22, color: ThemeColors.income),
                        title: Text('Manage Categories', style: TextStyle(fontWeight: FontWeight.w600, color: textPrimary)),
                        subtitle: Text(
                          '${categories.where((c) => c.type == 'expense').length} Expense, ${categories.where((c) => c.type == 'income').length} Income categories',
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => Navigator.push(
                          context,
                          CupertinoPageRoute(builder: (_) => const CategoriesScreen()),
                        ),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const AppIcon('sparkles', size: 22, color: ThemeColors.expense),
                        title: Text('Gemini AI Key', style: TextStyle(fontWeight: FontWeight.w600, color: textPrimary)),
                        subtitle: Text(_hasApiKey ? 'Connected' : 'Not configured'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: _showApiKeyDialog,
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: AppIcon('user', size: 22, color: ThemeColors.accentExpense(false)),
                        title: Text('AI Assistant Persona', style: TextStyle(fontWeight: FontWeight.w600, color: textPrimary)),
                        subtitle: Text(
                          ProfileStore.instance.aiPersona == 'strict' 
                              ? 'Strict & Firm' 
                              : ProfileStore.instance.aiPersona == 'casual' 
                                  ? 'Casual & Friendly' 
                                  : 'Professional',
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: _showAIPersonaDialog,
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const AppIcon('file-text', size: 22, color: ThemeColors.income),
                        title: Text('Export Excel Data (.xlsx)', style: TextStyle(fontWeight: FontWeight.w600, color: textPrimary)),
                        subtitle: const Text('Save or share your transaction records'),
                        trailing: _isExporting
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.share, size: 18),
                        onTap: _handleExport,
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const AppIcon('inbox', size: 22, color: ThemeColors.warningDefault),
                        title: Text('Import Excel Data (.xlsx)', style: TextStyle(fontWeight: FontWeight.w600, color: textPrimary)),
                        subtitle: const Text('Restore financial records from backup file'),
                        trailing: _isImporting
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.file_upload_outlined, size: 18),
                        onTap: _handleImport,
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
}
