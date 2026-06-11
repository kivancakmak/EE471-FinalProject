import 'enums.dart';
import 'food_entry.dart';

/// Bir besin/ürün tanımı (henüz günlüğe eklenmemiş arama sonucu veya tahmin).
///
/// Kalori değeri 100 g/ml başına tutulur. `servingGrams` varsa "1 porsiyon"un
/// kaç grama denk geldiğini belirtir (Open Food Facts `serving_quantity`).
class Food {
  final String name;
  final double caloriesPer100;
  final double? proteinPer100;
  final double? carbPer100;
  final double? fatPer100;

  /// 1 porsiyonun gram karşılığı. Bilinmiyorsa null.
  final double? servingGrams;

  final FoodSource source;
  final String? barcode;

  const Food({
    required this.name,
    required this.caloriesPer100,
    this.proteinPer100,
    this.carbPer100,
    this.fatPer100,
    this.servingGrams,
    this.source = FoodSource.manual,
    this.barcode,
  });

  /// Daha önce eklenmiş bir kayıttan tekrar eklenebilir besin üretir.
  factory Food.fromEntry(FoodEntry e) => Food(
        name: e.foodName,
        caloriesPer100: e.caloriesPer100,
        proteinPer100: e.proteinPer100,
        carbPer100: e.carbPer100,
        fatPer100: e.fatPer100,
        servingGrams: e.servingGrams,
        source: e.source,
      );

  /// Open Food Facts arama yanıtındaki tek bir ürünü modele çevirir.
  /// Kalori bilgisi yoksa null döner.
  static Food? fromOffProduct(Map<String, dynamic> json) {
    final nutriments = json['nutriments'];
    if (nutriments is! Map) return null;

    final kcal = _toDouble(nutriments['energy-kcal_100g']);
    if (kcal == null || kcal <= 0) return null;

    final name = (json['product_name'] as String?)?.trim();
    if (name == null || name.isEmpty) return null;

    return Food(
      name: name,
      caloriesPer100: kcal,
      proteinPer100: _toDouble(nutriments['proteins_100g']),
      carbPer100: _toDouble(nutriments['carbohydrates_100g']),
      fatPer100: _toDouble(nutriments['fat_100g']),
      servingGrams: _toDouble(json['serving_quantity']),
      source: FoodSource.off,
      barcode: json['code'] as String?,
    );
  }

  static double? _toDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v.replaceAll(',', '.'));
    return null;
  }
}
