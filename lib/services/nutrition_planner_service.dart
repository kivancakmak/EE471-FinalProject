import 'dart:math' as math;

import '../models/food_entry.dart';
import '../models/nutrition_plan.dart';
import '../models/nutrition_profile.dart';

abstract interface class NutritionCoachService {
  NutritionTargets calculateTargets(NutritionProfile profile);
  WeeklyNutritionPlan createWeeklyPlan(NutritionProfile profile);
  ProgressInsight reviewProgress(
    List<FoodEntry> entries,
    NutritionTargets targets,
  );
}

/// Hesapları ve örnek planı cihazda üretir. Bir bulut LLM kullanmaz.
class NutritionPlannerService implements NutritionCoachService {
  const NutritionPlannerService();

  @override
  NutritionTargets calculateTargets(NutritionProfile profile) {
    final sexOffset = profile.sex == BiologicalSex.male ? 5 : -161;
    final bmr =
        10 * profile.weightKg +
        6.25 * profile.heightCm -
        5 * profile.age +
        sexOffset;
    final maintenance = bmr * profile.activityLevel.multiplier;
    final calorieAdjustment = switch (profile.goal) {
      NutritionGoal.lose => -400,
      NutritionGoal.maintain => 0,
      NutritionGoal.gain => 300,
    };
    final calories = math.max(1200, (maintenance + calorieAdjustment).round());

    final proteinFactor = switch (profile.goal) {
      NutritionGoal.lose => 1.8,
      NutritionGoal.maintain => 1.6,
      NutritionGoal.gain => 2.0,
    };
    final protein = (profile.weightKg * proteinFactor).round();
    final fat = math.max(40, (profile.weightKg * 0.8).round());
    final carbs = math.max(
      80,
      ((calories - protein * 4 - fat * 9) / 4).round(),
    );

    return NutritionTargets(
      calories: calories,
      proteinGrams: protein,
      carbGrams: carbs,
      fatGrams: fat,
      waterMl: math.max(1800, (profile.weightKg * 35).round()),
    );
  }

  @override
  WeeklyNutritionPlan createWeeklyPlan(NutritionProfile profile) {
    final targets = calculateTargets(profile);
    const labels = [
      'Pazartesi',
      'Salı',
      'Çarşamba',
      'Perşembe',
      'Cuma',
      'Cumartesi',
      'Pazar',
    ];
    final trainingDays = _trainingDayIndexes(profile.trainingDaysPerWeek);

    final days = List.generate(labels.length, (index) {
      final training = trainingDays.contains(index);
      final menu = _menus[index % _menus.length];
      final scale = targets.calories / menu.baseCalories;
      return DailyMealPlan(
        dayLabel: labels[index],
        trainingDay: training,
        meals: menu.meals
            .map(
              (meal) => PlannedMeal(
                title: meal.title,
                description: meal.description,
                calories: (meal.calories * scale).round(),
                proteinGrams: (meal.protein * scale).round(),
                shoppingItems: meal.shoppingItems,
              ),
            )
            .toList(),
      );
    });

    return WeeklyNutritionPlan(targets: targets, days: days);
  }

  @override
  ProgressInsight reviewProgress(
    List<FoodEntry> entries,
    NutritionTargets targets,
  ) {
    final byDate = <String, List<FoodEntry>>{};
    for (final entry in entries) {
      byDate.putIfAbsent(entry.date, () => []).add(entry);
    }
    if (byDate.isEmpty) {
      return const ProgressInsight(
        title: 'Takibe başla',
        message:
            'Haftalık yorum için en az bir günlük öğünlerini kaydet. Düzenli kayıt, planı kişiselleştirmenin temelidir.',
        loggedDays: 0,
        averageCalories: 0,
        averageProtein: 0,
      );
    }

    final calorieTotals = byDate.values
        .map((day) => day.fold<double>(0, (sum, entry) => sum + entry.calories))
        .toList();
    final proteinTotals = byDate.values
        .map(
          (day) =>
              day.fold<double>(0, (sum, entry) => sum + (entry.protein ?? 0)),
        )
        .toList();
    final averageCalories =
        (calorieTotals.reduce((a, b) => a + b) / calorieTotals.length).round();
    final averageProtein =
        (proteinTotals.reduce((a, b) => a + b) / proteinTotals.length).round();
    final calorieRatio = averageCalories / targets.calories;
    final proteinRatio = averageProtein / targets.proteinGrams;

    final (title, message) = switch ((calorieRatio, proteinRatio)) {
      (< 0.75, _) => (
        'Enerji alımın düşük',
        'Ortalama kalorin hedefin oldukça altında. Öğün atlamamaya ve sürdürülebilir bir açık oluşturmaya dikkat et.',
      ),
      (> 1.2, _) => (
        'Kalori hedefini gözden geçir',
        'Ortalama alımın hedefinin üzerinde. Porsiyonları biraz küçültmek ve sıvı kalorileri kontrol etmek yardımcı olabilir.',
      ),
      (_, < 0.75) => (
        'Protein desteği ekle',
        'Kalori dengen iyi görünüyor ancak protein düşük. Ana öğünlere yoğurt, yumurta, baklagil veya yağsız et ekleyebilirsin.',
      ),
      _ => (
        'İyi ilerliyorsun',
        'Kalori ve protein ortalaman hedeflerine yakın. Aynı düzeni sürdür ve haftalık değişimi takip et.',
      ),
    };

    return ProgressInsight(
      title: title,
      message: message,
      loggedDays: byDate.length,
      averageCalories: averageCalories,
      averageProtein: averageProtein,
    );
  }

