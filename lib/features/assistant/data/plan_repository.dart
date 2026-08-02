import '../../../core/database/app_database.dart';
import '../models/financial_plan.dart';

/// SQLite repository for [FinancialPlan] objects.
///
/// All methods are async and communicate directly with the `financial_plans`
/// table created in the version-11 database migration.
class PlanRepository {
  static const _table = 'financial_plans';

  // ── Read ───────────────────────────────────────────────────────────────────

  /// Returns all plans, optionally filtered by [type].
  Future<List<FinancialPlan>> getAll({PlanType? type}) async {
    final rows = await AppDatabase.instance.query(
      _table,
      where: type != null ? 'type = ?' : null,
      whereArgs: type != null ? [type.name] : null,
      orderBy: 'created_at DESC',
    );
    return rows.map(FinancialPlan.fromMap).toList();
  }

  /// Returns a single plan by [id], or `null` if not found.
  Future<FinancialPlan?> getById(String id) async {
    final rows = await AppDatabase.instance.query(
      _table,
      where: 'id = ?',
      whereArgs: [id],
    );
    if (rows.isEmpty) return null;
    return FinancialPlan.fromMap(rows.first);
  }

  // ── Write ──────────────────────────────────────────────────────────────────

  /// Inserts a new plan. Throws if a plan with the same [id] already exists.
  Future<void> insert(FinancialPlan plan) async {
    await AppDatabase.instance.insert(_table, plan.toMap());
  }

  /// Updates an existing plan identified by [plan.id].
  Future<void> update(FinancialPlan plan) async {
    await AppDatabase.instance.update(
      _table,
      plan.toMap(),
      where: 'id = ?',
      whereArgs: [plan.id],
    );
  }

  /// Deletes the plan with the given [id].
  Future<void> delete(String id) async {
    await AppDatabase.instance.delete(_table, where: 'id = ?', whereArgs: [id]);
  }
}
