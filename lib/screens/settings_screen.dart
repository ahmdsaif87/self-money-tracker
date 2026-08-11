import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../db/database.dart';
import '../stores/account_store.dart';
import '../stores/profile_store.dart';
import '../stores/theme_store.dart';
import '../stores/chat_store.dart';
import '../stores/ai_queue_store.dart';
import '../models/models.dart';
import '../theme/theme.dart';
import '../components/app_icon.dart';
import '../components/sheet_drag.dart' show hexA;
import '../services/ai_key.dart';
import '../services/backup_service.dart';
import '../services/export_import_service.dart';
import '../services/gemini_service.dart';
import '../utils/amount.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isExporting = false;
  bool _isImporting = false;
  bool _syncingQueue = false;
  String? _lastExportAt;
  String? _lastExportSummary;
  bool _showKeyInput = false;
  final _keyController = TextEditingController();
  bool _hasKey = false;

  // Import preview
  BackupPreview? _importPreview;
  String? _importFileBase64;

  // Profile state
  final _profileNameController = TextEditingController();
  String? _profilePhoto;

  // Add/edit account sheet state
  Account? _editingAccount;
  final _newAccNameController = TextEditingController();
  final _newAccBalanceController = TextEditingController();
  String _newAccType = 'cash';

  static const _accountTypes = [
    (key: 'cash', label: 'Tunai', icon: 'wallet'),
    (key: 'bank', label: 'Bank', icon: 'banknote'),
    (key: 'ewallet', label: 'E-Wallet', icon: 'credit-card'),
  ];

  @override
  void initState() {
    super.initState();
    _loadKeyState();
    _profileNameController.text = ProfileStore.instance.name;
    ProfileStore.instance.addListener(_onProfileChanged);
  }

  @override
  void dispose() {
    ProfileStore.instance.removeListener(_onProfileChanged);
    _keyController.dispose();
    _profileNameController.dispose();
    _newAccNameController.dispose();
    _newAccBalanceController.dispose();
    super.dispose();
  }

  void _onProfileChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _loadKeyState() async {
    final key = await AIKeyService.getApiKey();
    if (mounted) setState(() => _hasKey = key != null && key.isNotEmpty);
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

  // ---- API Key ----
  Future<void> _handleSaveKey() async {
    final key = _keyController.text.trim();
    if (key.isEmpty) return;
    await AIKeyService.setApiKey(key);
    _keyController.clear();
    if (mounted) {
      setState(() {
        _showKeyInput = false;
        _hasKey = true;
      });
    }
  }

  Future<void> _handleClearKey() async {
    await AIKeyService.clearApiKey();
    if (mounted) setState(() => _hasKey = false);
  }

  // ---- Export ----
  Future<void> _handleExport() async {
    if (_isExporting) return;
    setState(() => _isExporting = true);
    try {
      final data = await ExportImportService.generateXLSXData();
      // Save to documents for user access
      final path = await ExportImportService.saveBackupFile(data.bytes);
      await ExportImportService.shareFile(data.bytes);
      if (mounted) {
        setState(() {
          _lastExportAt = DateTime.now().toIso8601String();
          _lastExportSummary =
              '${data.counts.accounts} akun · ${data.counts.categories} kategori · ${data.counts.transactions} transaksi';
          _isExporting = false;
        });
        _showAlert(
          'Cadangan Dibuat',
          'File cadangan ${data.counts.accounts} akun, ${data.counts.categories} kategori, ${data.counts.transactions} transaksi${path != null ? '\nTersimpan di: $path' : ''}',
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isExporting = false);
        _showAlert('Gagal', 'Gagal membuat cadangan: $e');
      }
    }
  }

  Future<void> _handlePickImport() async {
    final base64Str = await ExportImportService.pickBackupFileBase64();
    if (base64Str == null) return;
    final preview = BackupService.parseXLSXForPreview(base64Str);
    if (!preview.valid) {
      _showAlert('File Tidak Valid', preview.message);
      return;
    }
    if (mounted) {
      setState(() {
        _importPreview = preview;
        _importFileBase64 = base64Str;
      });
      _showImportPreviewSheet();
    }
  }

  void _showImportPreviewSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: ThemeStore.instance.isDarkMode
          ? const Color(0xFF1D1B19)
          : const Color(0xFFFBF8F3),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      isScrollControlled: true,
      builder: (_) => _buildImportPreviewSheet(),
    );
  }

  Future<void> _confirmImport() async {
    if (_isImporting) return;
    final fileToImport = _importFileBase64;
    if (fileToImport == null || fileToImport.isEmpty) return;
    setState(() => _isImporting = true);
    try {
      final result = await ExportImportService.importXLSXReplace(fileToImport);
      if (mounted) {
        setState(() {
          _isImporting = false;
          _importPreview = null;
        });
        Navigator.pop(context);
        if (result.success) {
          _showAlert('Restore Selesai', result.message);
        } else {
          _showAlert('Gagal Restore', result.message);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isImporting = false;
          _importPreview = null;
        });
        Navigator.pop(context);
        _showAlert('Gagal Restore', e.toString());
      }
    }
  }

  // ---- Offline queue ----
  Future<void> _handleSyncQueue() async {
    if (_syncingQueue) return;
    setState(() => _syncingQueue = true);
    try {
      final processed = await GeminiService.syncPendingAIQueue();
      await ChatStore.instance.reflectQueueState();
      await AIQueueStore.instance.fetchQueue();
      if (mounted) {
        setState(() => _syncingQueue = false);
        _showAlert(
          'Antrean Diproses',
          processed > 0
              ? '$processed pertanyaan berhasil diproses.'
              : 'Tidak ada pertanyaan yang menunggu diproses.',
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _syncingQueue = false);
        _showAlert('Gagal', 'Gagal memproses antrean: $e');
      }
    }
  }

  // ---- Reset ----
  Future<void> _handleResetData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Semua Data Lokal'),
        content: const Text(
          'Semua akun, kategori, transaksi, dan riwayat chat akan dihapus permanen. Lanjutkan?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final db = DB.instance.db;
    await db.delete('transactions');
    await db.delete('categories');
    await db.delete('accounts');
    await db.delete('ai_queue');
    await db.delete('chat_messages');
    await AccountStore.instance.fetchAccounts();
    await ChatStore.instance.load();
    await AIQueueStore.instance.fetchQueue();
    if (mounted) _showAlert('Selesai', 'Semua data lokal telah dihapus.');
  }

  // ---- Profile ----
  Future<void> _handleSaveProfile() async {
    await ProfileStore.instance.save(
      _profileNameController.text.trim(),
      _profilePhoto,
    );
    if (mounted) Navigator.pop(context);
  }

  Future<void> _pickProfilePhoto() async {
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );
      if (picked == null) return;
      if (mounted) setState(() => _profilePhoto = picked.path);
    } catch (e) {
      debugPrint('Pick photo error: $e');
    }
  }

  void _openProfileSheet() {
    _profileNameController.text = ProfileStore.instance.name;
    _profilePhoto = ProfileStore.instance.photoUri;
    showModalBottomSheet(
      context: context,
      backgroundColor: ThemeStore.instance.isDarkMode
          ? const Color(0xFF1D1B19)
          : const Color(0xFFFBF8F3),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      isScrollControlled: true,
      builder: (_) => _buildProfileSheet(),
    );
  }

  // ---- Account bottom sheet ----
  void _openAddAcc() {
    setState(() {
      _editingAccount = null;
      _newAccNameController.clear();
      _newAccBalanceController.clear();
      _newAccType = 'cash';
    });
    _showAccountSheet();
  }

  void _openEditAcc(Account acc) {
    setState(() {
      _editingAccount = acc;
      _newAccNameController.text = acc.name;
      _newAccBalanceController.text = acc.balance.round().toString();
      _newAccType = acc.type;
    });
    _showAccountSheet();
  }

  void _showAccountSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: ThemeStore.instance.isDarkMode
          ? const Color(0xFF1D1B19)
          : const Color(0xFFFBF8F3),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      isScrollControlled: true,
      builder: (_) => _buildAccountSheet(),
    );
  }

  Future<void> _handleSaveAcc() async {
    final name = _newAccNameController.text.trim();
    if (name.isEmpty) {
      _showAlert('Nama Diperlukan', 'Masukkan nama akun.');
      return;
    }
    final balance = parseRawAmount(_newAccBalanceController.text);
    if (_editingAccount != null) {
      await AccountStore.instance.updateAccount(
        _editingAccount!.id,
        name: name,
        type: _newAccType,
        balance: balance,
      );
    } else {
      final typeDef = _accountTypes.firstWhere(
        (t) => t.key == _newAccType,
        orElse: () => _accountTypes.first,
      );
      await AccountStore.instance.addAccount(
        name: name,
        type: _newAccType,
        balance: balance,
        color: typeDef.key == 'bank' ? '#7FA98B' : '#E06D53',
        icon: typeDef.icon,
      );
    }
    if (mounted) Navigator.pop(context);
  }

  Future<void> _handleDeleteAcc(Account acc) async {
    final txCount = await DB.instance.db.rawQuery(
      'SELECT COUNT(*) as c FROM transactions WHERE account_id = ? OR to_account_id = ?',
      [acc.id, acc.id],
    );
    final refs = (txCount.first['c'] as int?) ?? 0;
    if (refs > 0) {
      _showAlert(
        'Tidak Bisa Dihapus',
        'Akun punya $refs transaksi — hapus transaksinya dulu.',
      );
      return;
    }
    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Hapus Akun ${acc.name}?'),
        content: const Text('Akun ini akan dihapus permanen.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await AccountStore.instance.deleteAccount(acc.id);
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = ThemeStore.instance.isDarkMode;
    final accounts = AccountStore.instance.accounts;
    final queue = AIQueueStore.instance.queue;
    final pendingCount = queue.where((q) => q.status == 'pending').length;
    final t = _T(dark);

    return Scaffold(
      backgroundColor: ThemeColors.bg(dark),
      body: SafeArea(
        child: Stack(
          children: [
            ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
              children: [
                Text(
                  'Pengaturan',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: t.textPrimary,
                  ),
                ),
                const SizedBox(height: 20),

                // Profile card
                _Card(
                  dark: dark,
                  child: InkWell(
                    onTap: _openProfileSheet,
                    child: Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: ThemeColors.accentExpense(
                              dark,
                            ).withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                            image: ProfileStore.instance.photoUri != null
                                ? DecorationImage(
                                    image: FileImage(
                                      File(ProfileStore.instance.photoUri!),
                                    ),
                                    fit: BoxFit.cover,
                                  )
                                : null,
                          ),
                          child: ProfileStore.instance.photoUri == null
                              ? AppIcon(
                                  'user',
                                  size: 24,
                                  color: ThemeColors.accentExpense(dark),
                                )
                              : null,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                ProfileStore.instance.name.isEmpty
                                    ? 'Nama Anda'
                                    : ProfileStore.instance.name,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: t.textPrimary,
                                ),
                              ),
                              Text(
                                'Ubah profil',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: t.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        AppIcon('chevron-right', size: 18, color: t.textMuted),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Dark mode
                _Card(
                  dark: dark,
                  child: Row(
                    children: [
                      AppIcon(
                        dark ? 'moon' : 'sun',
                        size: 20,
                        color: ThemeColors.accentExpense(dark),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          'Mode Gelap',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: t.textPrimary,
                          ),
                        ),
                      ),
                      Switch(
                        value: dark,
                        onChanged: (_) => ThemeStore.instance.toggleDarkMode(),
                        activeThumbColor: ThemeColors.accentExpense(dark),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // AI API key
                _Card(
                  dark: dark,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          AppIcon(
                            'sparkles',
                            size: 20,
                            color: ThemeColors.accentExpense(dark),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Text(
                              'Asisten AI',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: t.textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Gemini API key digunakan untuk menjawab pertanyaan tentang keuangan Anda.',
                        style: TextStyle(fontSize: 12, color: t.textMuted),
                      ),
                      const SizedBox(height: 12),
                      if (_showKeyInput) ...[
                        TextField(
                          controller: _keyController,
                          obscureText: true,
                          style: TextStyle(color: t.textPrimary),
                          decoration: InputDecoration(
                            hintText: 'Tempel API key...',
                            hintStyle: TextStyle(color: t.textMuted),
                            filled: true,
                            fillColor: t.secondaryCard,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton(
                                onPressed: _handleSaveKey,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: ThemeColors.fillExpense,
                                ),
                                child: const Text(
                                  'Simpan',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            OutlinedButton(
                              onPressed: () => setState(() {
                                _showKeyInput = false;
                                _keyController.clear();
                              }),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: t.textSecondary,
                              ),
                              child: const Text('Batal'),
                            ),
                          ],
                        ),
                      ] else ...[
                        if (_hasKey)
                          Row(
                            children: [
                              Expanded(
                                child: GestureDetector(
                                  onTap: () =>
                                      setState(() => _showKeyInput = true),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                    decoration: BoxDecoration(
                                      color: hexA('#E06D53', 0.15),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Center(
                                      child: Text(
                                        'Ganti Key',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w800,
                                          color: t.expenseAccent,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: GestureDetector(
                                  onTap: _handleClearKey,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: t.dangerText),
                                    ),
                                    child: Center(
                                      child: Text(
                                        'Hapus Key',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w800,
                                          color: t.dangerText,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          )
                        else
                          GestureDetector(
                            onTap: () => setState(() => _showKeyInput = true),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: ThemeColors.fillExpense,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Center(
                                child: Text(
                                  'Masukkan API Key',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Manage accounts
                _Card(
                  dark: dark,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Kelola Akun (${accounts.length})',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: t.textPrimary,
                            ),
                          ),
                          GestureDetector(
                            onTap: _openAddAcc,
                            child: Text(
                              '+ Tambah Akun',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: t.expenseAccent,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ...accounts.map(
                        (acc) => InkWell(
                          onTap: () => _openEditAcc(acc),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              border: Border(
                                bottom: BorderSide(color: t.border),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  acc.name,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: t.textSecondary,
                                  ),
                                ),
                                Text(
                                  formatCurrency(acc.balance),
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    color: t.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Backup & restore
                _Card(
                  dark: dark,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Cadangan & Restore (XLSX)',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: t.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Satu file cadangan berisi semua akun, kategori, dan transaksi. Restore akan mengganti semua data.',
                        style: TextStyle(fontSize: 12, color: t.textMuted),
                      ),
                      const SizedBox(height: 12),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: AppIcon(
                          'download',
                          size: 20,
                          color: t.incomeAccent,
                        ),
                        title: Text(
                          _isExporting
                              ? 'Menyiapkan cadangan...'
                              : 'Export Database (.xlsx)',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: t.textPrimary,
                          ),
                        ),
                        onTap: _handleExport,
                      ),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: AppIcon(
                          'upload',
                          size: 20,
                          color: t.expenseAccent,
                        ),
                        title: Text(
                          'Restore dari File .xlsx',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: t.textPrimary,
                          ),
                        ),
                        onTap: _handlePickImport,
                      ),
                      if (_lastExportAt != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            'Cadangan terakhir: ${_lastExportAt!.split('T').first}'
                            '${_lastExportSummary != null ? ' · $_lastExportSummary' : ''}',
                            style: TextStyle(fontSize: 11, color: t.textMuted),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Offline queue
                _Card(
                  dark: dark,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Status Antrean Offline',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: t.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Pertanyaan AI: ${queue.length} ($pendingCount menunggu)',
                        style: TextStyle(fontSize: 13, color: t.textSecondary),
                      ),
                      if (queue.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        GestureDetector(
                          onTap: _syncingQueue ? null : _handleSyncQueue,
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: _syncingQueue
                                  ? t.secondaryCard
                                  : ThemeColors.fillExpense,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Center(
                              child: Text(
                                _syncingQueue
                                    ? 'Memproses...'
                                    : 'Proses Antrean Sekarang',
                                style: TextStyle(
                                  color: _syncingQueue
                                      ? t.textSecondary
                                      : Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Danger zone
                GestureDetector(
                  onTap: _handleResetData,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: ThemeColors.dangerSurface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0x40B84C34)),
                    ),
                    child: Center(
                      child: Text(
                        'Hapus Semua Data Lokal',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: t.dangerText,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ============ Bottom Sheet: Tambah/Ubah Akun ============
  Widget _buildAccountSheet() {
    final dark = ThemeStore.instance.isDarkMode;
    final t = _T(dark);
    final editing = _editingAccount;
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: t.border,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                editing != null ? 'Ubah Akun' : 'Tambah Akun',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: t.textPrimary,
                ),
              ),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: AppIcon('x', size: 20, color: t.textPrimary),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            'Nama Akun',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: t.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _newAccNameController,
            style: TextStyle(color: t.textPrimary),
            decoration: InputDecoration(
              hintText: 'contoh: Dompet, Bank BCA, GoPay',
              hintStyle: TextStyle(color: t.textMuted),
              filled: true,
              fillColor: t.secondaryCard,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            editing != null ? 'Saldo Akun (IDR)' : 'Saldo Awal (IDR)',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: t.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _newAccBalanceController,
            keyboardType: TextInputType.number,
            onChanged: (v) {
              final formatted = formatWithDots(v);
              if (formatted != v) {
                _newAccBalanceController.value = TextEditingValue(
                  text: formatted,
                  selection: TextSelection.collapsed(offset: formatted.length),
                );
              }
            },
            style: TextStyle(color: t.textPrimary),
            decoration: InputDecoration(
              hintText: 'contoh: 1.500.000',
              hintStyle: TextStyle(color: t.textMuted),
              filled: true,
              fillColor: t.secondaryCard,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Jenis Akun',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: t.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _accountTypes.map((at) {
              final selected = _newAccType == at.key;
              return GestureDetector(
                onTap: () => setState(() {
                  _newAccType = at.key;
                }),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: selected ? t.expenseAccent : t.border,
                    ),
                    color: selected ? hexA('#E06D53', 0.1) : t.secondaryCard,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AppIcon(
                        at.icon,
                        size: 16,
                        color: selected ? t.expenseAccent : t.textMuted,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        at.label,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: selected ? t.expenseAccent : t.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _handleSaveAcc,
            style: ElevatedButton.styleFrom(
              backgroundColor: ThemeColors.fillExpense,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: Text(
              editing != null ? 'Simpan Perubahan' : 'Simpan Akun',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 15,
              ),
            ),
          ),
          if (editing != null) ...[
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: () => _handleDeleteAcc(editing),
              style: OutlinedButton.styleFrom(
                foregroundColor: t.dangerText,
                side: BorderSide(color: t.dangerText),
                backgroundColor: dark
                    ? const Color(0x1AB84C34)
                    : const Color(0xFFF5E7E2),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text(
                'Hapus Akun',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ],
          const SizedBox(height: 10),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Batal',
              style: TextStyle(
                color: t.textSecondary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============ Bottom Sheet: Ubah Profil ============
  Widget _buildProfileSheet() {
    final dark = ThemeStore.instance.isDarkMode;
    final t = _T(dark);
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: t.border,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Ubah Profil',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: t.textPrimary,
                ),
              ),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: AppIcon('x', size: 20, color: t.textPrimary),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Avatar + pick photo
          Center(
            child: GestureDetector(
              onTap: _pickProfilePhoto,
              child: Stack(
                children: [
                  Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: t.secondaryCard,
                      border: Border.all(color: t.border, width: 2),
                      image: _profilePhoto != null
                          ? DecorationImage(
                              image: FileImage(File(_profilePhoto!)),
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    child: _profilePhoto == null
                        ? AppIcon('user', size: 40, color: t.textMuted)
                        : null,
                  ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: const BoxDecoration(
                        color: Color(0xFFE06D53),
                        shape: BoxShape.circle,
                      ),
                      child: const AppIcon(
                        'camera',
                        size: 14,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: GestureDetector(
              onTap: _pickProfilePhoto,
              child: Text(
                'Pilih Foto',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: t.expenseAccent,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Nama',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: t.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _profileNameController,
            style: TextStyle(color: t.textPrimary),
            decoration: InputDecoration(
              hintText: 'Masukkan nama Anda',
              hintStyle: TextStyle(color: t.textMuted),
              filled: true,
              fillColor: t.secondaryCard,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _handleSaveProfile,
            style: ElevatedButton.styleFrom(
              backgroundColor: ThemeColors.fillExpense,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: const Text(
              'Simpan Profil',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 15,
              ),
            ),
          ),
          const SizedBox(height: 10),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Batal',
              style: TextStyle(
                color: t.textSecondary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============ Bottom Sheet: Preview Import ============
  Widget _buildImportPreviewSheet() {
    final dark = ThemeStore.instance.isDarkMode;
    final t = _T(dark);
    final preview = _importPreview;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: t.border,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Periksa Cadangan',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: t.textPrimary,
                ),
              ),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: AppIcon('x', size: 20, color: t.textPrimary),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _ImportCount(
                label: 'Akun',
                value: preview?.accounts ?? 0,
                color: t.textPrimary,
                dark: dark,
              ),
              _ImportCount(
                label: 'Kategori',
                value: preview?.categories ?? 0,
                color: t.textPrimary,
                dark: dark,
              ),
              _ImportCount(
                label: 'Transaksi',
                value: preview?.transactions ?? 0,
                color: t.textPrimary,
                dark: dark,
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: ThemeColors.dangerSurface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0x40B84C34)),
            ),
            child: Column(
              children: [
                Text(
                  'PERHATIAN',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: t.dangerText,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Restore akan MENGGANTI semua data saat ini dan tidak bisa dibatalkan.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: t.dangerText),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _isImporting ? null : _confirmImport,
            style: ElevatedButton.styleFrom(
              backgroundColor: ThemeColors.dangerDefault,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: Text(
              _isImporting ? 'Mengembalikan data...' : 'Ya, Ganti Semua Data',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 15,
              ),
            ),
          ),
          const SizedBox(height: 10),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Batal',
              style: TextStyle(
                color: t.textSecondary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ImportCount extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  final bool dark;

  const _ImportCount({
    required this.label,
    required this.value,
    required this.color,
    required this.dark,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          '$value',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(fontSize: 11, color: ThemeColors.textMuted(dark)),
        ),
      ],
    );
  }
}

class _T {
  final bool dark;
  _T(this.dark);
  Color get cardBg => ThemeColors.card(dark);
  Color get secondaryCard => ThemeColors.secondaryCard(dark);
  Color get border => ThemeColors.border(dark);
  Color get textPrimary => ThemeColors.textPrimary(dark);
  Color get textSecondary => ThemeColors.textSecondary(dark);
  Color get textMuted => ThemeColors.textMuted(dark);
  Color get incomeAccent => ThemeColors.accentIncome(dark);
  Color get expenseAccent => ThemeColors.accentExpense(dark);
  Color get warningAccent => ThemeColors.accentWarning(dark);
  Color get dangerText =>
      dark ? const Color(0xFFF0907A) : ThemeColors.dangerDefault;
}

class _Card extends StatelessWidget {
  final Widget child;
  final bool dark;

  const _Card({required this.child, required this.dark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ThemeColors.card(dark),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ThemeColors.border(dark)),
      ),
      child: child,
    );
  }
}
