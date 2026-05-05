import 'package:flutter/material.dart';
import '../database/app_database.dart';
import '../models/custom_category.dart';

/// Manages user-created custom categories, persisted via SQLite.
/// Built-in categories live in the [categories] table and are read-only.
class CategoryService extends ChangeNotifier {
  final List<CustomCategory> _categories = [];

  List<CustomCategory> get all => List.unmodifiable(_categories);

  List<CustomCategory> get expenseCategories =>
      _categories.where((c) => c.isExpense).toList();

  List<CustomCategory> get incomeCategories =>
      _categories.where((c) => !c.isExpense).toList();

  CustomCategory? getById(String id) {
    try {
      return _categories.firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
    }
  }

  CategoryService() {
    _load();
  }

  // ── Persistence ────────────────────────────────────────────────────────────

  Future<void> _load() async {
    try {
      final rows = await AppDatabase.instance.query(
        'custom_categories',
        orderBy: 'label ASC',
      );
      _categories
        ..clear()
        ..addAll(rows.map(_fromRow));
      notifyListeners();
    } catch (e) {
      debugPrint('[CategoryService] load error: $e');
    }
  }

  /// Reloads all custom categories from the database.
  /// Call this after a backup restore to refresh in-memory state.
  Future<void> reload() => _load();

  // ── CRUD ───────────────────────────────────────────────────────────────────

  Future<void> add(CustomCategory category) async {
    await AppDatabase.instance.insert('custom_categories', _toRow(category));
    await _load();
  }

  Future<void> update(CustomCategory updated) async {
    await AppDatabase.instance.update(
      'custom_categories',
      _toRow(updated),
      where: 'id = ?',
      whereArgs: [updated.id],
    );
    await _load();
  }

  Future<void> remove(String id) async {
    await AppDatabase.instance.delete(
      'custom_categories',
      where: 'id = ?',
      whereArgs: [id],
    );
    await _load();
  }

  // ── Row mapping ────────────────────────────────────────────────────────────

  Map<String, dynamic> _toRow(CustomCategory c) => {
    'id': c.id,
    'label': c.label,
    'icon_code': c.iconCodePoint,
    'font_family': c.fontFamily,
    'color': c.color.toARGB32(),
    'is_expense': c.isExpense ? 1 : 0,
  };

  CustomCategory _fromRow(Map<String, dynamic> row) => CustomCategory(
    id: row['id'] as String,
    label: row['label'] as String,
    iconCodePoint: row['icon_code'] as int,
    fontFamily: row['font_family'] as String,
    color: Color(row['color'] as int),
    isExpense: (row['is_expense'] as int) == 1,
  );
}
