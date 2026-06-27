import 'dart:convert';
import 'dart:io';

import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:path_provider/path_provider.dart';

import 'gemini_service.dart' show AiEstimate;

/// Gemma servisi hataları. [needsModel] true ise model dosyası cihazda yok
/// (kullanıcıya adb push talimatı gösterilir).
class GemmaException implements Exception {
  final String message;
  final bool needsModel;
  GemmaException(this.message, {this.needsModel = false});
  @override
  String toString() => message;
}

/// On-device (Edge LLM) **muhakeme** servisi: küçük **Gemma 3 1B** modelini
/// MediaPipe LLM Inference (flutter_gemma) ile telefonda çalıştırır.
///
/// Akış (kamera ekranında): fotoğrafı önce kendi eğittiğimiz **CNN** tanır
/// (algı katmanı), bulduğu yemek adını bu servis **Gemma 1B**'ye verir; LLM
/// o yemek için tipik porsiyon + kalori + makroları (metin muhakemesiyle)
/// üretir. Yani "cihazda algı (CNN) + cihazda muhakeme (LLM)" — ikisi de
/// offline.
///
/// Neden 1B (multimodal 3n E2B değil): Gemma 3n E2B (~3 GB) 8 GB+ RAM ister;
/// 6 GB'lık telefonlarda işletim sistemi uygulamayı yükleme anında öldürür
/// (lowmemorykill). 1B (~550 MB int4) orta sınıf telefonda rahat koşar.
///
/// **Model dağıtımı (adb push):**
/// ```
/// adb push gemma3-1b-it-int4.task \
///   /sdcard/Android/data/com.ee471.kalori_takip/files/gemma3-1b-it-int4.task
/// ```
class GemmaVisionService {
  /// adb push ile cihaza atılacak model dosyasının adı (Gemma 3 1B int4).
  static const modelFileName = 'gemma3-1b-it-int4.task';

  InferenceModel? _model;
  InferenceChat? _chat;
  bool _used = false;
  static bool _pluginInitialized = false;

  /// Son çıkarımın gecikmesi (ms) — Edge vs Cloud kıyası için.
  int lastLatencyMs = 0;

  /// Hangi backend'in seçildiği (gpu/cpu) — rapora yazmak için.
  String backendInfo = '';

  /// Son ölçülen bellek durumu (rapor/teşhis için), ör. "2750 MB boş / 5613 MB".
  String lastMemInfo = '';

  /// Gemma 3 1B'yi yüklemek için gereken yaklaşık boş RAM (MB).
  /// Model ~550 MB + çalışma zamanı tamponları → güvenli eşik.
  static const _requiredFreeMb = 1500;

  /// Modelin cihazdaki beklenen mutlak yolu (uygulamaya özel harici dizin).
  Future<String> resolveModelPath() async {
    final dir = await getExternalStorageDirectory();
    if (dir == null) {
      throw GemmaException('Cihazda harici depolama bulunamadı.');
    }
    return '${dir.path}/$modelFileName';
  }

  /// Model dosyası adb push ile atılmış mı?
  Future<bool> isModelPresent() async {
    try {
      return File(await resolveModelPath()).exists();
    } catch (_) {
      return false;
    }
  }

  /// Yüklemeden ÖNCE boş RAM'i kontrol et. Yetersizse, işletim sistemi
  /// uygulamayı bellek yetersizliğinden öldürmeden (lowmemorykill) net bir
  /// hata fırlat. `/proc/meminfo` Android'de okunabilir; plugin gerekmez.
  Future<void> _ensureMemory() async {
    if (!Platform.isAndroid) return;
    int availMb = 0, totalMb = 0;
    try {
      final info = await File('/proc/meminfo').readAsString();
      int kb(String key) {
        final m = RegExp('$key:\\s+(\\d+)\\s*kB').firstMatch(info);
        return m == null ? 0 : int.parse(m.group(1)!);
      }

      availMb = kb('MemAvailable') ~/ 1024;
      totalMb = kb('MemTotal') ~/ 1024;
    } catch (_) {
      return; // meminfo okunamadı → best-effort, sessizce geç.
    }
    if (availMb <= 0) return;
    lastMemInfo = '$availMb MB boş / $totalMb MB';
    if (availMb < _requiredFreeMb) {
      throw GemmaException(
        'Gemma için yeterli boş RAM yok ($availMb MB boş, '
        '~$_requiredFreeMb MB gerekir; toplam $totalMb MB). '
        'Diğer uygulamaları kapatıp tekrar dene.',
      );
    }
  }

