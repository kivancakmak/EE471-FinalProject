import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/nutrition_plan.dart';
import '../models/nutrition_profile.dart';

class CloudNutritionCoachException implements Exception {
  final String message;
  const CloudNutritionCoachException(this.message);

  @override
  String toString() => message;
}

class CloudNutritionCoachService {
  final http.Client _client;

  CloudNutritionCoachService({http.Client? client})
    : _client = client ?? http.Client();

  Future<WeeklyNutritionPlan> createWeeklyPlan({
    required String backendUrl,
    required NutritionProfile profile,
    required NutritionTargets targets,
    List<String> allergies = const [],
    List<String> dislikedFoods = const [],
  }) async {
    final base = backendUrl.trim().replaceAll(RegExp(r'/$'), '');
    if (base.isEmpty) {
      throw const CloudNutritionCoachException(
        'AI backend adresi tanımlı değil.',
      );
    }

    final response = await _client
        .post(
          Uri.parse('$base/api/v1/nutrition/weekly-plan'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'profile': profile.toJson(),
            'targets': targets.toJson(),
            'allergies': allergies,
            'disliked_foods': dislikedFoods,
          }),
        )
        .timeout(const Duration(seconds: 80));

    if (response.statusCode != 200) {
      var message = 'AI planı üretilemedi (${response.statusCode}).';
      try {
        final body = jsonDecode(utf8.decode(response.bodyBytes));
        if (body is Map && body['detail'] != null) {
          message = body['detail'].toString();
        }
      } catch (_) {}
      throw CloudNutritionCoachException(message);
    }

    try {
      final data =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      final plan = WeeklyNutritionPlan.fromJson(data);
      if (plan.days.length != 7) {
        throw const FormatException('Plan 7 gün içermiyor.');
      }
      return plan;
    } catch (error) {
      throw CloudNutritionCoachException(
        'Backend yanıtı çözümlenemedi: $error',
      );
    }
  }
}
