import 'package:flutter/foundation.dart';
import '../db/database.dart';

/// Profile store — mirrors src/store/useProfileStore.ts
class ProfileStore extends ChangeNotifier {
  ProfileStore._();
  static final ProfileStore instance = ProfileStore._();

  String _name = '';
  String? _photoUri;
  String _aiPersona = 'professional';

  String get name => _name;
  String? get photoUri => _photoUri;
  String get aiPersona => _aiPersona;

  static const _nameKey = 'profile_name';
  static const _photoKey = 'profile_photo';
  static const _personaKey = 'ai_persona';

  Future<void> load() async {
    final results = await Future.wait([
      DB.instance.getSetting(_nameKey),
      DB.instance.getSetting(_photoKey),
      DB.instance.getSetting(_personaKey),
    ]);
    _name = results[0] ?? '';
    _photoUri = results[1];
    _aiPersona = results[2] ?? 'professional';
    notifyListeners();
  }

  Future<void> save(String name, String? photoUri) async {
    await DB.instance.setSetting(_nameKey, name);
    await DB.instance.setSetting(_photoKey, photoUri ?? '');
    _name = name;
    _photoUri = photoUri;
    notifyListeners();
  }

  Future<void> savePersona(String persona) async {
    await DB.instance.setSetting(_personaKey, persona);
    _aiPersona = persona;
    notifyListeners();
  }
}
