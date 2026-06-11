import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/food.dart';

/// Open Food Facts üzerinde yemek/ürün araması yapar (anahtar gerektirmez).
class OffService {
  static const _host = 'world.openfoodfacts.org';

  final http.Client _client;

  OffService({http.Client? client}) : _client = client ?? http.Client();

  /// [query] için ürünleri arar. Kalori bilgisi olmayanlar elenir.
  Future<List<Food>> search(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return [];

    final uri = Uri.https(_host, '/cgi/search.pl', {
      'search_terms': trimmed,
      'search_simple': '1',
      'action': 'process',
      'json': '1',
      'page_size': '25',
      'fields':
          'product_name,nutriments,serving_quantity,serving_size,code',
    });

    final res = await _client.get(
      uri,
      headers: {'User-Agent': 'KaloriTakip/1.0 (EE471 final project)'},
    ).timeout(const Duration(seconds: 15));

    if (res.statusCode != 200) {
      throw Exception('Open Food Facts hatası: ${res.statusCode}');
    }

    final data = jsonDecode(utf8.decode(res.bodyBytes));
    final products = (data['products'] as List?) ?? const [];

    final foods = <Food>[];
    final seen = <String>{};
    for (final p in products) {
      if (p is! Map<String, dynamic>) continue;
      final food = Food.fromOffProduct(p);
      if (food == null) continue;
      // Aynı isimli tekrarları ele.
      final key = food.name.toLowerCase();
      if (seen.add(key)) foods.add(food);
    }
    return foods;
  }
}
