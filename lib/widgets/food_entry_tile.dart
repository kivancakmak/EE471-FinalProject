import 'package:flutter/material.dart';

import '../models/food_entry.dart';

/// Öğün kartı içinde tek bir kaydı gösterir; sola kaydırınca silinir.
class FoodEntryTile extends StatelessWidget {
  final FoodEntry entry;
  final VoidCallback onDelete;

  const FoodEntryTile({
    super.key,
    required this.entry,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final qty = entry.quantity;
    final qtyText =
        qty == qty.roundToDouble() ? qty.round().toString() : qty.toString();
    final muted = Theme.of(context).textTheme.bodySmall?.color;

    return Dismissible(
      key: ValueKey(entry.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 8),
        child: Icon(Icons.delete_outline,
            color: Theme.of(context).colorScheme.error),
      ),
      onDismissed: (_) => onDelete(),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(entry.foodName,
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w500),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
            const SizedBox(height: 2),
            Text(
              '$qtyText ${entry.unit.label} • ${entry.calories.round()} kcal',
              style: TextStyle(fontSize: 13, color: muted),
            ),
          ],
        ),
      ),
    );
  }
}
