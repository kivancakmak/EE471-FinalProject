import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/food.dart';
import '../providers/diary_provider.dart';
import '../providers/nav_provider.dart';
import '../repositories/food_log_repository.dart';
import '../services/off_service.dart';
import '../widgets/food_result_card.dart';
import '../widgets/log_food_sheet.dart';
import '../widgets/manual_entry_sheet.dart';

/// "Ekle" sekmesi: arama (Open Food Facts), son eklenenler ve manuel giriş.
class AddFoodScreen extends StatefulWidget {
  const AddFoodScreen({super.key});

  @override
  State<AddFoodScreen> createState() => _AddFoodScreenState();
}

class _AddFoodScreenState extends State<AddFoodScreen> {
  final _service = OffService();
  final _controller = TextEditingController();

  List<Food> _recent = [];
  List<Food> _results = [];
  bool _searching = false;
  bool _loading = false;
  String? _error;
  int _filter = 0; // 0=Son, 1=Sık, 2=Yemeklerim, 3=Öğünler (görsel)

  static const _filters = ['Son', 'Sık', 'Yemeklerim', 'Öğünler'];

  @override
  void initState() {
    super.initState();
    _loadRecent();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadRecent() async {
    final repo = context.read<FoodLogRepository>();
    final entries = await repo.recentDistinctEntries(15);
    if (mounted) {
      setState(() => _recent = entries.map(Food.fromEntry).toList());
    }
  }

  Future<void> _search() async {
    final q = _controller.text.trim();
    if (q.isEmpty) {
      setState(() => _searching = false);
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _searching = true;
      _error = null;
    });
    try {
      final results = await _service.search(q);
      if (mounted) setState(() => _results = results);
    } catch (_) {
      if (mounted) {
        setState(() => _error =
            'Arama başarısız. İnternet bağlantını kontrol et veya manuel ekle.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String get _date => context.read<DiaryProvider>().selectedDate;

  Future<void> _addFood(Food food) async {
    final added = await showLogFoodSheet(context, food: food, date: _date);
    if (added == true && mounted) {
      await _loadRecent();
      if (mounted) context.read<NavProvider>().go(0);
    }
  }

  Future<void> _manualEntry() async {
    final added = await showManualEntrySheet(context, date: _date);
    if (added == true && mounted) {
      await _loadRecent();
      if (mounted) context.read<NavProvider>().go(0);
    }
  }

  void _comingSoon() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Barkod tarama yakında eklenecek')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ekle',
            style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _searchBar(),
            _filterChips(),
            const SizedBox(height: 8),
            Expanded(child: _body()),
            _bottomButtons(),
          ],
        ),
      ),
    );
  }

  Widget _searchBar() {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: TextField(
        controller: _controller,
        textInputAction: TextInputAction.search,
        onSubmitted: (_) => _search(),
        onChanged: (v) {
          if (v.trim().isEmpty && _searching) {
            setState(() => _searching = false);
          }
        },
        decoration: InputDecoration(
          hintText: 'Yemek veya marka ara...',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: IconButton(
            icon: Icon(Icons.qr_code_scanner, color: scheme.secondary),
            onPressed: _comingSoon,
          ),
        ),
      ),
    );
  }

  Widget _filterChips() {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _filters.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, i) => ChoiceChip(
          label: Text(_filters[i]),
          selected: _filter == i,
          showCheckmark: false,
          labelStyle: TextStyle(
            color: _filter == i
                ? Colors.white
                : Theme.of(context).textTheme.bodyMedium?.color,
            fontWeight: FontWeight.w500,
          ),
          onSelected: (_) {
            setState(() => _filter = i);
            if (i != 0) _comingSoonFilter();
          },
        ),
      ),
    );
  }

  void _comingSoonFilter() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Bu filtre yakında; şimdilik Son listesi')),
    );
  }

  Widget _body() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_searching) {
      if (_error != null) {
        return _message(Icons.wifi_off, _error!);
      }
      if (_results.isEmpty) {
        return _message(Icons.search_off,
            'Sonuç bulunamadı. Manuel Giriş ile ekleyebilirsin.');
      }
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        children: _results
            .map((f) => FoodResultCard(food: f, onAdd: () => _addFood(f)))
            .toList(),
      );
    }
    // Son Eklenenler
    if (_recent.isEmpty) {
      return _message(Icons.restaurant_menu,
          'Henüz kayıt yok. Ara veya Manuel Giriş yap.');
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text('Son Eklenenler',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold)),
        ),
        ..._recent
            .map((f) => FoodResultCard(food: f, onAdd: () => _addFood(f))),
      ],
    );
  }

  Widget _bottomButtons() {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Column(
          children: [
            FilledButton.icon(
              onPressed: _manualEntry,
              icon: const Icon(Icons.edit_note),
              label: const Text('Manuel Giriş'),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _comingSoon,
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text('Barkod Tara'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _message(IconData icon, String text) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: Theme.of(context).disabledColor),
            const SizedBox(height: 12),
            Text(text, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
