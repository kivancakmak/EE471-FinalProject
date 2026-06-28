import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

import 'gemini_service.dart' show AiEstimate;

class OnDeviceException implements Exception {
  final String message;
  OnDeviceException(this.message);
  @override
  String toString() => message;
}

/// CNN'in bir aday tahmini: gösterimlik ad, ham etiket ve olasılık.
class FoodCandidate {
  final String name; // "Grilled Salmon"
  final String label; // "grilled_salmon"
  final double probability; // 0..1
  final double kcalPer100;
  FoodCandidate(this.name, this.label, this.probability, this.kcalPer100);
}

/// Cihaz-içi (offline) yemek sınıflandırma: Food-101 üzerinde eğitilmiş
/// float16 TFLite modeli ile tahmin yapar, sınıfı kcal/100g'a çevirir.
///
/// Not: int8 yerine fp16 kullanılıyor — MobileNetV3 int8'e çok kötü kuantize
/// oluyordu (top-1 ~%8), fp16 ise neredeyse kayıpsız (~%67). Girdi/çıktı
/// float32'dir (0..255 ham; ölçekleme model içinde).
class OnDeviceFoodService {
  static const _modelAsset = 'assets/models/food_classifier_fp16.tflite';
  static const _labelsAsset = 'assets/models/labels.txt';
  static const _caloriesAsset = 'assets/models/food101_calories.csv';
  static const _imgSize = 224;
  static const _defaultGrams = 300.0; // tipik bir porsiyon; kullanıcı düzeltebilir

  Interpreter? _interpreter;
  List<String> _labels = [];
  Map<String, double> _calories = {};

  int lastLatencyMs = 0;

  bool get isReady => _interpreter != null;

  Future<void> _ensureLoaded() async {
    if (_interpreter != null) return;
    try {
      _interpreter = await Interpreter.fromAsset(_modelAsset);
      final labelData = await rootBundle.loadString(_labelsAsset);
      _labels = labelData
          .split('\n')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
      final csv = await rootBundle.loadString(_caloriesAsset);
      _calories = _parseCalories(csv);
    } catch (e) {
      throw OnDeviceException(
          'Cihaz modeli yüklenemedi. assets/models/ içine '
          'food_classifier_fp16.tflite ve labels.txt koyup yeniden derle. ($e)');
    }
  }

  Map<String, double> _parseCalories(String csv) {
    final map = <String, double>{};
    for (final line in csv.split('\n').skip(1)) {
      final parts = line.split(',');
      if (parts.length >= 3) {
        map[parts[1].trim()] = double.tryParse(parts[2].trim()) ?? 0;
      }
    }
    return map;
  }

  /// Modeli çalıştırıp ham softmax olasılıklarını döndürür (float 0..1).
  Future<List<double>> _infer(Uint8List imageBytes) async {
    await _ensureLoaded();

    final decoded = img.decodeImage(imageBytes);
    if (decoded == null) {
      throw OnDeviceException('Görsel çözümlenemedi.');
    }
    final resized =
        img.copyResize(decoded, width: _imgSize, height: _imgSize);

    // fp16 model: 0..255 float32 girdi [1,224,224,3] (ölçekleme model içinde).
    final input = List.generate(
      1,
      (_) => List.generate(
        _imgSize,
        (y) => List.generate(_imgSize, (x) {
          final p = resized.getPixel(x, y);
          return [p.r.toDouble(), p.g.toDouble(), p.b.toDouble()];
        }),
      ),
    );

    final numClasses = _labels.length;
    final output =
        List.generate(1, (_) => List<double>.filled(numClasses, 0.0));

    final sw = Stopwatch()..start();
    _interpreter!.run(input, output);
    sw.stop();
    lastLatencyMs = sw.elapsedMilliseconds;

    return output[0];
  }

  /// Fotoğraf baytlarından tek (en olası) tahmin üretir.
  Future<AiEstimate> estimate(Uint8List imageBytes) async {
    final scores = await _infer(imageBytes);
    var best = 0;
    for (var i = 1; i < scores.length; i++) {
      if (scores[i] > scores[best]) best = i;
    }
    final label = _labels[best];
    final prob = scores[best]; // fp16 model doğrudan softmax olasılığı verir
    final kcal100 = _calories[label] ?? 0;

    return AiEstimate(
      foodName: _prettify(label),
      estimatedGrams: _defaultGrams,
      calories: kcal100 * _defaultGrams / 100,
      confidence: prob > 0.6 ? 'high' : (prob > 0.35 ? 'medium' : 'low'),
    );
  }

  /// En olası ilk [k] adayı (olasılığa göre azalan) döndürür.
  /// Gemma'ya verilip "hangisi daha olası" diye seçtirmek için kullanılır.
  Future<List<FoodCandidate>> classifyTopK(Uint8List imageBytes,
      {int k = 3}) async {
    final scores = await _infer(imageBytes);
    final idx = List<int>.generate(scores.length, (i) => i)
      ..sort((a, b) => scores[b].compareTo(scores[a]));
    final top = idx.take(k).map((i) {
      final label = _labels[i];
      return FoodCandidate(
        _prettify(label),
        label,
        scores[i],
        _calories[label] ?? 0,
      );
    }).toList();
    return top;
  }

  /// "grilled_salmon" -> "Grilled Salmon"
  String _prettify(String label) => label
      .split('_')
      .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
      .join(' ');

  void dispose() {
    _interpreter?.close();
    _interpreter = null;
  }
}
