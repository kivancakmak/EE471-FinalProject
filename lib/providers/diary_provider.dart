import 'package:flutter/foundation.dart';

import '../models/daily_summary.dart';
import '../models/food_entry.dart';
import '../repositories/food_log_repository.dart';
import '../utils/date_helpers.dart';

/// Seçili güne ait öğün günlüğünü yönetir.
class DiaryProvider extends ChangeNotifier {
  final FoodLogRepository _repo;

  DiaryProvider(this._repo) {
    loadDate(DateHelpers.today());
  }

  String _selectedDate = DateHelpers.today();
  List<FoodEntry> _entries = [];
  bool _loading = false;

  String get selectedDate => _selectedDate;
  bool get loading => _loading;
  DailySummary get summary =>
      DailySummary(date: _selectedDate, entries: _entries);

  bool get isViewingToday => DateHelpers.isToday(_selectedDate);

  Future<void> loadDate(String date) async {
    _selectedDate = date;
    _loading = true;
    notifyListeners();
    _entries = await _repo.entriesForDate(date);
    _loading = false;
    notifyListeners();
  }

  /// Bir önceki/sonraki güne geçiş.
  Future<void> shiftDay(int days) async {
    final d = DateHelpers.parseKey(_selectedDate).add(Duration(days: days));
    await loadDate(DateHelpers.keyOf(d));
  }

  Future<void> addEntry(FoodEntry entry) async {
    final saved = await _repo.addEntry(entry);
    // Yalnızca görüntülenen gün ise listeye yansıt.
    if (saved.date == _selectedDate) {
      _entries = [..._entries, saved];
      notifyListeners();
    }
  }

  Future<void> updateEntry(FoodEntry entry) async {
    await _repo.updateEntry(entry);
    final i = _entries.indexWhere((e) => e.id == entry.id);
    if (i != -1) {
      _entries = [..._entries]..[i] = entry;
      notifyListeners();
    }
  }

  Future<void> deleteEntry(FoodEntry entry) async {
    if (entry.id == null) return;
    await _repo.deleteEntry(entry.id!);
    _entries = _entries.where((e) => e.id != entry.id).toList();
    notifyListeners();
  }
}
