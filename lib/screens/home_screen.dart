import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/daily_summary.dart';
import '../models/enums.dart';
import '../providers/diary_provider.dart';
import '../providers/nav_provider.dart';
import '../providers/settings_provider.dart';
import '../utils/date_helpers.dart';
import '../widgets/app_header.dart';
import '../widgets/calorie_ring.dart';
import '../widgets/macro_card.dart';
import '../widgets/meal_section.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final diary = context.watch<DiaryProvider>();
    final settings = context.watch<SettingsProvider>();
    final summary = diary.summary;
    final eaten = summary.totalCalories;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: () => diary.loadDate(diary.selectedDate),
          child: ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              const AppHeader(),
              if (!diary.isViewingToday) _DateBanner(diary: diary),
              const SizedBox(height: 4),
              _CalorieCard(eaten: eaten, goal: settings.calorieGoal),
              const SizedBox(height: 14),
              _MacroRow(summary: summary, settings: settings),
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text("Bugünkü Öğünler",
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: MealType.values
                      .map((meal) => MealSection(
                            meal: meal,
                            summary: summary,
                            onAdd: () => context.read<NavProvider>().go(2),
                            onDelete: (entry) async {
                              await diary.deleteEntry(entry);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                      content:
                                          Text('${entry.foodName} silindi')),
                                );
                              }
                            },
                          ))
                      .toList(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CalorieCard extends StatelessWidget {
  final double eaten;
  final int goal;

  const _CalorieCard({required this.eaten, required this.goal});

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).textTheme.bodySmall?.color;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
          child: Column(
            children: [
              CalorieRing(consumed: eaten, goal: goal),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _stat(context, Icons.local_fire_department_outlined,
                      '$goal Hedef', muted),
                  Container(
                      width: 1,
                      height: 20,
                      color: muted?.withValues(alpha: 0.2)),
                  _stat(context, Icons.restaurant_outlined,
                      '${eaten.round()} Yenen', muted),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _stat(
      BuildContext context, IconData icon, String text, Color? muted) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: muted),
        const SizedBox(width: 6),
        Text(text,
            style: const TextStyle(
                fontSize: 14, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class _MacroRow extends StatelessWidget {
  final DailySummary summary;
  final SettingsProvider settings;

  const _MacroRow({required this.summary, required this.settings});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: MacroCard(
                label: 'Protein',
                consumed: summary.totalProtein,
                goal: settings.proteinGoal),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: MacroCard(
                label: 'Karb.',
                consumed: summary.totalCarb,
                goal: settings.carbGoal),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: MacroCard(
                label: 'Yağ',
                consumed: summary.totalFat,
                goal: settings.fatGoal),
          ),
        ],
      ),
    );
  }
}

class _DateBanner extends StatelessWidget {
  final DiaryProvider diary;

  const _DateBanner({required this.diary});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: scheme.secondary.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(Icons.event, size: 18, color: scheme.secondary),
            const SizedBox(width: 8),
            Expanded(
                child: Text(DateHelpers.displayOfKey(diary.selectedDate))),
            TextButton(
              onPressed: () => diary.loadDate(DateHelpers.today()),
              child: const Text('Bugüne dön'),
            ),
          ],
        ),
      ),
    );
  }
}
