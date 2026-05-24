import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'app_database.dart';

/// Helper class for managing database migrations and data restoration
class MigrationHelper {
  MigrationHelper._();

  /// Exports all data from the database to a JSON backup
  /// This can be used to restore data after schema changes
  static Future<Map<String, dynamic>> exportAllData() async {
    final db = await AppDatabase.instance.database;

    debugPrint('[MigrationHelper] Starting data export...');

    try {
      final backup = <String, dynamic>{
        'version': 1,
        'exportedAt': DateTime.now().toIso8601String(),
        'tables': {},
      };

      // Export all tables
      final tables = [
        'transactions',
        'accounts',
        'tags',
        'custom_categories',
        'budgets',
        'reminders',
        'recurring_confirmations',
        'credit_card_bills',
        'bill_payments',
        'bill_transactions',
      ];

      for (final table in tables) {
        try {
          final data = await db.query(table);
          backup['tables'][table] = data;
          debugPrint('[MigrationHelper] Exported $table: ${data.length} rows');
        } catch (e) {
          debugPrint('[MigrationHelper] Table $table not found or error: $e');
          backup['tables'][table] = [];
        }
      }

      debugPrint('[MigrationHelper] Data export completed successfully');
      return backup;
    } catch (e) {
      debugPrint('[MigrationHelper] Error during export: $e');
      rethrow;
    }
  }

  /// Imports data from a JSON backup into the database
  /// This is used to restore data after schema changes
  static Future<void> importAllData(Map<String, dynamic> backup) async {
    final db = await AppDatabase.instance.database;

    debugPrint('[MigrationHelper] Starting data import...');

    try {
      final tables = backup['tables'] as Map<String, dynamic>? ?? {};

      // Import each table
      for (final entry in tables.entries) {
        final tableName = entry.key;
        final rows = entry.value as List<dynamic>? ?? [];

        if (rows.isEmpty) {
          debugPrint('[MigrationHelper] Skipping empty table: $tableName');
          continue;
        }

        try {
          final batch = db.batch();
          for (final row in rows) {
            final data = Map<String, dynamic>.from(row as Map);
            batch.insert(
              tableName,
              data,
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
          }
          await batch.commit(noResult: true);
          debugPrint(
            '[MigrationHelper] Imported $tableName: ${rows.length} rows',
          );
        } catch (e) {
          debugPrint('[MigrationHelper] Error importing $tableName: $e');
          // Continue with other tables even if one fails
        }
      }

      debugPrint('[MigrationHelper] Data import completed successfully');
    } catch (e) {
      debugPrint('[MigrationHelper] Error during import: $e');
      rethrow;
    }
  }

  /// Validates that all required columns exist in the transactions table
  /// Returns a list of missing columns
  static Future<List<String>> validateTransactionSchema() async {
    final db = await AppDatabase.instance.database;
    final missingColumns = <String>[];

    const requiredColumns = [
      'id',
      'title',
      'amount',
      'type',
      'category',
      'date',
      'note',
      'account_id',
      'to_account_id',
      'tag_ids',
      'is_emi',
      'emi_interest_rate',
      'emi_duration_months',
      'emi_monthly_amount',
      'parent_transaction_id',
      'exclude_from_expense',
      'is_monthly',
      'is_recurring',
      'recurring_frequency',
      'recurring_end_date',
      'recurring_parent_id',
      'source',
      'sms_message_id',
      'bank_name',
      'custom_category_id',
      'credit_card_account_id',
      'transaction_state',
      'credit_card_bill_id',
      'state_changed_at',
    ];

    try {
      final result = await db.rawQuery('PRAGMA table_info(transactions)');
      final existingColumns = result.map((r) => r['name'] as String).toSet();

      for (final col in requiredColumns) {
        if (!existingColumns.contains(col)) {
          missingColumns.add(col);
        }
      }

      if (missingColumns.isEmpty) {
        debugPrint('[MigrationHelper] Transaction schema validation: OK');
      } else {
        debugPrint('[MigrationHelper] Missing columns: $missingColumns');
      }
    } catch (e) {
      debugPrint('[MigrationHelper] Error validating schema: $e');
    }

    return missingColumns;
  }

  /// Validates that all required columns exist in the accounts table
  /// Returns a list of missing columns
  static Future<List<String>> validateAccountSchema() async {
    final db = await AppDatabase.instance.database;
    final missingColumns = <String>[];

    const requiredColumns = [
      'id',
      'name',
      'type',
      'balance',
      'credit_limit',
      'bill_date',
      'last_four_digits',
      'color',
      'is_default',
      'billing_cycle_day',
      'budget_counting_method',
      'issuer_name',
      'statement_start_date',
      'reminder_days_before',
    ];

    try {
      final result = await db.rawQuery('PRAGMA table_info(accounts)');
      final existingColumns = result.map((r) => r['name'] as String).toSet();

      for (final col in requiredColumns) {
        if (!existingColumns.contains(col)) {
          missingColumns.add(col);
        }
      }

      if (missingColumns.isEmpty) {
        debugPrint('[MigrationHelper] Account schema validation: OK');
      } else {
        debugPrint('[MigrationHelper] Missing columns: $missingColumns');
      }
    } catch (e) {
      debugPrint('[MigrationHelper] Error validating schema: $e');
    }

    return missingColumns;
  }

  /// Validates that all required tables exist
  /// Returns a list of missing tables
  static Future<List<String>> validateTables() async {
    final db = await AppDatabase.instance.database;
    final missingTables = <String>[];

    const requiredTables = [
      'transactions',
      'accounts',
      'tags',
      'custom_categories',
      'budgets',
      'reminders',
      'recurring_confirmations',
      'credit_card_bills',
      'bill_payments',
      'bill_transactions',
    ];

    try {
      final result = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table'",
      );
      final existingTables = result.map((r) => r['name'] as String).toSet();

      for (final table in requiredTables) {
        if (!existingTables.contains(table)) {
          missingTables.add(table);
        }
      }

      if (missingTables.isEmpty) {
        debugPrint('[MigrationHelper] Table validation: OK');
      } else {
        debugPrint('[MigrationHelper] Missing tables: $missingTables');
      }
    } catch (e) {
      debugPrint('[MigrationHelper] Error validating tables: $e');
    }

    return missingTables;
  }

