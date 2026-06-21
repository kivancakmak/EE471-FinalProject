import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/nutrition_profile.dart';

/// Günlük kalori hedefi, tema ve Gemini API anahtarı gibi kullanıcı ayarları.
class SettingsProvider extends ChangeNotifier {
  static const _goalKey = 'daily_calorie_goal';
  static const _apiKeyKey = 'gemini_api_key';
  static const _themeKey = 'theme_mode';
  static const _nameKey = 'user_name';
  static const _weightKey = 'weight_goal';
  static const _notifKey = 'notifications';
  static const _ageKey = 'profile_age';
  static const _heightKey = 'profile_height_cm';
  static const _currentWeightKey = 'profile_current_weight_kg';
  static const _sexKey = 'profile_sex';
  static const _activityKey = 'profile_activity';
  static const _nutritionGoalKey = 'profile_nutrition_goal';
  static const _trainingDaysKey = 'profile_training_days';
  static const _coachBackendUrlKey = 'coach_backend_url';

  final SharedPreferences _prefs;

  int _calorieGoal;
  String _geminiApiKey;
  ThemeMode _themeMode;
  String _userName;
  int _weightGoal;
  bool _notifications;
  int _age;
  double _heightCm;
  double _currentWeightKg;
  BiologicalSex _sex;
  ActivityLevel _activityLevel;
  NutritionGoal _nutritionGoal;
  int _trainingDaysPerWeek;
  String _coachBackendUrl;

  SettingsProvider(this._prefs)
    : _calorieGoal = _prefs.getInt(_goalKey) ?? 2000,
      // Önce kullanıcının kaydettiği anahtar, yoksa .env'deki varsayılan.
      _geminiApiKey =
          _prefs.getString(_apiKeyKey) ??
          (dotenv.maybeGet('GEMINI_API_KEY') ?? ''),
      _themeMode = _parseTheme(_prefs.getString(_themeKey)),
      _userName = _prefs.getString(_nameKey) ?? 'Kullanıcı',
      _weightGoal = _prefs.getInt(_weightKey) ?? 75,
      _notifications = _prefs.getBool(_notifKey) ?? true,
      _age = _prefs.getInt(_ageKey) ?? 25,
      _heightCm = _prefs.getDouble(_heightKey) ?? 175,
      _currentWeightKg = _prefs.getDouble(_currentWeightKey) ?? 75,
      _sex = BiologicalSex.fromName(_prefs.getString(_sexKey)),
      _activityLevel = ActivityLevel.fromName(_prefs.getString(_activityKey)),
      _nutritionGoal = NutritionGoal.fromName(
        _prefs.getString(_nutritionGoalKey),
      ),
      _trainingDaysPerWeek = _prefs.getInt(_trainingDaysKey) ?? 3,
      _coachBackendUrl =
          _prefs.getString(_coachBackendUrlKey) ?? 'http://10.0.2.2:8000';

  int get calorieGoal => _calorieGoal;
  String get geminiApiKey => _geminiApiKey;
  bool get hasApiKey => _geminiApiKey.trim().isNotEmpty;
  ThemeMode get themeMode => _themeMode;
  String get userName => _userName;
  int get weightGoal => _weightGoal;
  bool get notifications => _notifications;
  int get age => _age;
  double get heightCm => _heightCm;
  double get currentWeightKg => _currentWeightKg;
  BiologicalSex get sex => _sex;
  ActivityLevel get activityLevel => _activityLevel;
  NutritionGoal get nutritionGoal => _nutritionGoal;
  int get trainingDaysPerWeek => _trainingDaysPerWeek;
  String get coachBackendUrl => _coachBackendUrl;
  NutritionProfile get nutritionProfile => NutritionProfile(
    age: _age,
    heightCm: _heightCm,
    weightKg: _currentWeightKg,
    sex: _sex,
    activityLevel: _activityLevel,
    goal: _nutritionGoal,
    trainingDaysPerWeek: _trainingDaysPerWeek,
  );

  // Makro hedefleri kalori hedefinden 30/40/30 (P/K/Y) dağılımıyla türetilir.
  int get proteinGoal => (_calorieGoal * 0.30 / 4).round();
  int get carbGoal => (_calorieGoal * 0.40 / 4).round();
  int get fatGoal => (_calorieGoal * 0.30 / 9).round();

  static ThemeMode _parseTheme(String? v) => switch (v) {
    'light' => ThemeMode.light,
    'dark' => ThemeMode.dark,
    _ => ThemeMode.system,
  };

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    await _prefs.setString(_themeKey, mode.name);
    notifyListeners();
  }

  Future<void> setCalorieGoal(int value) async {
    if (value <= 0) return;
    _calorieGoal = value;
    await _prefs.setInt(_goalKey, value);
    notifyListeners();
  }

  Future<void> setGeminiApiKey(String value) async {
    _geminiApiKey = value.trim();
    await _prefs.setString(_apiKeyKey, _geminiApiKey);
    notifyListeners();
  }

  Future<void> setUserName(String value) async {
    final v = value.trim();
    if (v.isEmpty) return;
    _userName = v;
    await _prefs.setString(_nameKey, v);
    notifyListeners();
  }

  Future<void> setWeightGoal(int value) async {
    if (value <= 0) return;
    _weightGoal = value;
    await _prefs.setInt(_weightKey, value);
    notifyListeners();
  }

  Future<void> setNotifications(bool value) async {
    _notifications = value;
    await _prefs.setBool(_notifKey, value);
    notifyListeners();
  }

  Future<void> setNutritionProfile(NutritionProfile profile) async {
    _age = profile.age;
    _heightCm = profile.heightCm;
    _currentWeightKg = profile.weightKg;
    _sex = profile.sex;
    _activityLevel = profile.activityLevel;
    _nutritionGoal = profile.goal;
    _trainingDaysPerWeek = profile.trainingDaysPerWeek;

    await Future.wait([
      _prefs.setInt(_ageKey, _age),
      _prefs.setDouble(_heightKey, _heightCm),
      _prefs.setDouble(_currentWeightKey, _currentWeightKg),
      _prefs.setString(_sexKey, _sex.name),
      _prefs.setString(_activityKey, _activityLevel.name),
      _prefs.setString(_nutritionGoalKey, _nutritionGoal.name),
      _prefs.setInt(_trainingDaysKey, _trainingDaysPerWeek),
    ]);
    notifyListeners();
  }

  Future<void> setCoachBackendUrl(String value) async {
    _coachBackendUrl = value.trim();
    await _prefs.setString(_coachBackendUrlKey, _coachBackendUrl);
    notifyListeners();
  }
}
