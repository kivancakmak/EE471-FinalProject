import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../models/enums.dart';
import '../models/food_entry.dart';
import '../providers/diary_provider.dart';
import '../providers/nav_provider.dart';
import '../providers/settings_provider.dart';
import '../services/gemini_service.dart';
import '../widgets/meal_selector.dart';

/// "AI Kam" sekmesi: fotoğraftan Gemini ile kalori tahmini.
class CameraEstimateScreen extends StatefulWidget {
  const CameraEstimateScreen({super.key});

  @override
  State<CameraEstimateScreen> createState() => _CameraEstimateScreenState();
}

class _CameraEstimateScreenState extends State<CameraEstimateScreen> {
  final _picker = ImagePicker();
  final _gemini = GeminiService();

  File? _image;
  bool _loading = false;
  int _retryAttempt = 0;
  String? _error;
  AiEstimate? _estimate;

  // Düzenlenebilir taban değerler (1 porsiyon için).
  String _name = '';
  double _baseGrams = 0;
  double _baseCalories = 0;
  double? _baseProtein;
  double? _baseCarbs;
  double? _baseFat;

  // Porsiyon çarpanı: Normal=1, Büyük=1.5, Küçük=0.6
  int _portion = 0;
  static const _portionLabels = ['Normal', 'Büyük', 'Küçük'];
  static const _portionFactors = [1.0, 1.5, 0.6];
  double get _factor => _portionFactors[_portion];

  MealType _meal = MealType.lunch;

  void _reset() {
    setState(() {
      _image = null;
      _estimate = null;
      _error = null;
      _portion = 0;
    });
  }

  Future<void> _pick(ImageSource source) async {
    final picked = await _picker.pickImage(
        source: source, maxWidth: 1024, imageQuality: 85);
    if (picked == null) return;
    if (!mounted) return;
    setState(() {
      _image = File(picked.path);
      _estimate = null;
      _error = null;
    });

    final apiKey = context.read<SettingsProvider>().geminiApiKey;
    if (apiKey.trim().isEmpty) {
      setState(() => _error = 'no_key');
      return;
    }
    setState(() {
      _loading = true;
      _retryAttempt = 0;
    });
    try {
      final est = await _gemini.estimateFromImage(
        imageBytes: await picked.readAsBytes(),
        mimeType: picked.mimeType ?? 'image/jpeg',
        apiKey: apiKey,
        onRetry: (attempt) {
          if (mounted) setState(() => _retryAttempt = attempt);
        },
      );
      setState(() {
        _estimate = est;
        _name = est.foodName;
        _baseGrams = est.estimatedGrams > 0 ? est.estimatedGrams : 100;
        _baseCalories = est.calories;
        _baseProtein = est.protein;
        _baseCarbs = est.carbs;
        _baseFat = est.fat;
      });
    } on GeminiException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = 'Beklenmeyen hata: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    final grams = _baseGrams * _factor;
    final cal = _baseCalories * _factor;
    if (_name.trim().isEmpty || cal <= 0 || grams <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Değerleri kontrol et')),
      );
      return;
    }
    double? per100(double? v) => v == null ? null : v * _factor * 100 / grams;

