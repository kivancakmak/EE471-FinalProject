import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/enums.dart';
import '../models/food.dart';
import '../models/food_entry.dart';
import '../providers/diary_provider.dart';
import 'meal_selector.dart';

/// Bir [Food] için miktar/birim/öğün toplayıp günlüğe ekleyen alt sayfa.
/// Eklenirse `true` döner. [date] hedef gün (YYYY-MM-DD).
Future<bool?> showLogFoodSheet(
  BuildContext context, {
  required Food food,
  required String date,
  MealType initialMeal = MealType.breakfast,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: _LogFoodForm(
          food: food, date: date, initialMeal: initialMeal),
    ),
  );
}

class _LogFoodForm extends StatefulWidget {
  final Food food;
  final String date;
  final MealType initialMeal;

  const _LogFoodForm({
    required this.food,
    required this.date,
    required this.initialMeal,
  });

  @override
  State<_LogFoodForm> createState() => _LogFoodFormState();
}

class _LogFoodFormState extends State<_LogFoodForm> {
  late MealType _meal = widget.initialMeal;
  ServingUnit _unit = ServingUnit.gram;
  final _qtyController = TextEditingController(text: '100');
  final _servingController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Porsiyon bilgisi varsa porsiyon birimini varsayılan yap.
    if (widget.food.servingGrams != null) {
      _unit = ServingUnit.portion;
      _qtyController.text = '1';
      _servingController.text = widget.food.servingGrams!.toStringAsFixed(0);
    } else {
      _servingController.text = '100';
    }
  }

  @override
  void dispose() {
    _qtyController.dispose();
    _servingController.dispose();
    super.dispose();
  }

  double get _quantity =>
      double.tryParse(_qtyController.text.replaceAll(',', '.')) ?? 0;

  double get _servingGrams =>
      double.tryParse(_servingController.text.replaceAll(',', '.')) ?? 100;

  /// Önizleme için geçici kayıt oluşturur.
  FoodEntry _buildEntry() {
    final food = _unit == ServingUnit.portion
        ? Food(
            name: widget.food.name,
            caloriesPer100: widget.food.caloriesPer100,
            proteinPer100: widget.food.proteinPer100,
            carbPer100: widget.food.carbPer100,
            fatPer100: widget.food.fatPer100,
            servingGrams: _servingGrams,
            source: widget.food.source,
            barcode: widget.food.barcode,
          )
        : widget.food;
    return FoodEntry.fromFood(
      food: food,
      quantity: _quantity,
      unit: _unit,
      mealType: _meal,
      date: widget.date,
    );
  }

  Future<void> _save() async {
    if (_quantity <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Geçerli bir miktar girin')),
      );
      return;
    }
    await context.read<DiaryProvider>().addEntry(_buildEntry());
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final preview = _buildEntry();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.food.name,
              style: Theme.of(context).textTheme.titleLarge,
              maxLines: 2,
              overflow: TextOverflow.ellipsis),
          Text('${widget.food.caloriesPer100.round()} kcal / 100 g',
              style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 16),

          // Öğün seçimi
          const Text('Öğün'),
          const SizedBox(height: 6),
          MealSelector(
            selected: _meal,
            onChanged: (m) => setState(() => _meal = m),
          ),
          const SizedBox(height: 16),

          // Birim seçimi
          const Text('Birim'),
          const SizedBox(height: 6),
          SegmentedButton<ServingUnit>(
            segments: const [
              ButtonSegment(
                  value: ServingUnit.portion, label: Text('Porsiyon')),
              ButtonSegment(value: ServingUnit.gram, label: Text('Gram')),
              ButtonSegment(
                  value: ServingUnit.milliliter, label: Text('ml')),
            ],
            selected: {_unit},
            onSelectionChanged: (s) => setState(() => _unit = s.first),
          ),
          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _qtyController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                  ],
                  decoration: InputDecoration(
                    labelText: 'Miktar',
                    suffixText: _unit.label,
                    border: const OutlineInputBorder(),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              if (_unit == ServingUnit.portion) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _servingController,
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                    ],
                    decoration: const InputDecoration(
                      labelText: '1 porsiyon',
                      suffixText: 'g',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),

          // Canlı kalori önizleme
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'Toplam: ${preview.calories.round()} kcal',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
            ),
          ),
          const SizedBox(height: 16),

          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.check),
              label: const Text('Günlüğe Ekle'),
            ),
          ),
        ],
      ),
    );
  }
}
