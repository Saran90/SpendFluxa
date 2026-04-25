import 'package:flutter/material.dart';
import '../database/app_database.dart';
import '../models/tag.dart';

class TagService extends ChangeNotifier {
  final List<Tag> _tags = [];

  List<Tag> get all => List.unmodifiable(_tags);

  TagService() {
    _load();
  }

  Tag? getById(String id) {
    try {
      return _tags.firstWhere((t) => t.id == id);
    } catch (_) {
      return null;
    }
  }

  // ── Persistence ────────────────────────────────────────────────────────────

  Future<void> _load() async {
    try {
      final rows = await AppDatabase.instance.query(
        'tags',
        orderBy: 'name ASC',
      );
      _tags
        ..clear()
        ..addAll(rows.map(_fromRow));
      notifyListeners();
    } catch (e) {
      debugPrint('[TagService] load error: $e');
    }
  }

  /// Reloads all tags from the database.
  /// Call this after a backup restore to refresh in-memory state.
  Future<void> reload() => _load();

  // ── CRUD ───────────────────────────────────────────────────────────────────

  Future<void> add(Tag tag) async {
    await AppDatabase.instance.insert('tags', _toRow(tag));
    await _load();
  }

  Future<void> update(Tag updated) async {
    await AppDatabase.instance.update(
      'tags',
      _toRow(updated),
      where: 'id = ?',
      whereArgs: [updated.id],
    );
    await _load();
  }

  Future<void> remove(String id) async {
    await AppDatabase.instance.delete('tags', where: 'id = ?', whereArgs: [id]);
    await _load();
  }

  // ── Row mapping ────────────────────────────────────────────────────────────

  Map<String, dynamic> _toRow(Tag t) => {
    'id': t.id,
    'name': t.name,
    'color': t.color.toARGB32(),
    'icon_code': t.icon.codePoint,
    'font_family': t.icon.fontFamily ?? 'MaterialIcons',
    'created_at': t.createdAt.toIso8601String(),
  };

  Tag _fromRow(Map<String, dynamic> row) => Tag(
    id: row['id'] as String,
    name: row['name'] as String,
    color: Color(row['color'] as int),
    icon: IconData(
      row['icon_code'] as int,
      fontFamily: row['font_family'] as String,
    ),
    createdAt: DateTime.parse(row['created_at'] as String),
  );
}
