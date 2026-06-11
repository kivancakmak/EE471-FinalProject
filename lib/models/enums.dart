import 'package:flutter/material.dart';

/// Öğün tipleri. Veritabanında `name` (örn. "breakfast") olarak saklanır.
enum MealType {
  breakfast,
  lunch,
  dinner,
  snack;

  /// Türkçe görünen ad.
  String get label {
    switch (this) {
      case MealType.breakfast:
        return 'Kahvaltı';
      case MealType.lunch:
        return 'Öğle';
      case MealType.dinner:
        return 'Akşam';
      case MealType.snack:
        return 'Atıştırmalık';
    }
  }

  IconData get icon {
    switch (this) {
      case MealType.breakfast:
        return Icons.free_breakfast;
      case MealType.lunch:
        return Icons.lunch_dining;
      case MealType.dinner:
        return Icons.dinner_dining;
      case MealType.snack:
        return Icons.cookie;
    }
  }

  static MealType fromName(String name) =>
      MealType.values.firstWhere((e) => e.name == name,
          orElse: () => MealType.snack);
}

/// Miktar birimi. `portion` için porsiyon başına gram bilgisi gerekir.
enum ServingUnit {
  portion,
  gram,
  milliliter;

  String get label {
    switch (this) {
      case ServingUnit.portion:
        return 'porsiyon';
      case ServingUnit.gram:
        return 'g';
      case ServingUnit.milliliter:
        return 'ml';
    }
  }

  static ServingUnit fromName(String name) =>
      ServingUnit.values.firstWhere((e) => e.name == name,
          orElse: () => ServingUnit.gram);
}

/// Kaydın nereden geldiği.
enum FoodSource {
  off, // Open Food Facts
  manual, // Kullanıcı elle girdi
  ai; // Gemini fotoğraf tahmini

  static FoodSource fromName(String name) =>
      FoodSource.values.firstWhere((e) => e.name == name,
          orElse: () => FoodSource.manual);
}