    final entry = FoodEntry(
      foodName: _name.trim(),
      caloriesPer100: cal * 100 / grams,
      servingGrams: grams,
      quantity: 1,
      unit: ServingUnit.portion,
      mealType: _meal,
      proteinPer100: per100(_baseProtein),
      carbPer100: per100(_baseCarbs),
      fatPer100: per100(_baseFat),
      date: context.read<DiaryProvider>().selectedDate,
      source: FoodSource.ai,
      createdAt: DateTime.now(),
    );
    await context.read<DiaryProvider>().addEntry(entry);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${entry.foodName} günlüğe eklendi')),
    );
    _reset();
    context.read<NavProvider>().go(0);
  }

  Future<void> _editDialog() async {
    final nameC = TextEditingController(text: _name);
    final gramC = TextEditingController(text: _baseGrams.toStringAsFixed(0));
    final calC = TextEditingController(text: _baseCalories.toStringAsFixed(0));
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Düzenle'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
                controller: nameC,
                decoration: const InputDecoration(labelText: 'Yemek adı')),
            const SizedBox(height: 8),
            TextField(
                controller: gramC,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))
                ],
                decoration: const InputDecoration(
                    labelText: 'Porsiyon (g)')),
            const SizedBox(height: 8),
            TextField(
                controller: calC,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))
                ],
                decoration:
                    const InputDecoration(labelText: 'Kalori (kcal)')),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('İptal')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Tamam')),
        ],
      ),
    );
    if (ok == true) {
      setState(() {
        _name = nameC.text.trim();
        _baseGrams =
            double.tryParse(gramC.text.replaceAll(',', '.')) ?? _baseGrams;
        _baseCalories =
            double.tryParse(calC.text.replaceAll(',', '.')) ?? _baseCalories;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Kam',
            style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _imageArea(),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed:
                        _loading ? null : () => _pick(ImageSource.camera),
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('Çek'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed:
                        _loading ? null : () => _pick(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library),
                    label: const Text('Galeri'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_loading) _loadingCard(),
            if (_error != null && !_loading) _errorCard(),
            if (_estimate != null && !_loading) _resultCard(),
          ],
        ),
      ),
    );
  }

  Widget _imageArea() {
    if (_image == null) {
      return Container(
        height: 220,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.add_a_photo,
                  size: 48, color: Theme.of(context).colorScheme.secondary),
              const SizedBox(height: 8),
              const Text('Yemeğin fotoğrafını çek veya galeriden seç'),
            ],
          ),
        ),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Image.file(_image!,
          height: 240, width: double.infinity, fit: BoxFit.cover),
    );
  }

  Widget _loadingCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 14),
            Text(_retryAttempt > 0
                ? 'Sunucu yoğun, tekrar deneniyor... ($_retryAttempt)'
                : 'Yapay zeka fotoğrafı inceliyor...'),
          ],
        ),
      ),
    );
  }

  Widget _errorCard() {
    final scheme = Theme.of(context).colorScheme;
    if (_error == 'no_key') {
      return Card(
        color: scheme.errorContainer,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const Text(
                'Bu özellik için Gemini API anahtarı gerekli. '
                'Ücretsiz anahtarı Google AI Studio\'dan alabilirsin.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () => context.read<NavProvider>().go(4),
                icon: const Icon(Icons.key),
                label: const Text('Ayarlara Git'),
              ),
            ],
          ),
        ),
      );
    }
    return Card(
      color: scheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(_error!, textAlign: TextAlign.center),
      ),
    );
  }

  Widget _resultCard() {
    final scheme = Theme.of(context).colorScheme;
    final cal = (_baseCalories * _factor).round();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _ConfidenceBadge(level: _estimate!.confidence),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: _editDialog,
                  tooltip: 'Düzenle',
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(_name,
                style: const TextStyle(
                    fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            // Büyük kalori + makrolar
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    flex: 5,
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: scheme.secondary.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('$cal',
                              style: TextStyle(
                                  fontSize: 40,
                                  fontWeight: FontWeight.bold,
                                  color: scheme.primary)),
                          const Text('Tahmini Kalori',
                              style: TextStyle(fontSize: 13)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 5,
                    child: Column(
                      children: [
                        _macroRow('Protein', _baseProtein),
                        const SizedBox(height: 8),
                        _macroRow('Karb.', _baseCarbs),
                        const SizedBox(height: 8),
                        _macroRow('Yağ', _baseFat),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Porsiyon segmenti
            SegmentedButton<int>(
              segments: [
                for (var i = 0; i < _portionLabels.length; i++)
                  ButtonSegment(value: i, label: Text(_portionLabels[i])),
              ],
              selected: {_portion},
              onSelectionChanged: (s) => setState(() => _portion = s.first),
            ),
            const SizedBox(height: 12),
            const Text('Öğün'),
            const SizedBox(height: 6),
            MealSelector(
              selected: _meal,
              onChanged: (m) => setState(() => _meal = m),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.check_circle_outline),
              label: const Text('Onayla ve Ekle'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _macroRow(String label, double? base) {
    final scheme = Theme.of(context).colorScheme;
    final value = base == null ? '—' : '${(base * _factor).round()}g';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

class _ConfidenceBadge extends StatelessWidget {
  final String level;
  const _ConfidenceBadge({required this.level});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (level) {
      'high' => ('Eşleşme • Yüksek', Colors.green),
      'medium' => ('Eşleşme • Orta', Colors.orange),
      _ => ('Eşleşme • Düşük', Colors.redAccent),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle, size: 16, color: color),
          const SizedBox(width: 6),
          Text(label,
              style: TextStyle(
                  fontSize: 12,
                  color: color,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
