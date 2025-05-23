import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/expense.dart';
import '../providers/settings_provider.dart'; // For Tag model

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;
  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('wallet.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);
    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  Future<int> updateExpense(Expense expense) async {
    final db = await instance.database;
    return db.update(
      'expenses',
      expense.toMap(),
      where: 'id = ?',
      whereArgs: [expense.id],
    );
  }

  Future<void> _createDB(Database db, int version) async {
    const idType = 'INTEGER PRIMARY KEY AUTOINCREMENT';
    const textType = 'TEXT NOT NULL';
    const realType = 'REAL NOT NULL';

    // Create expenses table.
    await db.execute('''
      CREATE TABLE expenses (
        id $idType,
        name $textType,
        amount $realType,
        date $textType,
        tag $textType
      )
    ''');

    // Create tags table.
    await db.execute('''
      CREATE TABLE tags (
        name TEXT PRIMARY KEY,
        allowanceLimit REAL,
        duration INTEGER,
        allowanceStart TEXT
      )
    ''');

    // Insert a default "General" tag.
    await db.insert('tags', {
      'name': 'General',
      'allowanceLimit': null,
      'duration': 30,
      'allowanceStart': null,
    });
  }

  Future<int> insertExpense(Expense expense) async {
    final db = await instance.database;
    return await db.insert('expenses', {
      'name': expense.name,
      'amount': expense.amount,
      'date': expense.date.toIso8601String(),
      'tag': expense.tag,
    });
  }

  Future<List<Map<String, dynamic>>> queryAllExpenses() async {
    final db = await instance.database;
    return await db.query('expenses', orderBy: 'date DESC');
  }

  Future<List<Map<String, dynamic>>> queryMonthExpenses(DateTime date) async {
    final db = await instance.database;
    final startOfMonth = DateTime(date.year, date.month, 1);
    // last day of month:
    final endOfMonth = DateTime(date.year, date.month + 1, 0, 23, 59, 59);
    return await db.query(
      'expenses',
      where: 'date BETWEEN ? AND ?',
      whereArgs: [
        startOfMonth.toIso8601String(),
        endOfMonth.toIso8601String(),
      ],
      orderBy: 'date DESC',
    );
  }

  Future<List<Expense>> getExpenses() async {
    final result = await queryAllExpenses();
    return result.map((json) => Expense.fromMap(json)).toList();
  }

  Future<List<Expense>> getMonthExpenses(DateTime date) async {
    final result = await queryMonthExpenses(date);
    return result.map((json) => Expense.fromMap(json)).toList();
  }

  Future<List<Expense>> getExpensesByDateRange(
      DateTime start, DateTime end) async {
    final db = await instance.database;
    final result = await db.query(
      'expenses',
      where: 'date BETWEEN ? AND ?',
      whereArgs: [
        start.toIso8601String(),
        end.toIso8601String(),
      ],
      orderBy: 'date DESC',
    );
    return result.map((json) => Expense.fromMap(json)).toList();
  }

  Future<void> deleteExpense(int id) async {
    final db = await instance.database;
    await db.delete(
      'expenses',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ---------- Tag table functions ----------
  Future<List<Map<String, dynamic>>> queryAllTags() async {
    final db = await instance.database;
    return await db.query('tags', orderBy: 'name ASC');
  }

  Future<List<Tag>> getTags() async {
    final result = await queryAllTags();
    return result.map((json) => Tag.fromMap(json)).toList();
  }

  Future<int> insertTag(Tag tag) async {
    final db = await instance.database;
    return await db.insert(
      'tags',
      tag.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<int> updateTag(Tag tag) async {
    final db = await instance.database;
    return await db.update(
      'tags',
      tag.toMap(),
      where: 'name = ?',
      whereArgs: [tag.name],
    );
  }

  Future<int> deleteTag(String tagName) async {
    final db = await instance.database;
    return await db.delete(
      'tags',
      where: 'name = ?',
      whereArgs: [tagName],
    );
  }

  Future<void> close() async {
    final db = await instance.database;
    db.close();
  }
}
