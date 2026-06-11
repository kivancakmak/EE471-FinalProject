import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Günlük kalori hedefi, tema ve Gemini API anahtarı gibi kullanıcı ayarları.
class SettingsProvider extends ChangeNotifier {
  static const _goalKey = 'daily_calorie_goal';
  static const _apiKeyKey = 'gemini_api_key';
  static const _themeKey = 'theme_mode';
  static const _nameKey = 'user_name';
  static const _weightKey = 'weight_goal';
  static const _notifKey = 'notifications';

  final SharedPreferences _prefs;

  int _calorieGoal;
  String _geminiApiKey;
  ThemeMode _themeMode;
  String _userName;
  int _weightGoal;
  bool _notifications;

  SettingsProvider(this._prefs)
      : _calorieGoal = _prefs.getInt(_goalKey) ?? 2000,
        // Önce kullanıcının kaydettiği anahtar, yoksa .env'deki varsayılan.
        _geminiApiKey = _prefs.getString(_apiKeyKey) ??
            (dotenv.maybeGet('GEMINI_API_KEY') ?? ''),
        _themeMode = _parseTheme(_prefs.getString(_themeKey)),
        _userName = _prefs.getString(_nameKey) ?? 'Kullanıcı',
        _weightGoal = _prefs.getInt(_weightKey) ?? 75,
        _notifications = _prefs.getBool(_notifKey) ?? true;

  int get calorieGoal => _calorieGoal;
  String get geminiApiKey => _geminiApiKey;
  bool get hasApiKey => _geminiApiKey.trim().isNotEmpty;
  ThemeMode get themeMode => _themeMode;
  String get userName => _userName;
  int get weightGoal => _weightGoal;
  bool get notifications => _notifications;

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
}
