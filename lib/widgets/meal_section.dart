import 'package:flutter/material.dart';

import '../models/daily_summary.dart';
import '../models/enums.dart';
import '../models/food_entry.dart';
import 'food_entry_tile.dart';

/// Bir öğün için kart: başlık (ikon + ad + toplam/EKLE) ve kayıtlar.
class MealSection extends StatelessWidget {
  final MealType meal;
  final DailySummary summary;
  final void Function(FoodEntry) onDelete;
  final VoidCallback onAdd;

  const MealSection({
    super.key,
    required this.meal,
    required this.summary,
    required this.onDelete,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final entries = summary.entriesFor(meal);
    final total = summary.caloriesFor(meal);
    final hasEntries = entries.isNotEmpty;

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 12, 16, hasEntries ? 8 : 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(meal.icon, color: scheme.secondary, size: 22),
                const SizedBox(width: 10),
                Text(meal.label,
                    style: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w600)),
                const Spacer(),
                if (hasEntries)
                  Text('${total.round()} kcal',
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.bold))
                else
                  InkWell(
                    onTap: onAdd,
                    child: Row(
                      children: [
                        Text('EKLE',
                            style: TextStyle(
                                color: scheme.secondary,
                                fontWeight: FontWeight.w600,
                                fontSize: 13)),
                        const SizedBox(width: 4),
                        Icon(Icons.add_circle_outline,
                            color: scheme.secondary, size: 20),
                      ],
                    ),
                  ),
              ],
            ),
            if (hasEntries) ...[
              const SizedBox(height: 4),
              const Divider(),
              for (var i = 0; i < entries.length; i++) ...[
                FoodEntryTile(
                    entry: entries[i], onDelete: () => onDelete(entries[i])),
                if (i < entries.length - 1) const Divider(),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
