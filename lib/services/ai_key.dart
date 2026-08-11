import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// AI key storage — mirrors src/services/aiKey.ts
/// Tries env var (--dart-define=GEMINI_API_KEY), then bundled .env asset, then SecureStorage fallback.
class AIKeyService {
  static const _storageKey = 'gemini_api_key';
  static const _secureStorage = FlutterSecureStorage();

  static const _envKey = String.fromEnvironment('GEMINI_API_KEY', defaultValue: '');

  static Future<String?> getApiKey() async {
    if (_envKey.isNotEmpty) return _envKey.trim();
    // Fallback: read bundled .env asset (works on all platforms).
    try {
      final envFile = await rootBundle.loadString('.env');
      for (final line in envFile.split('\n')) {
        final trimmed = line.trim();
        if (trimmed.startsWith('GEMINI_API_KEY=')) {
          final v = trimmed.substring('GEMINI_API_KEY='.length).trim();
          if (v.isNotEmpty && !v.startsWith('#')) return v;
        }
      }
    } catch (e) {
      debugPrint('.env asset read error: $e');
    }
    try {
      return await _secureStorage.read(key: _storageKey);
    } catch (e) {
      debugPrint('SecureStore read error: $e');
      return null;
    }
  }

  static Future<void> setApiKey(String key) async {
    final trimmed = key.trim();
    if (trimmed.isEmpty) return;
    try {
      await _secureStorage.write(key: _storageKey, value: trimmed);
    } catch (e) {
      debugPrint('SecureStore write error: $e');
    }
  }

  static Future<void> clearApiKey() async {
    try {
      await _secureStorage.delete(key: _storageKey);
    } catch (e) {
      debugPrint('SecureStore delete error: $e');
    }
  }
}
