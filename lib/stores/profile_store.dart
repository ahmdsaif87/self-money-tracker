import 'package:flutter/foundation.dart';
import '../db/database.dart';

/// Profile store — mirrors src/store/useProfileStore.ts
class ProfileStore extends ChangeNotifier {
  ProfileStore._();
  static final ProfileStore instance = ProfileStore._();

  String _name = '';
  String? _photoUri;

  String get name => _name;
  String? get photoUri => _photoUri;

  static const _nameKey = 'profile_name';
  static const _photoKey = 'profile_photo';

  Future<void> load() async {
    final results = await Future.wait([
      DB.instance.getSetting(_nameKey),
      DB.instance.getSetting(_photoKey),
    ]);
    _name = results[0] ?? '';
    _photoUri = results[1];
    notifyListeners();
  }

  Future<void> save(String name, String? photoUri) async {
    await DB.instance.setSetting(_nameKey, name);
    await DB.instance.setSetting(_photoKey, photoUri ?? '');
    _name = name;
    _photoUri = photoUri;
    notifyListeners();
  }
}