  Set<int> _trainingDayIndexes(int count) {
    const preferred = [0, 2, 4, 5, 1, 3, 6];
    return preferred.take(count.clamp(0, 7)).toSet();
  }
}

class _MealTemplate {
  final String title;
  final String description;
  final int calories;
  final int protein;
  final List<String> shoppingItems;

  const _MealTemplate(
    this.title,
    this.description,
    this.calories,
    this.protein,
    this.shoppingItems,
  );
}

class _MenuTemplate {
  final int baseCalories;
  final List<_MealTemplate> meals;

  const _MenuTemplate(this.baseCalories, this.meals);
}

const _menus = [
  _MenuTemplate(2000, [
    _MealTemplate('Kahvaltı', 'Yulaf, yoğurt, muz ve ceviz', 500, 25, [
      'Yulaf',
      'Yoğurt',
      'Muz',
      'Ceviz',
    ]),
    _MealTemplate('Öğle', 'Izgara tavuk, bulgur ve mevsim salata', 650, 50, [
      'Tavuk göğsü',
      'Bulgur',
      'Salata malzemeleri',
    ]),
    _MealTemplate('Ara öğün', 'Kefir ve elma', 250, 10, ['Kefir', 'Elma']),
    _MealTemplate(
      'Akşam',
      'Mercimek çorbası, tam buğday ekmeği ve cacık',
      600,
      30,
      ['Mercimek', 'Tam buğday ekmeği', 'Yoğurt', 'Salatalık'],
    ),
  ]),
  _MenuTemplate(2000, [
    _MealTemplate(
      'Kahvaltı',
      'Yumurta, peynir, domates ve tam buğday ekmeği',
      500,
      32,
      ['Yumurta', 'Peynir', 'Domates', 'Tam buğday ekmeği'],
    ),
    _MealTemplate(
      'Öğle',
      'Etli kuru fasulye, pirinç pilavı ve ayran',
      700,
      42,
      ['Kuru fasulye', 'Yağsız dana eti', 'Pirinç', 'Ayran'],
    ),
    _MealTemplate('Ara öğün', 'Badem ve mevsim meyvesi', 250, 7, [
      'Badem',
      'Mevsim meyvesi',
    ]),
    _MealTemplate('Akşam', 'Ton balıklı büyük salata ve yoğurt', 550, 42, [
      'Ton balığı',
      'Salata malzemeleri',
      'Yoğurt',
    ]),
  ]),
  _MenuTemplate(2000, [
    _MealTemplate('Kahvaltı', 'Sebzeli omlet ve ayran', 450, 32, [
      'Yumurta',
      'Biber',
      'Domates',
      'Ayran',
    ]),
    _MealTemplate('Öğle', 'Hindi sandviç ve mercimek çorbası', 650, 45, [
      'Hindi füme',
      'Tam buğday ekmeği',
      'Mercimek',
      'Yeşillik',
    ]),
    _MealTemplate('Ara öğün', 'Yoğurt, yaban mersini ve yulaf', 300, 17, [
      'Yoğurt',
      'Yaban mersini',
      'Yulaf',
    ]),
    _MealTemplate('Akşam', 'Fırında somon, patates ve sebze', 600, 42, [
      'Somon',
      'Patates',
      'Mevsim sebzeleri',
    ]),
  ]),
];
