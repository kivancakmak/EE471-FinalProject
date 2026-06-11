import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/enums.dart';
import '../models/food_entry.dart';
import '../providers/diary_provider.dart';
import 'meal_selector.dart';

/// Yemek adı + kalori + öğün ile elle kayıt ekleyen alt sayfa.
Future<bool?> showManualEntrySheet(BuildContext context,
    {required String date}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: _ManualForm(date: date),
    ),
  );
}

class _ManualForm extends StatefulWidget {
  final String date;
  const _ManualForm({required this.date});

  @override
  State<_ManualForm> createState() => _ManualFormState();
}

class _ManualFormState extends State<_ManualForm> {
  final _nameController = TextEditingController();
  final _calController = TextEditingController();
  MealType _meal = MealType.breakfast;

  @override
  void dispose() {
    _nameController.dispose();
    _calController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    final cal = double.tryParse(_calController.text.replaceAll(',', '.'));
    if (name.isEmpty || cal == null || cal <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Yemek adı ve geçerli kalori girin')),
      );
      return;
    }
    final entry = FoodEntry(
      foodName: name,
      caloriesPer100: cal,
      servingGrams: 100,
      quantity: 1,
      unit: ServingUnit.portion,
      mealType: _meal,
      date: widget.date,
      source: FoodSource.manual,
      createdAt: DateTime.now(),
    );
    await context.read<DiaryProvider>().addEntry(entry);
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Manuel Giriş',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(labelText: 'Yemek adı'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _calController,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
            ],
            decoration: const InputDecoration(
                labelText: 'Kalori', suffixText: 'kcal'),
          ),
          const SizedBox(height: 16),
          const Text('Öğün'),
          const SizedBox(height: 6),
          MealSelector(
            selected: _meal,
            onChanged: (m) => setState(() => _meal = m),
          ),
          const SizedBox(height: 20),
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
