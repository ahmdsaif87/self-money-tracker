import 'dart:convert';
import 'dart:typed_data';
import 'package:excel/excel.dart';
import '../db/database.dart';

/// Backup format — mirrors src/services/backupFormat.ts
/// XLSX with sheets: Accounts, Categories, Transactions, Meta.
class BackupFormat {
  static const int schemaVersion = 1;
  static const String appVersion = '1.0.0';
}

class BackupCounts {
  final int accounts;
  final int categories;
  final int transactions;

  BackupCounts({required this.accounts, required this.categories, required this.transactions});
}

class BackupPreview {
  final bool valid;
  final String message;
  final int accounts;
  final int categories;
  final int transactions;
  final int? schemaVersion;
  final String? exportedAt;

  BackupPreview({
    required this.valid,
    required this.message,
    required this.accounts,
    required this.categories,
    required this.transactions,
    this.schemaVersion,
    this.exportedAt,
  });
}

class BackupService {
  /// Build XLSX bytes from current DB contents.
  static Future<Uint8List> generateXLSXBytes() async {
    final db = DB.instance.db;
    final accRows = await db.query('accounts');
    final catRows = await db.query('categories');
    final txRows = await db.query('transactions');

    final excel = Excel.createExcel();
    final accountsSheet = excel['Accounts'];
    final categoriesSheet = excel['Categories'];
    final transactionsSheet = excel['Transactions'];
    final metaSheet = excel['Meta'];

    void appendRows(Sheet sheet, List<Map<String, dynamic>> rows) {
      if (rows.isEmpty) return;
      final headers = rows.first.keys.toList();
      sheet.appendRow(headers.map(_toCellValue).toList());
      for (final row in rows) {
        sheet.appendRow(headers.map((h) => _toCellValue(row[h])).toList());
      }
    }

    appendRows(accountsSheet, accRows);
    appendRows(categoriesSheet, catRows);
    appendRows(transactionsSheet, txRows);

    final exportedAt = DateTime.now().toUtc().toIso8601String();
    metaSheet.appendRow(<CellValue?>[
      TextCellValue('key'),
      TextCellValue('value'),
    ]);
    metaSheet.appendRow(<CellValue?>[
      TextCellValue('schemaVersion'),
      IntCellValue(BackupFormat.schemaVersion),
    ]);
    metaSheet.appendRow(<CellValue?>[
      TextCellValue('appVersion'),
      TextCellValue(BackupFormat.appVersion),
    ]);
    metaSheet.appendRow(<CellValue?>[
      TextCellValue('exportedAt'),
      TextCellValue(exportedAt),
    ]);

    final saved = excel.save();
    return Uint8List.fromList(saved ?? []);
  }

  static CellValue? _toCellValue(dynamic v) {
    if (v == null) return null;
    if (v is int) return IntCellValue(v);
    if (v is double) return DoubleCellValue(v);
    if (v is num) return IntCellValue(v.toInt());
    return TextCellValue(v.toString());
  }

  /// Parse a base64 XLSX for preview validation.
  static BackupPreview parseXLSXForPreview(String base64Data) {
    try {
      final bytes = base64Decode(base64Data);
      final excel = Excel.decodeBytes(bytes);
      final sheets = excel.tables.keys.toSet();

      const required = ['Accounts', 'Categories', 'Transactions'];
      for (final sheet in required) {
        if (!sheets.contains(sheet)) {
          return BackupPreview(
            valid: false,
            message: 'File cadangan tidak lengkap: sheet "$sheet" tidak ditemukan.',
            accounts: 0, categories: 0, transactions: 0,
          );
        }
      }

      int? schemaVersion;
      String? exportedAt;
      if (sheets.contains('Meta')) {
        final meta = excel.tables['Meta'];
        for (final row in meta!.rows) {
          final cells = row.map((c) => c?.value?.toString() ?? '').toList();
          if (cells.length >= 2) {
            if (cells[0] == 'schemaVersion') schemaVersion = int.tryParse(cells[1]);
            if (cells[0] == 'exportedAt') exportedAt = cells[1];
          }
        }
      }

      if (schemaVersion != null && schemaVersion > BackupFormat.schemaVersion) {
        return BackupPreview(
          valid: false,
          message: 'Versi cadangan ($schemaVersion) lebih baru dari yang didukung (${BackupFormat.schemaVersion}). Perbarui aplikasi terlebih dahulu.',
          accounts: 0, categories: 0, transactions: 0,
          schemaVersion: schemaVersion, exportedAt: exportedAt,
        );
      }

      int countRows(String name) {
        final t = excel.tables[name];
        if (t == null) return 0;
        var count = 0;
        for (final row in t.rows) {
          if (row.any((c) => c != null && c.value != null)) count++;
        }
        return count;
      }

      return BackupPreview(
        valid: true,
        message: 'File cadangan valid.',
        accounts: countRows('Accounts'),
        categories: countRows('Categories'),
        transactions: countRows('Transactions'),
        schemaVersion: schemaVersion ?? BackupFormat.schemaVersion,
        exportedAt: exportedAt,
      );
    } catch (_) {
      return BackupPreview(
        valid: false,
        message: 'Gagal membaca file cadangan.',
        accounts: 0, categories: 0, transactions: 0,
      );
    }
  }

  /// Extract sheet rows as maps (header -> value).
  static ({List<Map<String, dynamic>> accounts, List<Map<String, dynamic>> categories, List<Map<String, dynamic>> transactions})
      extractSheets(String base64Data) {
    final bytes = base64Decode(base64Data);
    final excel = Excel.decodeBytes(bytes);

    List<Map<String, dynamic>> rowsOf(String name) {
      final t = excel.tables[name];
      if (t == null) return [];
      final out = <Map<String, dynamic>>[];
      final rows = t.rows;
      if (rows.isEmpty) return out;
      final headers = rows.first.map((c) => c?.value?.toString() ?? '').toList();
      for (var i = 1; i < rows.length; i++) {
        final row = rows[i];
        if (row.every((c) => c == null || c.value == null)) continue;
        final map = <String, dynamic>{};
        for (var j = 0; j < headers.length && j < row.length; j++) {
          final cell = row[j];
          map[headers[j]] = cell?.value;
        }
        out.add(map);
      }
      return out;
    }

    return (
      accounts: rowsOf('Accounts'),
      categories: rowsOf('Categories'),
      transactions: rowsOf('Transactions'),
    );
  }
}