  Future<void> _ensureReady() async {
    if (_chat != null) return;

    await _ensureMemory();

    final path = await resolveModelPath();
    if (!await File(path).exists()) {
      throw GemmaException(
        'Gemma model dosyası cihazda yok. Modeli adb push ile yükleyin.',
        needsModel: true,
      );
    }

    try {
      // Eklenti servis kayıt defterini bir kez başlat (yerel dosya; token gerekmez).
      if (!_pluginInitialized) {
        await FlutterGemma.initialize();
        _pluginInitialized = true;
      }

      // Cihazdaki dosyayı aktif model olarak kaydet (indirme yok).
      await FlutterGemma.installModel(
        modelType: ModelType.gemmaIt,
        fileType: ModelFileType.task,
      ).fromFile(path).install();

      // Metin (görüntüsüz) çıkarım modeli — küçük ve hızlı.
      final model = await FlutterGemmaPlugin.instance.createModel(
        modelType: ModelType.gemmaIt,
        fileType: ModelFileType.task,
        maxTokens: 512,
        preferredBackend: PreferredBackend.gpu,
      );
      backendInfo = (model.activeBackend ?? PreferredBackend.cpu).name;

      _model = model;
      _chat = await model.createChat();
      _used = false;
    } catch (e) {
      await dispose();
      throw GemmaException('Gemma yüklenemedi: $e');
    }
  }

  /// CNN'in tanıdığı yemek adından (ve tahmini gramdan) kalori + makroları
  /// cihaz-içi Gemma 1B ile muhakeme eder.
  Future<AiEstimate> estimateFromText({
    required String foodName,
    double? grams,
  }) async {
    await _ensureReady();
    final chat = _chat!;

    if (_used) {
      await chat.clearHistory();
    }
    _used = true;

    final portion = (grams != null && grams > 0)
        ? '${grams.round()} g'
        : 'tipik bir porsiyon';
    final prompt = '''
"$foodName" adlı yemeğin $portion'lık porsiyonunu besin değeri açısından değerlendir.
Yanıtı SADECE şu JSON şemasıyla ver, başka metin/açıklama ekleme:
{
  "food_name": "$foodName",
  "estimated_grams": <porsiyon gramı, sayı>,
  "calories": <toplam kalori, sayı>,
  "protein": <protein gramı, sayı>,
  "carbs": <karbonhidrat gramı, sayı>,
  "fat": <yağ gramı, sayı>,
  "confidence": "<low|medium|high>"
}
''';

    final sw = Stopwatch()..start();
    await chat.addQueryChunk(Message.text(text: prompt, isUser: true));
    final ModelResponse resp = await chat.generateChatResponse();
    sw.stop();
    lastLatencyMs = sw.elapsedMilliseconds;

    final text = resp is TextResponse ? resp.token : resp.toString();
    return _parse(text, fallbackName: foodName);
  }

  AiEstimate _parse(String text, {required String fallbackName}) {
    var clean = text.trim();
    // Modelin sardığı ```json``` çitlerini at.
    if (clean.startsWith('```')) {
      clean = clean
          .replaceAll(RegExp(r'```[a-zA-Z]*'), '')
          .replaceAll('```', '')
          .trim();
    }
    // JSON öncesi/sonrası serbest metin kalırsa ilk { ... son } arasını al.
    final start = clean.indexOf('{');
    final end = clean.lastIndexOf('}');
    if (start >= 0 && end > start) {
      clean = clean.substring(start, end + 1);
    }
    try {
      final json = jsonDecode(clean) as Map<String, dynamic>;
      return AiEstimate(
        foodName: (json['food_name'] as String?)?.trim().isNotEmpty == true
            ? json['food_name'] as String
            : fallbackName,
        estimatedGrams: _num(json['estimated_grams']),
        calories: _num(json['calories']),
        protein: json['protein'] == null ? null : _num(json['protein']),
        carbs: json['carbs'] == null ? null : _num(json['carbs']),
        fat: json['fat'] == null ? null : _num(json['fat']),
        confidence: (json['confidence'] as String?) ?? 'low',
      );
    } catch (_) {
      throw GemmaException('Gemma yanıtı çözümlenemedi: $clean');
    }
  }

  double _num(dynamic v) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v.replaceAll(',', '.')) ?? 0;
    return 0;
  }

  Future<void> dispose() async {
    try {
      await _chat?.close();
    } catch (_) {}
    try {
      await _model?.close();
    } catch (_) {}
    _chat = null;
    _model = null;
    _used = false;
  }
}
