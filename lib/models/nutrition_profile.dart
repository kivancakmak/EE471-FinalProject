enum BiologicalSex {
  female,
  male;

  String get label => this == female ? 'Kadın' : 'Erkek';

  static BiologicalSex fromName(String? value) =>
      BiologicalSex.values.firstWhere(
        (item) => item.name == value,
        orElse: () => BiologicalSex.male,
      );
}

enum ActivityLevel {
  sedentary,
  light,
  moderate,
  active,
  veryActive;

  String get label => switch (this) {
    sedentary => 'Hareketsiz',
    light => 'Hafif aktif',
    moderate => 'Orta aktif',
    active => 'Aktif',
    veryActive => 'Çok aktif',
  };

  double get multiplier => switch (this) {
    sedentary => 1.2,
    light => 1.375,
    moderate => 1.55,
    active => 1.725,
    veryActive => 1.9,
  };

  static ActivityLevel fromName(String? value) =>
      ActivityLevel.values.firstWhere(
        (item) => item.name == value,
        orElse: () => ActivityLevel.moderate,
      );
}

enum NutritionGoal {
  lose,
  maintain,
  gain;

  String get label => switch (this) {
    lose => 'Kilo ver',
    maintain => 'Kiloyu koru',
    gain => 'Kas / kilo kazan',
  };

  static NutritionGoal fromName(String? value) =>
      NutritionGoal.values.firstWhere(
        (item) => item.name == value,
        orElse: () => NutritionGoal.maintain,
      );
}

class NutritionProfile {
  final int age;
  final double heightCm;
  final double weightKg;
  final BiologicalSex sex;
  final ActivityLevel activityLevel;
  final NutritionGoal goal;
  final int trainingDaysPerWeek;

  const NutritionProfile({
    required this.age,
    required this.heightCm,
    required this.weightKg,
    required this.sex,
    required this.activityLevel,
    required this.goal,
    required this.trainingDaysPerWeek,
  });

  Map<String, dynamic> toJson() => {
    'age': age,
    'height_cm': heightCm,
    'weight_kg': weightKg,
    'sex': sex.name,
    'activity_level': activityLevel.name,
    'goal': goal.name,
    'training_days_per_week': trainingDaysPerWeek,
  };
}
