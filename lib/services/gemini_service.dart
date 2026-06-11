import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

/// Gemini'nin bir yemek fotoğrafından döndürdüğü tahmin.
class AiEstimate {
  final String foodName;
  final double estimatedGrams;
  final double calories;
  final double? protein;
  final double? carbs;
  final double? fat;
  final String confidence; // low | medium | high

  AiEstimate({
    required this.foodName,
    required this.estimatedGrams,
    required this.calories,
    this.protein,
    this.carbs,
    this.fat,
    required this.confidence,
  });

  /// 100 g başına kalori (kayıt modeli bunu kullanır).
  double get caloriesPer100 =>
      estimatedGrams > 0 ? calories * 100 / estimatedGrams : calories;
}

class GeminiException implements Exception {
  final String message;
  GeminiException(this.message);
  @override
  String toString() => message;
}

/// Gemini vision modeline fotoğraf gönderip kalori tahmini alır.
class GeminiService {
  static const _model = 'gemini-2.5-flash';
  final http.Client _client;

  GeminiService({http.Client? client}) : _client = client ?? http.Client();

  static const _prompt = '''
Bu fotoğraftaki yemeği analiz et. Tek bir ana yemek/öğün olduğunu varsay.
Yanıtı SADECE şu JSON şemasıyla ver, başka metin ekleme:
{
  "food_name": "<yemeğin Türkçe adı>",
  "estimated_grams": <tahmini porsiyon gram, sayı>,
  "calories": <bu porsiyonun toplam tahmini kalorisi, sayı>,
  "protein": <tahmini protein gramı, sayı>,
  "carbs": <tahmini karbonhidrat gramı, sayı>,
  "fat": <tahmini yağ gramı, sayı>,
  "confidence": "<low|medium|high>"
}
Yemek tanınamıyorsa food_name'i "Bilinmeyen" yap ve sayıları 0 ver.
''';

  Future<AiEstimate> estimateFromImage({
    required Uint8List imageBytes,
    required String mimeType,
    required String apiKey,
    void Function(int attempt)? onRetry,
  }) async {
    if (apiKey.trim().isEmpty) {
      throw GeminiException('Gemini API anahtarı tanımlı değil.');
    }

    final uri = Uri.https(
      'generativelanguage.googleapis.com',
      '/v1beta/models/$_model:generateContent',
      {'key': apiKey.trim()},
    );

    final body = jsonEncode({
      'contents': [
        {
          'parts': [
            {'text': _prompt},
            {
              'inline_data': {
                'mime_type': mimeType,
                'data': base64Encode(imageBytes),
              }
            },
          ]
        }
      ],
      'generationConfig': {'responseMimeType': 'application/json'},
    });

    // Geçici hatalarda (sunucu yoğun / ağ) üstel beklemeyle yeniden dene.
    const maxAttempts = 3;
    const transientCodes = {500, 502, 503, 504};
    http.Response? res;

    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        res = await _client
            .post(uri,
                headers: {'Content-Type': 'application/json'}, body: body)
            .timeout(const Duration(seconds: 40));
      } catch (e) {
        // Ağ/zaman aşımı: son deneme değilse tekrar dene.
        if (attempt == maxAttempts) {
          throw GeminiException('Bağlantı hatası: $e');
        }
        onRetry?.call(attempt);
        await Future.delayed(Duration(seconds: attempt));
        continue;
      }

      // Kalıcı hatalar: hemen dur, tekrar deneme.
      if (res.statusCode == 400 || res.statusCode == 403) {
        throw GeminiException(
            'API anahtarı geçersiz veya yetkisiz (${res.statusCode}).');
      }
      if (res.statusCode == 429) {
        throw GeminiException('Günlük ücretsiz kota doldu, sonra deneyin.');
      }

      // Geçici hata: bekle ve tekrar dene.
      if (transientCodes.contains(res.statusCode)) {
        if (attempt == maxAttempts) {
          throw GeminiException(
              'Gemini sunucuları şu an yoğun (${res.statusCode}). '
              'Lütfen birkaç saniye sonra tekrar dene.');
        }
        onRetry?.call(attempt);
        await Future.delayed(Duration(seconds: attempt));
        continue;
      }

      if (res.statusCode != 200) {
        throw GeminiException('Gemini hatası: ${res.statusCode}');
      }
      break; // 200 OK
    }

    final data = jsonDecode(utf8.decode(res!.bodyBytes));
    final text = _extractText(data);
    if (text == null) {
      throw GeminiException('Model boş yanıt döndürdü.');
    }

    return _parseEstimate(text);
  }

  String? _extractText(dynamic data) {
    try {
      final parts = data['candidates'][0]['content']['parts'] as List;
      for (final part in parts) {
        final t = part['text'];
        if (t is String && t.trim().isNotEmpty) return t;
      }
    } catch (_) {}
    return null;
  }

  AiEstimate _parseEstimate(String text) {
    // Olası markdown ```json``` çitlerini temizle.
    var clean = text.trim();
    if (clean.startsWith('```')) {
      clean = clean.replaceAll(RegExp(r'```[a-zA-Z]*'), '').replaceAll('```', '').trim();
    }
    try {
      final json = jsonDecode(clean) as Map<String, dynamic>;
      return AiEstimate(
        foodName: (json['food_name'] as String?)?.trim().isNotEmpty == true
            ? json['food_name'] as String
            : 'Bilinmeyen',
        estimatedGrams: _num(json['estimated_grams']),
        calories: _num(json['calories']),
        protein: json['protein'] == null ? null : _num(json['protein']),
        carbs: json['carbs'] == null ? null : _num(json['carbs']),
        fat: json['fat'] == null ? null : _num(json['fat']),
        confidence: (json['confidence'] as String?) ?? 'low',
      );
    } catch (e) {
      throw GeminiException('Yanıt çözümlenemedi: $clean');
    }
  }

  double _num(dynamic v) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v.replaceAll(',', '.')) ?? 0;
    return 0;
  }
}
