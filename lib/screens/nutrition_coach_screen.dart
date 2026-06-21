import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/food_entry.dart';
import '../models/nutrition_plan.dart';
import '../models/nutrition_profile.dart';
import '../providers/settings_provider.dart';
import '../repositories/food_log_repository.dart';
import '../services/cloud_nutrition_coach_service.dart';
import '../services/nutrition_planner_service.dart';
import '../utils/date_helpers.dart';

class NutritionCoachScreen extends StatefulWidget {
  const NutritionCoachScreen({super.key});

  @override
  State<NutritionCoachScreen> createState() => _NutritionCoachScreenState();
}

class _NutritionCoachScreenState extends State<NutritionCoachScreen> {
  static const _planner = NutritionPlannerService();
  final _cloudCoach = CloudNutritionCoachService();
  List<FoodEntry> _recentEntries = [];
  bool _loadingProgress = true;
  bool _generatingCloudPlan = false;
  WeeklyNutritionPlan? _cloudPlan;
  String? _cloudError;

  @override
  void initState() {
    super.initState();
    _loadProgress();
  }

  Future<void> _loadProgress() async {
    final end = DateTime.now();
    final start = end.subtract(const Duration(days: 6));
    final entries = await context.read<FoodLogRepository>().entriesBetween(
      DateHelpers.keyOf(start),
      DateHelpers.keyOf(end),
    );
    if (mounted) {
      setState(() {
        _recentEntries = entries;
        _loadingProgress = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final localPlan = _planner.createWeeklyPlan(settings.nutritionProfile);
    final plan = _cloudPlan ?? localPlan;
    final insight = _planner.reviewProgress(_recentEntries, plan.targets);

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Beslenme Koçu'),
          actions: [
            IconButton(
              onPressed: () => _editProfile(settings),
              icon: const Icon(Icons.tune),
              tooltip: 'Profili düzenle',
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Plan'),
              Tab(text: 'Alışveriş'),
              Tab(text: 'İlerleme'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _planTab(plan, localPlan, settings),
            _shoppingTab(plan),
            _progressTab(insight, plan.targets),
          ],
        ),
      ),
    );
  }

  Widget _planTab(
    WeeklyNutritionPlan plan,
    WeeklyNutritionPlan localPlan,
    SettingsProvider settings,
  ) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _targetCard(plan.targets, settings),
        const SizedBox(height: 12),
        _aiPlanCard(plan, localPlan, settings),
        const SizedBox(height: 16),
        Text(
          '7 Günlük Örnek Plan',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          'Porsiyonlar günlük hedefe göre ölçeklenmiştir. Sağlık durumun varsa profesyonel görüş al.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        for (final day in plan.days) ...[
          _dayCard(day),
          const SizedBox(height: 12),
        ],
      ],
    );
  }

  Widget _aiPlanCard(
    WeeklyNutritionPlan plan,
    WeeklyNutritionPlan localPlan,
    SettingsProvider settings,
  ) {
    final isCloud = _cloudPlan != null;
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isCloud ? Icons.cloud_done_outlined : Icons.phone_android,
                  color: scheme.secondary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isCloud ? 'Groq AI planı aktif' : 'Yerel örnek plan aktif',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              isCloud
                  ? 'Model: ${plan.source.replaceFirst('groq:', '')}'
                  : 'Ücretsiz ve internetsiz plan kullanılıyor. AI daha çeşitli bir plan üretebilir.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (_cloudError != null) ...[
              const SizedBox(height: 8),
              Text(
                'AI kullanılamadı: $_cloudError\nYerel plana geri dönüldü.',
                style: TextStyle(color: scheme.error, fontSize: 12),
              ),
            ],
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _generatingCloudPlan
                  ? null
                  : () => _generateCloudPlan(settings, localPlan),
              icon: _generatingCloudPlan
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.auto_awesome),
              label: Text(
                _generatingCloudPlan
                    ? 'AI planı hazırlanıyor...'
                    : isCloud
                    ? 'AI planını yenile'
                    : 'AI ile kişisel plan üret',
              ),
            ),
            if (isCloud) ...[
              const SizedBox(height: 4),
              TextButton(
                onPressed: () => setState(() {
                  _cloudPlan = null;
                  _cloudError = null;
                }),
                child: const Text('Yerel plana dön'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _generateCloudPlan(
    SettingsProvider settings,
    WeeklyNutritionPlan localPlan,
  ) async {
    setState(() {
      _generatingCloudPlan = true;
      _cloudError = null;
    });
    try {
      final plan = await _cloudCoach.createWeeklyPlan(
        backendUrl: settings.coachBackendUrl,
        profile: settings.nutritionProfile,
        targets: localPlan.targets,
      );
      if (!mounted) return;
      setState(() => _cloudPlan = plan);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _cloudPlan = null;
        _cloudError = error.toString();
      });
    } finally {
      if (mounted) setState(() => _generatingCloudPlan = false);
    }
  }

  Widget _targetCard(NutritionTargets targets, SettingsProvider settings) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: scheme.primary,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome, color: Colors.white),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Kişisel günlük hedefin',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Text(
                settings.nutritionGoal.label,
                style: const TextStyle(color: Colors.white70),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _targetChip('${targets.calories} kcal'),
              _targetChip('${targets.proteinGrams} g protein'),
              _targetChip('${targets.carbGrams} g karb.'),
              _targetChip('${targets.fatGrams} g yağ'),
              _targetChip('${targets.waterMl} ml su'),
            ],
          ),
          if (settings.calorieGoal != targets.calories) ...[
            const SizedBox(height: 14),
            TextButton.icon(
              onPressed: () async {
                await settings.setCalorieGoal(targets.calories);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Kalori hedefin ana sayfaya uygulandı'),
                    ),
                  );
                }
              },
              style: TextButton.styleFrom(foregroundColor: Colors.white),
              icon: const Icon(Icons.sync),
              label: const Text('Bu hedefi ana sayfada kullan'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _targetChip(String label) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.16),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(label, style: const TextStyle(color: Colors.white)),
  );

  Widget _dayCard(DailyMealPlan day) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: ExpansionTile(
        initiallyExpanded: day.dayLabel == 'Pazartesi',
        shape: const Border(),
        title: Row(
          children: [
            Expanded(
              child: Text(
                day.dayLabel,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            if (day.trainingDay)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: scheme.secondary.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'ANTRENMAN',
                  style: TextStyle(
                    color: scheme.secondary,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
        subtitle: Text(
          '${day.totalCalories} kcal • ${day.totalProtein} g protein',
        ),
        children: [
          for (final meal in day.meals)
            ListTile(
              dense: true,
              leading: CircleAvatar(
                backgroundColor: scheme.secondary.withValues(alpha: 0.12),
                child: Icon(Icons.restaurant, color: scheme.secondary),
              ),
              title: Text(meal.title),
              subtitle: Text(meal.description),
              trailing: Text(
                '${meal.calories}\nkcal',
                textAlign: TextAlign.right,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _shoppingTab(WeeklyNutritionPlan plan) {
    final checked = <String>{};
    return StatefulBuilder(
      builder: (context, setLocalState) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Haftalık Alışveriş Listesi',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            '${plan.shoppingList.length} farklı ürün',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          Card(
            child: Column(
              children: [
                for (final item in plan.shoppingList)
                  CheckboxListTile(
                    value: checked.contains(item),
                    title: Text(
                      item,
                      style: TextStyle(
                        decoration: checked.contains(item)
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                    ),
                    onChanged: (value) => setLocalState(() {
                      value == true ? checked.add(item) : checked.remove(item);
                    }),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _progressTab(ProgressInsight insight, NutritionTargets targets) {
    if (_loadingProgress) {
      return const Center(child: CircularProgressIndicator());
    }
    final scheme = Theme.of(context).colorScheme;
    return RefreshIndicator(
      onRefresh: _loadProgress,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: scheme.secondary.withValues(alpha: 0.13),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.insights, color: scheme.secondary, size: 32),
                const SizedBox(height: 12),
                Text(
                  insight.title,
                  style: const TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(insight.message),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _progressMetric(
                  'Kayıtlı gün',
                  '${insight.loggedDays}/7',
                  Icons.event,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _progressMetric(
                  'Ort. kalori',
                  '${insight.averageCalories}',
                  Icons.local_fire_department,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _progressMetric(
                  'Ort. protein',
                  '${insight.averageProtein} g',
                  Icons.fitness_center,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Hedef: ${targets.calories} kcal • ${targets.proteinGrams} g protein',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _progressMetric(String label, String value, IconData icon) => Card(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
      child: Column(
        children: [
          Icon(icon, size: 20),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    ),
  );

  Future<void> _editProfile(SettingsProvider settings) async {
    final age = TextEditingController(text: settings.age.toString());
    final height = TextEditingController(
      text: settings.heightCm.toStringAsFixed(0),
    );
    final weight = TextEditingController(
      text: settings.currentWeightKg.toStringAsFixed(1),
    );
    var sex = settings.sex;
    var activity = settings.activityLevel;
    var goal = settings.nutritionGoal;
    var trainingDays = settings.trainingDaysPerWeek;

    final result = await showModalBottomSheet<NutritionProfile>(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocalState) => Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            20,
            20,
            MediaQuery.viewInsetsOf(context).bottom + 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Beslenme Profili',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(child: _numberField(age, 'Yaş')),
                    const SizedBox(width: 10),
                    Expanded(child: _numberField(height, 'Boy (cm)')),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _numberField(weight, 'Kilo (kg)', decimal: true),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<BiologicalSex>(
                  initialValue: sex,
                  decoration: const InputDecoration(labelText: 'Cinsiyet'),
                  items: BiologicalSex.values
                      .map(
                        (value) => DropdownMenuItem(
                          value: value,
                          child: Text(value.label),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => setLocalState(() => sex = value ?? sex),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<ActivityLevel>(
                  initialValue: activity,
                  decoration: const InputDecoration(
                    labelText: 'Aktivite seviyesi',
                  ),
                  items: ActivityLevel.values
                      .map(
                        (value) => DropdownMenuItem(
                          value: value,
                          child: Text(value.label),
                        ),
                      )
                      .toList(),
                  onChanged: (value) =>
                      setLocalState(() => activity = value ?? activity),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<NutritionGoal>(
                  initialValue: goal,
                  decoration: const InputDecoration(labelText: 'Hedef'),
                  items: NutritionGoal.values
                      .map(
                        (value) => DropdownMenuItem(
                          value: value,
                          child: Text(value.label),
                        ),
                      )
                      .toList(),
                  onChanged: (value) =>
                      setLocalState(() => goal = value ?? goal),
                ),
                const SizedBox(height: 16),
                Text('Haftalık antrenman: $trainingDays gün'),
                Slider(
                  value: trainingDays.toDouble(),
                  min: 0,
                  max: 7,
                  divisions: 7,
                  label: '$trainingDays',
                  onChanged: (value) =>
                      setLocalState(() => trainingDays = value.round()),
                ),
                const SizedBox(height: 8),
                FilledButton(
                  onPressed: () {
                    final profile = NutritionProfile(
                      age: int.tryParse(age.text) ?? settings.age,
                      heightCm:
                          double.tryParse(height.text.replaceAll(',', '.')) ??
                          settings.heightCm,
                      weightKg:
                          double.tryParse(weight.text.replaceAll(',', '.')) ??
                          settings.currentWeightKg,
                      sex: sex,
                      activityLevel: activity,
                      goal: goal,
                      trainingDaysPerWeek: trainingDays,
                    );
                    Navigator.pop(context, profile);
                  },
                  child: const Text('Profili Kaydet'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (result != null) {
      await settings.setNutritionProfile(result);
      if (mounted) {
        setState(() {
          _cloudPlan = null;
          _cloudError = null;
        });
      }
    }
  }

  Widget _numberField(
    TextEditingController controller,
    String label, {
    bool decimal = false,
  }) => TextField(
    controller: controller,
    keyboardType: TextInputType.numberWithOptions(decimal: decimal),
    inputFormatters: [
      FilteringTextInputFormatter.allow(
        RegExp(decimal ? r'[0-9.,]' : r'[0-9]'),
      ),
    ],
    decoration: InputDecoration(labelText: label),
  );
}
