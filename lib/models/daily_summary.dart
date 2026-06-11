import 'enums.dart';
import 'food_entry.dart';

/// Bir günün öğünlere göre gruplanmış kayıtları ve toplamları.
class DailySummary {
  final String date;
  final List<FoodEntry> entries;

  DailySummary({required this.date, required this.entries});

  double get totalCalories =>
      entries.fold(0.0, (sum, e) => sum + e.calories);

  double get totalProtein =>
      entries.fold(0.0, (sum, e) => sum + (e.protein ?? 0));
  double get totalCarb => entries.fold(0.0, (sum, e) => sum + (e.carb ?? 0));
  double get totalFat => entries.fold(0.0, (sum, e) => sum + (e.fat ?? 0));

  /// Belirli bir öğüne ait kayıtlar.
  List<FoodEntry> entriesFor(MealType meal) =>
      entries.where((e) => e.mealType == meal).toList();

  double caloriesFor(MealType meal) =>
      entriesFor(meal).fold(0.0, (sum, e) => sum + e.calories);
}
