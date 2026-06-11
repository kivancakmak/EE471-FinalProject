import 'package:flutter/material.dart';

import '../models/enums.dart';

/// Öğün tipi seçimi (Kahvaltı/Öğle/Akşam/Atıştırmalık) için çip grubu.
/// Seçili olmayan çipler de net görünür (hafif yeşil zemin + kenarlık).
class MealSelector extends StatelessWidget {
  final MealType selected;
  final ValueChanged<MealType> onChanged;

  const MealSelector({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: MealType.values.map((m) {
        final isSel = selected == m;
        return ChoiceChip(
          label: Text(m.label),
          selected: isSel,
          showCheckmark: false,
          backgroundColor: scheme.secondary.withValues(alpha: 0.12),
          selectedColor: scheme.secondary,
          side: BorderSide(
            color: isSel ? Colors.transparent : scheme.outlineVariant,
          ),
          labelStyle: TextStyle(
            color: isSel ? scheme.onSecondary : scheme.onSurface,
            fontWeight: FontWeight.w600,
          ),
          onSelected: (_) => onChanged(m),
        );
      }).toList(),
    );
  }
}
