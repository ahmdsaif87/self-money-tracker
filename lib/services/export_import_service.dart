import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart' as path_provider;
import 'package:flutter/foundation.dart';
import '../db/database.dart';
import '../stores/account_store.dart';
import '../stores/category_store.dart';
import '../stores/transaction_store.dart';
import 'backup_service.dart';

/// Export/Import service — mirrors src/services/exportImportService.ts
class ExportImportService {
  static Future<({Uint8List bytes, BackupCounts counts, String exportedAt})>
  generateXLSXData() async {
    final db = DB.instance.db;
    final accRows = await db.query('accounts');
    final catRows = await db.query('categories');
    final txRows = await db.query('transactions');

    final bytes = await BackupService.generateXLSXBytes();
    return (
      bytes: bytes,
      counts: BackupCounts(
        accounts: accRows.length,
        categories: catRows.length,
        transactions: txRows.length,
      ),
      exportedAt: DateTime.now().toUtc().toIso8601String(),
    );
  }

  static Future<({bool success, String message, BackupCounts counts})>
  importXLSXReplace(String base64Data) async {
    final preview = BackupService.parseXLSXForPreview(base64Data);
    if (!preview.valid) {
      return (
        success: false,
        message: preview.message,
        counts: BackupCounts(accounts: 0, categories: 0, transactions: 0),
      );
    }

    try {
      final extracted = BackupService.extractSheets(base64Data);
      final db = DB.instance.db;

      // Destructive replace: wipe existing data first (respects foreign keys)
      await db.delete('transactions');
      await db.delete('categories');
      await db.delete('accounts');

      if (extracted.accounts.isNotEmpty) {
        for (final row in extracted.accounts) {
          await db.insert('accounts', _snake(row));
        }
      }
      if (extracted.categories.isNotEmpty) {
        for (final row in extracted.categories) {
          await db.insert('categories', _snake(row));
        }
      }
      if (extracted.transactions.isNotEmpty) {
        for (final row in extracted.transactions) {
          await db.insert('transactions', _snake(row));
        }
      }

      await AccountStore.instance.fetchAccounts();
      await CategoryStore.instance.fetchCategories();
      await TransactionStore.instance.fetchTransactions();

      return (
        success: true,
        message:
            'Restore selesai: ${extracted.accounts.length} akun, ${extracted.categories.length} kategori, ${extracted.transactions.length} transaksi.',
        counts: BackupCounts(
          accounts: extracted.accounts.length,
          categories: extracted.categories.length,
          transactions: extracted.transactions.length,
        ),
      );
    } catch (e) {
      return (
        success: false,
        message: e.toString(),
        counts: BackupCounts(accounts: 0, categories: 0, transactions: 0),
      );
    }
  }

  static Map<String, dynamic> _snake(Map<String, dynamic> row) {
    // Convert camelCase headers from xlsx to snake_case DB columns.
    final out = <String, dynamic>{};
    for (final entry in row.entries) {
      final k = entry.key;
      final snake = k.replaceAllMapped(
        RegExp('([A-Z])'),
        (m) => '_${m[1]!.toLowerCase()}',
      );
      out[snake] = entry.value;
    }
    return out;
  }

  static Future<String?> saveBackupFile(Uint8List bytes) async {
    if (kIsWeb) return null;
    try {
      final dir = await path_provider.getApplicationDocumentsDirectory();
      final filename =
          'money-tracker-backup-${DateTime.now().toIso8601String().split('T').first}.xlsx';
      final file = File('${dir.path}/$filename');
      await file.writeAsBytes(bytes);
      return file.path;
    } catch (e) {
      debugPrint('Save backup error: $e');
      return null;
    }
  }

  static Future<String?> pickBackupFileBase64() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return null;
    final f = result.files.first;
    if (f.bytes != null) {
      return base64Encode(f.bytes!);
    }
    if (f.path != null) {
      final bytes = await File(f.path!).readAsBytes();
      return base64Encode(bytes);
    }
    return null;
  }

  static Future<void> shareFile(Uint8List bytes, {String? fileName}) async {
    final dir = await path_provider.getTemporaryDirectory();
    final name = fileName ?? 'money-tracker-backup.xlsx';
    final file = File('${dir.path}/$name');
    await file.writeAsBytes(bytes);
    await SharePlus.instance.share(
      ShareParams(files: [XFile(file.path)], fileNameOverrides: [name]),
    );
  }
}
