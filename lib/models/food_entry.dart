import 'enums.dart';
import 'food.dart';

/// Günlüğe işlenmiş tek bir öğün kaydı.
class FoodEntry {
  final int? id;
  final String foodName;
  final double caloriesPer100;
  final double? servingGrams; // porsiyon başına gram (porsiyon birimi için)
  final double quantity;
  final ServingUnit unit;
  final MealType mealType;
  final double? proteinPer100;
  final double? carbPer100;
  final double? fatPer100;

  /// YYYY-MM-DD biçiminde tarih (yerel gün).
  final String date;
  final FoodSource source;
  final DateTime createdAt;

  const FoodEntry({
    this.id,
    required this.foodName,
    required this.caloriesPer100,
    this.servingGrams,
    required this.quantity,
    required this.unit,
    required this.mealType,
    this.proteinPer100,
    this.carbPer100,
    this.fatPer100,
    required this.date,
    required this.source,
    required this.createdAt,
  });

  /// Bu kaydın toplam gram/ml karşılığı (besin değeri ölçeklemesi için).
  double get totalGrams {
    switch (unit) {
      case ServingUnit.gram:
      case ServingUnit.milliliter:
        return quantity;
      case ServingUnit.portion:
        return (servingGrams ?? 100) * quantity;
    }
  }

  /// Hesaplanan toplam kalori.
  double get calories => caloriesPer100 * totalGrams / 100;

  double? get protein =>
      proteinPer100 == null ? null : proteinPer100! * totalGrams / 100;
  double? get carb =>
      carbPer100 == null ? null : carbPer100! * totalGrams / 100;
  double? get fat => fatPer100 == null ? null : fatPer100! * totalGrams / 100;

  /// Bir [Food] + kullanıcı girdisinden yeni kayıt üretir.
  factory FoodEntry.fromFood({
    required Food food,
    required double quantity,
    required ServingUnit unit,
    required MealType mealType,
    required String date,
  }) {
    return FoodEntry(
      foodName: food.name,
      caloriesPer100: food.caloriesPer100,
      servingGrams: food.servingGrams,
      quantity: quantity,
      unit: unit,
      mealType: mealType,
      proteinPer100: food.proteinPer100,
      carbPer100: food.carbPer100,
      fatPer100: food.fatPer100,
      date: date,
      source: food.source,
      createdAt: DateTime.now(),
    );
  }

  FoodEntry copyWith({
    int? id,
    double? quantity,
    ServingUnit? unit,
    MealType? mealType,
  }) {
    return FoodEntry(
      id: id ?? this.id,
      foodName: foodName,
      caloriesPer100: caloriesPer100,
      servingGrams: servingGrams,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      mealType: mealType ?? this.mealType,
      proteinPer100: proteinPer100,
      carbPer100: carbPer100,
      fatPer100: fatPer100,
      date: date,
      source: source,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'food_name': foodName,
        'calories_per_100': caloriesPer100,
        'serving_grams': servingGrams,
        'quantity': quantity,
        'unit': unit.name,
        'meal_type': mealType.name,
        'protein_per_100': proteinPer100,
        'carb_per_100': carbPer100,
        'fat_per_100': fatPer100,
        'date': date,
        'source': source.name,
        'created_at': createdAt.toIso8601String(),
      };

  factory FoodEntry.fromMap(Map<String, dynamic> map) => FoodEntry(
        id: map['id'] as int?,
        foodName: map['food_name'] as String,
        caloriesPer100: (map['calories_per_100'] as num).toDouble(),
        servingGrams: (map['serving_grams'] as num?)?.toDouble(),
        quantity: (map['quantity'] as num).toDouble(),
        unit: ServingUnit.fromName(map['unit'] as String),
        mealType: MealType.fromName(map['meal_type'] as String),
        proteinPer100: (map['protein_per_100'] as num?)?.toDouble(),
        carbPer100: (map['carb_per_100'] as num?)?.toDouble(),
        fatPer100: (map['fat_per_100'] as num?)?.toDouble(),
        date: map['date'] as String,
        source: FoodSource.fromName(map['source'] as String),
        createdAt: DateTime.parse(map['created_at'] as String),
      );
}