  /// Performs a full database validation
  /// Returns true if all schemas and tables are valid
  static Future<bool> validateDatabase() async {
    debugPrint('[MigrationHelper] Starting full database validation...');

    final missingTables = await validateTables();
    final missingTransactionCols = await validateTransactionSchema();
    final missingAccountCols = await validateAccountSchema();

    final isValid =
        missingTables.isEmpty &&
        missingTransactionCols.isEmpty &&
        missingAccountCols.isEmpty;

    if (isValid) {
      debugPrint('[MigrationHelper] Database validation: PASSED');
    } else {
      debugPrint('[MigrationHelper] Database validation: FAILED');
      debugPrint('[MigrationHelper] Missing tables: $missingTables');
      debugPrint(
        '[MigrationHelper] Missing transaction columns: $missingTransactionCols',
      );
      debugPrint(
        '[MigrationHelper] Missing account columns: $missingAccountCols',
      );
    }

    return isValid;
  }

  /// Initializes default values for new CC fields in existing transactions
  /// Sets all transactions to 'pending' state
  static Future<void> initializeDefaultCCValues() async {
    final db = await AppDatabase.instance.database;

    debugPrint('[MigrationHelper] Initializing default CC values...');

    try {
      // Set all transactions to pending state if not already set
      await db.execute('''
        UPDATE transactions 
        SET transaction_state = 'pending'
        WHERE transaction_state IS NULL OR transaction_state = ''
      ''');
      debugPrint('[MigrationHelper] Initialized transaction states');

      // Set default budget counting method for CC accounts
      await db.execute('''
        UPDATE accounts 
        SET budget_counting_method = 'committed'
        WHERE budget_counting_method IS NULL OR budget_counting_method = ''
      ''');
      debugPrint('[MigrationHelper] Initialized budget counting methods');

      // Set default reminder days
      await db.execute('''
        UPDATE accounts 
        SET reminder_days_before = 3
        WHERE reminder_days_before IS NULL
      ''');
      debugPrint('[MigrationHelper] Initialized reminder days');

      debugPrint(
        '[MigrationHelper] Default CC values initialization completed',
      );
    } catch (e) {
      debugPrint('[MigrationHelper] Error initializing default values: $e');
    }
  }

  /// Creates a backup file path for the given timestamp
  static String getBackupFilePath(DateTime timestamp) {
    final formattedTime = timestamp.toIso8601String().replaceAll(':', '-');
    return 'spendflux_backup_$formattedTime.json';
  }

  /// Converts backup data to JSON string
  static String backupToJson(Map<String, dynamic> backup) {
    return jsonEncode(backup);
  }

  /// Converts JSON string to backup data
  static Map<String, dynamic> jsonToBackup(String json) {
    return jsonDecode(json) as Map<String, dynamic>;
  }
}
