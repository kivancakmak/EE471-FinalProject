import '../models/food_entry.dart';
import '../services/database_service.dart';

/// Günlük kayıtlarına erişimi soyutlar. Şu an yalnızca yerel SQLite kullanır;
/// ileride bulut (Firebase vb.) bu arayüzün ardına eklenebilir.
abstract class FoodLogRepository {
  Future<FoodEntry> addEntry(FoodEntry entry);
  Future<void> updateEntry(FoodEntry entry);
  Future<void> deleteEntry(int id);
  Future<List<FoodEntry>> entriesForDate(String date);
  Future<List<String>> datesWithEntries();
  Future<List<FoodEntry>> entriesBetween(String start, String end);
  Future<List<FoodEntry>> recentDistinctEntries(int limit);
}

/// Yerel (cihaz içi) SQLite tabanlı uygulama.
class LocalFoodLogRepository implements FoodLogRepository {
  final DatabaseService _db;

  LocalFoodLogRepository(this._db);

  @override
  Future<FoodEntry> addEntry(FoodEntry entry) => _db.insertEntry(entry);

  @override
  Future<void> updateEntry(FoodEntry entry) => _db.updateEntry(entry);

  @override
  Future<void> deleteEntry(int id) => _db.deleteEntry(id);

  @override
  Future<List<FoodEntry>> entriesForDate(String date) =>
      _db.entriesForDate(date);

  @override
  Future<List<String>> datesWithEntries() => _db.datesWithEntries();

  @override
  Future<List<FoodEntry>> entriesBetween(String start, String end) =>
      _db.entriesBetween(start, end);

  @override
  Future<List<FoodEntry>> recentDistinctEntries(int limit) =>
      _db.recentDistinctEntries(limit);
}
