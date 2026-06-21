import 'package:flutter_test/flutter_test.dart';
import 'package:kalori_takip/models/enums.dart';
import 'package:kalori_takip/models/food.dart';
import 'package:kalori_takip/models/food_entry.dart';
import 'package:kalori_takip/models/nutrition_profile.dart';
import 'package:kalori_takip/models/nutrition_plan.dart';
import 'package:kalori_takip/services/nutrition_planner_service.dart';

FoodEntry _entry({
  required double caloriesPer100,
  double? servingGrams,
  required double quantity,
  required ServingUnit unit,
}) {
  return FoodEntry(
    foodName: 'Test',
    caloriesPer100: caloriesPer100,
    servingGrams: servingGrams,
    quantity: quantity,
    unit: unit,
    mealType: MealType.lunch,
    date: '2026-06-10',
    source: FoodSource.manual,
    createdAt: DateTime(2026, 6, 10),
  );
}

void main() {
  group('Kalori hesaplama', () {
    test('gram birimi doğrudan ölçeklenir', () {
      final e = _entry(
        caloriesPer100: 100,
        quantity: 250,
        unit: ServingUnit.gram,
      );
      expect(e.calories, 250);
    });

    test('ml birimi gram gibi ölçeklenir', () {
      final e = _entry(
        caloriesPer100: 40,
        quantity: 200,
        unit: ServingUnit.milliliter,
      );
      expect(e.calories, 80);
    });

    test('porsiyon birimi serving_grams ile çarpılır', () {
      final e = _entry(
        caloriesPer100: 150,
        servingGrams: 50,
        quantity: 2,
        unit: ServingUnit.portion,
      );
      // 2 porsiyon * 50 g = 100 g -> 150 kcal
      expect(e.calories, 150);
    });

    test('serving_grams yoksa porsiyon 100 g varsayılır', () {
      final e = _entry(
        caloriesPer100: 90,
        quantity: 1,
        unit: ServingUnit.portion,
      );
      expect(e.calories, 90);
    });

    test('makrolar da miktara göre ölçeklenir', () {
      final food = Food(
        name: 'Tavuk',
        caloriesPer100: 165,
        proteinPer100: 31,
        servingGrams: 100,
      );
      final e = FoodEntry.fromFood(
        food: food,
        quantity: 200,
        unit: ServingUnit.gram,
        mealType: MealType.dinner,
        date: '2026-06-10',
      );
      expect(e.calories, 330);
      expect(e.protein, 62);
    });
  });

  group('Open Food Facts ayrıştırma', () {
    test('kalorisi olmayan ürün elenir', () {
      final food = Food.fromOffProduct({
        'product_name': 'Su',
        'nutriments': {'proteins_100g': 0},
      });
      expect(food, isNull);
    });

    test('geçerli ürün modele çevrilir', () {
      final food = Food.fromOffProduct({
        'product_name': 'Muz',
        'nutriments': {'energy-kcal_100g': 89, 'carbohydrates_100g': 23},
        'serving_quantity': 120,
        'code': '123',
      });
      expect(food, isNotNull);
      expect(food!.caloriesPer100, 89);
      expect(food.servingGrams, 120);
      expect(food.source, FoodSource.off);
    });
  });

  group('Beslenme planlayıcı', () {
    const planner = NutritionPlannerService();
    const profile = NutritionProfile(
      age: 25,
      heightCm: 180,
      weightKg: 80,
      sex: BiologicalSex.male,
      activityLevel: ActivityLevel.moderate,
      goal: NutritionGoal.lose,
      trainingDaysPerWeek: 3,
    );

    test('profil için makul hedefler hesaplar', () {
      final targets = planner.calculateTargets(profile);
      expect(targets.calories, inInclusiveRange(1800, 3000));
      expect(targets.proteinGrams, 144);
      expect(targets.carbGrams, greaterThan(80));
      expect(targets.waterMl, 2800);
    });

    test('yedi günlük plan ve alışveriş listesi üretir', () {
      final plan = planner.createWeeklyPlan(profile);
      expect(plan.days, hasLength(7));
      expect(plan.days.where((day) => day.trainingDay), hasLength(3));
      expect(plan.shoppingList, isNotEmpty);
      expect(plan.days.every((day) => day.meals.length == 4), isTrue);
    });

    test('cloud plan JSON yanıtını ayrıştırır', () {
      final plan = WeeklyNutritionPlan.fromJson({
        'source': 'groq:qwen/qwen3-32b',
        'targets': {
          'calories': 2200,
          'protein_grams': 150,
          'carb_grams': 250,
          'fat_grams': 65,
          'water_ml': 2800,
        },
        'days': List.generate(
          7,
          (index) => {
            'day_label': 'Gün ${index + 1}',
            'training_day': index < 3,
            'meals': [
              {
                'title': 'Kahvaltı',
                'description': 'Yulaf ve yoğurt',
                'calories': 500,
                'protein_grams': 30,
                'shopping_items': ['Yulaf', 'Yoğurt'],
              },
            ],
          },
        ),
      });
      expect(plan.days, hasLength(7));
      expect(plan.source, contains('qwen'));
      expect(plan.shoppingList, contains('Yulaf'));
    });
  });
}
