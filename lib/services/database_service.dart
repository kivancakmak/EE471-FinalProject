import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/food_entry.dart';

/// SQLite veritabanını yönetir: şema oluşturma ve food_entries CRUD.
class DatabaseService {
  static const _dbName = 'kalori_takip.db';
  static const _table = 'food_entries';

  Database? _db;

  Future<Database> get database async {
    return _db ??= await _open();
  }

  Future<Database> _open() async {
    final dir = await getDatabasesPath();
    final path = p.join(dir, _dbName);
    return openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE $_table (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            food_name TEXT NOT NULL,
            calories_per_100 REAL NOT NULL,
            serving_grams REAL,
            quantity REAL NOT NULL,
            unit TEXT NOT NULL,
            meal_type TEXT NOT NULL,
            protein_per_100 REAL,
            carb_per_100 REAL,
            fat_per_100 REAL,
            date TEXT NOT NULL,
            source TEXT NOT NULL,
            created_at TEXT NOT NULL
          )
        ''');
        await db.execute(
            'CREATE INDEX idx_${_table}_date ON $_table(date)');
      },
    );
  }

  Future<FoodEntry> insertEntry(FoodEntry entry) async {
    final db = await database;
    final id = await db.insert(_table, entry.toMap());
    return entry.copyWith(id: id);
  }

  Future<void> updateEntry(FoodEntry entry) async {
    final db = await database;
    await db.update(_table, entry.toMap(),
        where: 'id = ?', whereArgs: [entry.id]);
  }

  Future<void> deleteEntry(int id) async {
    final db = await database;
    await db.delete(_table, where: 'id = ?', whereArgs: [id]);
  }

  /// Belirli bir gündeki (YYYY-MM-DD) kayıtlar.
  Future<List<FoodEntry>> entriesForDate(String date) async {
    final db = await database;
    final rows = await db.query(_table,
        where: 'date = ?', whereArgs: [date], orderBy: 'created_at ASC');
    return rows.map(FoodEntry.fromMap).toList();
  }

  /// Kaydı olan farklı tarihler (geçmiş ekranı için), yeniden eskiye.
  Future<List<String>> datesWithEntries() async {
    final db = await database;
    final rows = await db.rawQuery(
        'SELECT DISTINCT date FROM $_table ORDER BY date DESC');
    return rows.map((r) => r['date'] as String).toList();
  }

  /// Bir tarih aralığındaki (dahil) tüm kayıtlar — haftalık grafik için.
  Future<List<FoodEntry>> entriesBetween(String start, String end) async {
    final db = await database;
    final rows = await db.query(_table,
        where: 'date >= ? AND date <= ?',
        whereArgs: [start, end],
        orderBy: 'date ASC');
    return rows.map(FoodEntry.fromMap).toList();
  }

  /// Son eklenen farklı yemekler (ada göre tekilleştirilmiş) — hızlı tekrar ekleme için.
  Future<List<FoodEntry>> recentDistinctEntries(int limit) async {
    final db = await database;
    final rows = await db.rawQuery('''
      SELECT * FROM $_table
      WHERE id IN (SELECT MAX(id) FROM $_table GROUP BY food_name)
      ORDER BY created_at DESC
      LIMIT ?
    ''', [limit]);
    return rows.map(FoodEntry.fromMap).toList();
  }
}
