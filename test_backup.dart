import 'dart:convert';
import 'package:flutter/widgets.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'lib/db/database.dart';
import 'lib/services/export_import_service.dart';

void main() async {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    await DB.instance.initDatabase();
    print('DB initialized.');

    // Export
    final exportResult = await ExportImportService.generateXLSXData();
    print('Exported bytes: ${exportResult.bytes.length}');
    print('Exported counts: ${exportResult.counts.accounts} accounts, ${exportResult.counts.categories} categories, ${exportResult.counts.transactions} transactions');

    // Encode to base64
    final base64Data = base64Encode(exportResult.bytes);

    // Import
    print('\nStarting import...');
    final importResult = await ExportImportService.importXLSXReplace(base64Data);
    
    if (importResult.success) {
      print('✅ SUCCESS: ${importResult.message}');
    } else {
      print('❌ FAILED: ${importResult.message}');
    }
  } catch (e) {
    print('❌ ERROR: $e');
  }
}
