import 'dart:io';

import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

/// Central SQLite database helper for SpendFlux.
///
/// Tables created on first launch:
///   - categories        (built-in, seeded automatically)
///   - currencies        (built-in, seeded automatically)
///   - accounts          (user data, seeded with defaults)
///   - tags              (user data)
///   - custom_categories (user data)
///   - transactions      (user data)
///   - budgets           (user data)
class AppDatabase {
  AppDatabase._();
  static final AppDatabase instance = AppDatabase._();

  static const _dbName = 'spendflux.db';
  static const _dbVersion = 7;

  Database? _db;

  Future<Database> get database async {
    _db ??= await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _dbName);
    return openDatabase(
      path,
      version: _dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      onConfigure: (db) async => db.execute('PRAGMA foreign_keys = ON'),
    );
  }

  /// Closes the current connection and reopens the database file from scratch.
  ///
  /// Use this after overwriting the database file on disk (e.g. after a
  /// backup restore) to guarantee sqflite opens a fresh file handle instead
  /// of returning a cached connection that still points to the old data.
  Future<void> reopen() async {
    await close();

    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _dbName);

    // Remove any leftover WAL / SHM journal files from the previous
    // connection. If these exist alongside the newly written DB file, SQLite
    // will try to apply them on open and corrupt the restored data.
    for (final suffix in ['-wal', '-shm']) {
      final journal = File('$path$suffix');
      if (await journal.exists()) {
        await journal.delete();
        debugPrint('[AppDatabase] Deleted journal file: $path$suffix');
      }
    }

    _db = await openDatabase(
      path,
      version: _dbVersion,
      onUpgrade: _onUpgrade,
      // Do NOT pass onCreate — the restored file already has all tables.
      onConfigure: (db) async => db.execute('PRAGMA foreign_keys = ON'),
    );
    debugPrint('[AppDatabase] Reopened after restore: $path');
  }

  // ── Schema creation ────────────────────────────────────────────────────────

  Future<void> _onCreate(Database db, int version) async {
    await _createTables(db);
    await _seedCategories(db);
    await _seedCurrencies(db);
    await _seedAccounts(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Add reminders table in version 2
      await db.execute('''
        CREATE TABLE reminders (
          id                        TEXT PRIMARY KEY,
          recurring_transaction_id  TEXT NOT NULL,
          days_before               INTEGER NOT NULL DEFAULT 0,
          time_hour                 INTEGER NOT NULL,
          time_minute               INTEGER NOT NULL,
          is_enabled                INTEGER NOT NULL DEFAULT 1,
          FOREIGN KEY (recurring_transaction_id) REFERENCES transactions(id) ON DELETE CASCADE
        )
      ''');
    }
    if (oldVersion < 3) {
      // Add recurring_confirmations table in version 3
      await db.execute('''
        CREATE TABLE recurring_confirmations (
          id                        TEXT PRIMARY KEY,
          recurring_transaction_id  TEXT NOT NULL,
          due_date                  TEXT NOT NULL,
          status                    TEXT NOT NULL CHECK(status IN ('pending','accepted','denied')),
          confirmed_at              TEXT,
          FOREIGN KEY (recurring_transaction_id) REFERENCES transactions(id) ON DELETE CASCADE,
          UNIQUE(recurring_transaction_id, due_date)
        )
      ''');
    }
    if (oldVersion < 4) {
      // Add SMS tracking fields to transactions table in version 4
      await db.execute('ALTER TABLE transactions ADD COLUMN source TEXT');
      await db.execute(
        'ALTER TABLE transactions ADD COLUMN sms_message_id TEXT',
      );
      await db.execute('ALTER TABLE transactions ADD COLUMN bank_name TEXT');
    }
    if (oldVersion < 5) {
      // Add is_monthly flag — default 1 (true) so existing transactions
      // continue to count toward monthly totals
      await db.execute(
        'ALTER TABLE transactions ADD COLUMN is_monthly INTEGER NOT NULL DEFAULT 1',
      );
    }
    if (oldVersion < 6) {
      await db.execute(
        'ALTER TABLE transactions ADD COLUMN custom_category_id TEXT',
      );
    }
    if (oldVersion < 7) {
      // Ensure custom_category_id exists for databases that reached version 6
      // without the column (created before the column was added to _createTables).
      try {
        await db.execute(
          'ALTER TABLE transactions ADD COLUMN custom_category_id TEXT',
        );
      } catch (_) {
        // Column already exists — safe to ignore.
      }
    }
  }

  Future<void> _createTables(Database db) async {
    // Built-in categories (expense + income)
    await db.execute('''
      CREATE TABLE categories (
        id          TEXT PRIMARY KEY,
        name        TEXT NOT NULL,
        label       TEXT NOT NULL,
        icon_code   INTEGER NOT NULL,
        font_family TEXT NOT NULL DEFAULT 'MaterialIcons',
        color       INTEGER NOT NULL,
        type        TEXT NOT NULL CHECK(type IN ('expense','income','both')),
        is_builtin  INTEGER NOT NULL DEFAULT 1
      )
    ''');

    // Supported currencies
    await db.execute('''
      CREATE TABLE currencies (
        code        TEXT PRIMARY KEY,
        name        TEXT NOT NULL,
        symbol      TEXT NOT NULL,
        flag        TEXT NOT NULL,
        is_builtin  INTEGER NOT NULL DEFAULT 1
      )
    ''');

    // Accounts (bank, wallet, cash, credit card, savings)
    await db.execute('''
      CREATE TABLE accounts (
        id               TEXT PRIMARY KEY,
        name             TEXT NOT NULL,
        type             TEXT NOT NULL,
        balance          REAL NOT NULL DEFAULT 0,
        credit_limit     REAL,
        bill_date        INTEGER,
        last_four_digits TEXT,
        color            INTEGER NOT NULL,
        is_default       INTEGER NOT NULL DEFAULT 0
      )
    ''');

    // User-created tags
    await db.execute('''
      CREATE TABLE tags (
        id          TEXT PRIMARY KEY,
        name        TEXT NOT NULL,
        color       INTEGER NOT NULL,
        icon_code   INTEGER NOT NULL,
        font_family TEXT NOT NULL DEFAULT 'MaterialIcons',
        created_at  TEXT NOT NULL
      )
    ''');

    // User-created custom categories
    await db.execute('''
      CREATE TABLE custom_categories (
        id          TEXT PRIMARY KEY,
        label       TEXT NOT NULL,
        icon_code   INTEGER NOT NULL,
        font_family TEXT NOT NULL DEFAULT 'MaterialIcons',
        color       INTEGER NOT NULL,
        is_expense  INTEGER NOT NULL DEFAULT 1
      )
    ''');

    // Transactions
    await db.execute('''
      CREATE TABLE transactions (
        id                    TEXT PRIMARY KEY,
        title                 TEXT NOT NULL,
        amount                REAL NOT NULL,
        type                  TEXT NOT NULL,
        category              TEXT NOT NULL,
        date                  TEXT NOT NULL,
        note                  TEXT,
        account_id            TEXT,
        to_account_id         TEXT,
        tag_ids               TEXT NOT NULL DEFAULT '[]',
        is_emi                INTEGER NOT NULL DEFAULT 0,
        emi_interest_rate     REAL,
        emi_duration_months   INTEGER,
        emi_monthly_amount    REAL,
        parent_transaction_id TEXT,
        exclude_from_expense  INTEGER NOT NULL DEFAULT 0,
        is_monthly            INTEGER NOT NULL DEFAULT 1,
        is_recurring          INTEGER NOT NULL DEFAULT 0,
        recurring_frequency   TEXT,
        recurring_end_date    TEXT,
        recurring_parent_id   TEXT,
        source                TEXT,
        sms_message_id        TEXT,
        bank_name             TEXT,
        custom_category_id    TEXT,
        FOREIGN KEY (account_id)    REFERENCES accounts(id) ON DELETE SET NULL,
        FOREIGN KEY (to_account_id) REFERENCES accounts(id) ON DELETE SET NULL
      )
    ''');

    // Monthly budgets
    await db.execute('''
      CREATE TABLE budgets (
        id               TEXT PRIMARY KEY,
        year             INTEGER NOT NULL,
        month            INTEGER NOT NULL,
        overall_limit    REAL,
        category_limits  TEXT NOT NULL DEFAULT '{}',
        UNIQUE(year, month)
      )
    ''');

    // Reminders for recurring transactions
    await db.execute('''
      CREATE TABLE reminders (
        id                        TEXT PRIMARY KEY,
        recurring_transaction_id  TEXT NOT NULL,
        days_before               INTEGER NOT NULL DEFAULT 0,
        time_hour                 INTEGER NOT NULL,
        time_minute               INTEGER NOT NULL,
        is_enabled                INTEGER NOT NULL DEFAULT 1,
        FOREIGN KEY (recurring_transaction_id) REFERENCES transactions(id) ON DELETE CASCADE
      )
    ''');

    // Recurring transaction confirmations
    await db.execute('''
      CREATE TABLE recurring_confirmations (
        id                        TEXT PRIMARY KEY,
        recurring_transaction_id  TEXT NOT NULL,
        due_date                  TEXT NOT NULL,
        status                    TEXT NOT NULL CHECK(status IN ('pending','accepted','denied')),
        confirmed_at              TEXT,
        FOREIGN KEY (recurring_transaction_id) REFERENCES transactions(id) ON DELETE CASCADE,
        UNIQUE(recurring_transaction_id, due_date)
      )
    ''');
  }

  // ── Seed data ──────────────────────────────────────────────────────────────

  Future<void> _seedCategories(Database db) async {
    final categories = _builtinCategories();
    final batch = db.batch();
    for (final cat in categories) {
      batch.insert(
        'categories',
        cat,
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<void> _seedCurrencies(Database db) async {
    final currencies = _builtinCurrencies();
    final batch = db.batch();
    for (final cur in currencies) {
      batch.insert(
        'currencies',
        cur,
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<void> _seedAccounts(Database db) async {
    final accounts = _defaultAccounts();
    final batch = db.batch();
    for (final acc in accounts) {
      batch.insert(
        'accounts',
        acc,
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
    await batch.commit(noResult: true);
  }

  // ── Built-in category definitions ─────────────────────────────────────────

  List<Map<String, dynamic>> _builtinCategories() => [
    // ── Expense categories ──────────────────────────────────────────────────
    {
      'id': 'cat_food',
      'name': 'food',
      'label': 'Food & Dining',
      'icon_code': Icons.restaurant_rounded.codePoint,
      'font_family': 'MaterialIcons',
      'color': const Color(0xFFFF6B6B).toARGB32(),
      'type': 'expense',
      'is_builtin': 1,
    },
    {
      'id': 'cat_grocery',
      'name': 'grocery',
      'label': 'Grocery',
      'icon_code': Icons.shopping_cart_rounded.codePoint,
      'font_family': 'MaterialIcons',
      'color': const Color(0xFF8BC34A).toARGB32(),
      'type': 'expense',
      'is_builtin': 1,
    },
    {
      'id': 'cat_vegetables',
      'name': 'vegetables',
      'label': 'Vegetables',
      'icon_code': Icons.eco_rounded.codePoint,
      'font_family': 'MaterialIcons',
      'color': const Color(0xFF4CAF50).toARGB32(),
      'type': 'expense',
      'is_builtin': 1,
    },
    {
      'id': 'cat_bakery',
      'name': 'bakery',
      'label': 'Bakery',
      'icon_code': Icons.bakery_dining_rounded.codePoint,
      'font_family': 'MaterialIcons',
      'color': const Color(0xFFD4A574).toARGB32(),
      'type': 'expense',
      'is_builtin': 1,
    },
    {
      'id': 'cat_drinks_snacks',
      'name': 'drinksAndSnacks',
      'label': 'Drinks & Snacks',
      'icon_code': Icons.local_cafe_rounded.codePoint,
      'font_family': 'MaterialIcons',
      'color': const Color(0xFFFF7043).toARGB32(),
      'type': 'expense',
      'is_builtin': 1,
    },
    {
      'id': 'cat_transport',
      'name': 'transport',
      'label': 'Transport',
      'icon_code': Icons.directions_car_rounded.codePoint,
      'font_family': 'MaterialIcons',
      'color': const Color(0xFF4ECDC4).toARGB32(),
      'type': 'expense',
      'is_builtin': 1,
    },
    {
      'id': 'cat_fuel',
      'name': 'fuel',
      'label': 'Fuel',
      'icon_code': Icons.local_gas_station_rounded.codePoint,
      'font_family': 'MaterialIcons',
      'color': const Color(0xFFFF9800).toARGB32(),
      'type': 'expense',
      'is_builtin': 1,
    },
    {
      'id': 'cat_shopping',
      'name': 'shopping',
      'label': 'Shopping',
      'icon_code': Icons.shopping_bag_rounded.codePoint,
      'font_family': 'MaterialIcons',
      'color': const Color(0xFFFFBE0B).toARGB32(),
      'type': 'expense',
      'is_builtin': 1,
    },
    {
      'id': 'cat_entertainment',
      'name': 'entertainment',
      'label': 'Entertainment',
      'icon_code': Icons.movie_rounded.codePoint,
      'font_family': 'MaterialIcons',
      'color': const Color(0xFF9B59B6).toARGB32(),
      'type': 'expense',
      'is_builtin': 1,
    },
    {
      'id': 'cat_health',
      'name': 'health',
      'label': 'Health',
      'icon_code': Icons.favorite_rounded.codePoint,
      'font_family': 'MaterialIcons',
      'color': const Color(0xFFE74C3C).toARGB32(),
      'type': 'expense',
      'is_builtin': 1,
    },
    {
      'id': 'cat_utilities',
      'name': 'utilities',
      'label': 'Utilities',
      'icon_code': Icons.bolt_rounded.codePoint,
      'font_family': 'MaterialIcons',
      'color': const Color(0xFF3498DB).toARGB32(),
      'type': 'expense',
      'is_builtin': 1,
    },
    {
      'id': 'cat_bills',
      'name': 'bills',
      'label': 'Bills',
      'icon_code': Icons.receipt_rounded.codePoint,
      'font_family': 'MaterialIcons',
      'color': const Color(0xFF607D8B).toARGB32(),
      'type': 'expense',
      'is_builtin': 1,
    },
    {
      'id': 'cat_rent',
      'name': 'rent',
      'label': 'Rent',
      'icon_code': Icons.home_rounded.codePoint,
      'font_family': 'MaterialIcons',
      'color': const Color(0xFF2ECC71).toARGB32(),
      'type': 'expense',
      'is_builtin': 1,
    },
    {
      'id': 'cat_education',
      'name': 'education',
      'label': 'Education',
      'icon_code': Icons.school_rounded.codePoint,
      'font_family': 'MaterialIcons',
      'color': const Color(0xFF1ABC9C).toARGB32(),
      'type': 'expense',
      'is_builtin': 1,
    },
    {
      'id': 'cat_insurance',
      'name': 'insurance',
      'label': 'Insurance',
      'icon_code': Icons.shield_rounded.codePoint,
      'font_family': 'MaterialIcons',
      'color': const Color(0xFF5C6BC0).toARGB32(),
      'type': 'expense',
      'is_builtin': 1,
    },
    {
      'id': 'cat_expense_investment',
      'name': 'expenseInvestment',
      'label': 'Investment',
      'icon_code': Icons.account_balance_rounded.codePoint,
      'font_family': 'MaterialIcons',
      'color': const Color(0xFF00897B).toARGB32(),
      'type': 'expense',
      'is_builtin': 1,
    },
    {
      'id': 'cat_other_expense',
      'name': 'other',
      'label': 'Other',
      'icon_code': Icons.category_rounded.codePoint,
      'font_family': 'MaterialIcons',
      'color': const Color(0xFF95A5A6).toARGB32(),
      'type': 'both',
      'is_builtin': 1,
    },
    // ── Income categories ───────────────────────────────────────────────────
    {
      'id': 'cat_salary',
      'name': 'salary',
      'label': 'Salary',
      'icon_code': Icons.work_rounded.codePoint,
      'font_family': 'MaterialIcons',
      'color': const Color(0xFF2D9E6B).toARGB32(),
      'type': 'income',
      'is_builtin': 1,
    },
    {
      'id': 'cat_freelance',
      'name': 'freelance',
      'label': 'Freelance',
      'icon_code': Icons.laptop_rounded.codePoint,
      'font_family': 'MaterialIcons',
      'color': const Color(0xFF27AE60).toARGB32(),
      'type': 'income',
      'is_builtin': 1,
    },
    {
      'id': 'cat_investment',
      'name': 'investment',
      'label': 'Investment',
      'icon_code': Icons.trending_up_rounded.codePoint,
      'font_family': 'MaterialIcons',
      'color': const Color(0xFF16A085).toARGB32(),
      'type': 'income',
      'is_builtin': 1,
    },
    {
      'id': 'cat_gift',
      'name': 'gift',
      'label': 'Gift',
      'icon_code': Icons.card_giftcard_rounded.codePoint,
      'font_family': 'MaterialIcons',
      'color': const Color(0xFFE91E63).toARGB32(),
      'type': 'income',
      'is_builtin': 1,
    },
    {
      'id': 'cat_cashback',
      'name': 'cashback',
      'label': 'Cashback',
      'icon_code': Icons.currency_exchange_rounded.codePoint,
      'font_family': 'MaterialIcons',
      'color': const Color(0xFF00BCD4).toARGB32(),
      'type': 'income',
      'is_builtin': 1,
    },
  ];

  // ── Built-in currency definitions ──────────────────────────────────────────

  List<Map<String, dynamic>> _builtinCurrencies() => [
    {
      'code': 'INR',
      'name': 'Indian Rupee',
      'symbol': '₹',
      'flag': '🇮🇳',
      'is_builtin': 1,
    },
    {
      'code': 'USD',
      'name': 'US Dollar',
      'symbol': '\$',
      'flag': '🇺🇸',
      'is_builtin': 1,
    },
    {
      'code': 'EUR',
      'name': 'Euro',
      'symbol': '€',
      'flag': '🇪🇺',
      'is_builtin': 1,
    },
    {
      'code': 'GBP',
      'name': 'British Pound',
      'symbol': '£',
      'flag': '🇬🇧',
      'is_builtin': 1,
    },
  ];

  // ── Default account seed data ──────────────────────────────────────────────

  List<Map<String, dynamic>> _defaultAccounts() => [
    {
      'id': 'default_bank',
      'name': 'Primary Bank',
      'type': 'bank',
      'balance': 0.0,
      'credit_limit': null,
      'bill_date': null,
      'last_four_digits': null,
      'color': const Color(0xFF3498DB).toARGB32(),
      'is_default': 1,
    },
    {
      'id': 'default_wallet',
      'name': 'Online Wallet',
      'type': 'wallet',
      'balance': 0.0,
      'credit_limit': null,
      'bill_date': null,
      'last_four_digits': null,
      'color': const Color(0xFF9B59B6).toARGB32(),
      'is_default': 0,
    },
    {
      'id': 'default_cash',
      'name': 'Cash',
      'type': 'cash',
      'balance': 0.0,
      'credit_limit': null,
      'bill_date': null,
      'last_four_digits': null,
      'color': const Color(0xFF2D9E6B).toARGB32(),
      'is_default': 0,
    },
  ];

  // ── Generic query helpers ──────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> query(
    String table, {
    String? where,
    List<dynamic>? whereArgs,
    String? orderBy,
  }) async {
    final db = await database;
    return db.query(
      table,
      where: where,
      whereArgs: whereArgs,
      orderBy: orderBy,
    );
  }

  Future<int> insert(
    String table,
    Map<String, dynamic> values, {
    ConflictAlgorithm conflictAlgorithm = ConflictAlgorithm.replace,
  }) async {
    final db = await database;
    return db.insert(table, values, conflictAlgorithm: conflictAlgorithm);
  }

  Future<int> update(
    String table,
    Map<String, dynamic> values, {
    required String where,
    required List<dynamic> whereArgs,
  }) async {
    final db = await database;
    return db.update(table, values, where: where, whereArgs: whereArgs);
  }

  Future<int> delete(
    String table, {
    required String where,
    required List<dynamic> whereArgs,
  }) async {
    final db = await database;
    return db.delete(table, where: where, whereArgs: whereArgs);
  }

  Future<void> close() async {
    final db = _db;
    if (db != null) {
      await db.close();
      _db = null;
    }
  }
}
