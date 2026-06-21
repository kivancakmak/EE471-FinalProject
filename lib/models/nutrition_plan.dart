class NutritionTargets {
  final int calories;
  final int proteinGrams;
  final int carbGrams;
  final int fatGrams;
  final int waterMl;

  const NutritionTargets({
    required this.calories,
    required this.proteinGrams,
    required this.carbGrams,
    required this.fatGrams,
    required this.waterMl,
  });

  Map<String, dynamic> toJson() => {
    'calories': calories,
    'protein_grams': proteinGrams,
    'carb_grams': carbGrams,
    'fat_grams': fatGrams,
    'water_ml': waterMl,
  };

  factory NutritionTargets.fromJson(Map<String, dynamic> json) =>
      NutritionTargets(
        calories: (json['calories'] as num).round(),
        proteinGrams: (json['protein_grams'] as num).round(),
        carbGrams: (json['carb_grams'] as num).round(),
        fatGrams: (json['fat_grams'] as num).round(),
        waterMl: (json['water_ml'] as num).round(),
      );
}

class PlannedMeal {
  final String title;
  final String description;
  final int calories;
  final int proteinGrams;
  final List<String> shoppingItems;

  const PlannedMeal({
    required this.title,
    required this.description,
    required this.calories,
    required this.proteinGrams,
    required this.shoppingItems,
  });

  factory PlannedMeal.fromJson(Map<String, dynamic> json) => PlannedMeal(
    title: json['title'] as String,
    description: json['description'] as String,
    calories: (json['calories'] as num).round(),
    proteinGrams: (json['protein_grams'] as num).round(),
    shoppingItems: (json['shopping_items'] as List)
        .map((item) => item.toString())
        .toList(),
  );
}

class DailyMealPlan {
  final String dayLabel;
  final bool trainingDay;
  final List<PlannedMeal> meals;

  const DailyMealPlan({
    required this.dayLabel,
    required this.trainingDay,
    required this.meals,
  });

  factory DailyMealPlan.fromJson(Map<String, dynamic> json) => DailyMealPlan(
    dayLabel: json['day_label'] as String,
    trainingDay: json['training_day'] as bool,
    meals: (json['meals'] as List)
        .map((item) => PlannedMeal.fromJson(item as Map<String, dynamic>))
        .toList(),
  );

  int get totalCalories => meals.fold(0, (sum, meal) => sum + meal.calories);
  int get totalProtein => meals.fold(0, (sum, meal) => sum + meal.proteinGrams);
}

class WeeklyNutritionPlan {
  final NutritionTargets targets;
  final List<DailyMealPlan> days;
  final String source;

  const WeeklyNutritionPlan({
    required this.targets,
    required this.days,
    this.source = 'local',
  });

  factory WeeklyNutritionPlan.fromJson(Map<String, dynamic> json) =>
      WeeklyNutritionPlan(
        targets: NutritionTargets.fromJson(
          json['targets'] as Map<String, dynamic>,
        ),
        days: (json['days'] as List)
            .map((item) => DailyMealPlan.fromJson(item as Map<String, dynamic>))
            .toList(),
        source: json['source'] as String? ?? 'cloud',
      );

  List<String> get shoppingList {
    final items = <String>{};
    for (final day in days) {
      for (final meal in day.meals) {
        items.addAll(meal.shoppingItems);
      }
    }
    final sorted = items.toList()..sort();
    return sorted;
  }
}

class ProgressInsight {
  final String title;
  final String message;
  final int loggedDays;
  final int averageCalories;
  final int averageProtein;

  const ProgressInsight({
    required this.title,
    required this.message,
    required this.loggedDays,
    required this.averageCalories,
    required this.averageProtein,
  });
}
