import 'package:flutter/foundation.dart' show debugPrint, ChangeNotifier;
import '../db/database.dart';
import '../models/models.dart';

/// Category store — mirrors src/store/useCategoryStore.ts
class CategoryStore extends ChangeNotifier {
  CategoryStore._();
  static final CategoryStore instance = CategoryStore._();

  List<Category> _categories = [];
  bool _isLoading = false;

  List<Category> get categories => _categories;
  bool get isLoading => _isLoading;

  Future<void> fetchCategories() async {
    _isLoading = true;
    notifyListeners();
    try {
      _categories = await DB.instance.fetchCategories();
    } catch (e) {
      debugPrint('Error fetching categories: $e');
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<Category> addCategory({
    required String name,
    required String type,
    required String icon,
    required String color,
  }) async {
    final now = DateTime.now().toIso8601String();
    final newCat = Category(
      id: 'cat_${DateTime.now().millisecondsSinceEpoch}_${_rand(5)}',
      name: name,
      type: type,
      icon: icon,
      color: color,
      isSystem: false,
      createdAt: now,
    );
    await DB.instance.db.insert('categories', newCat.toMap());
    await fetchCategories();
    return newCat;
  }

  Future<void> updateCategory(
    String id, {
    String? name,
    String? type,
    String? icon,
    String? color,
  }) async {
    final updates = <String, dynamic>{};
    if (name != null) updates['name'] = name;
    if (type != null) updates['type'] = type;
    if (icon != null) updates['icon'] = icon;
    if (color != null) updates['color'] = color;
    if (updates.isEmpty) return;

    await DB.instance.db.update(
      'categories',
      updates,
      where: 'id = ?',
      whereArgs: [id],
    );
    await fetchCategories();
  }

  Future<void> deleteCategory(String id) async {
    await DB.instance.db.delete('categories', where: 'id = ?', whereArgs: [id]);
    await fetchCategories();
  }

  String _rand(int n) {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final r = StringBuffer();
    for (var i = 0; i < n; i++) {
      r.write(chars[DateTime.now().microsecondsSinceEpoch % chars.length]);
    }
    return r.toString();
  }
}
