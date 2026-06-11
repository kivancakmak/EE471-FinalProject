# Kalori Takip

Günlük kalori alımını takip etmek için Flutter ile geliştirilmiş bir Android uygulaması (EE471 final projesi).

## Özellikler

- **Öğün ekleme:** Open Food Facts veritabanında yemek arama; porsiyon / gram / ml seçimiyle otomatik kalori hesabı.
- **Manuel ekleme:** Yemek adı ve kalorisini elle girme.
- **Günlük takip:** Öğünlere göre (kahvaltı/öğle/akşam/atıştırmalık) gruplama, dairesel ilerleme halkası, hedefe göre kalan/aşan kalori, makro (protein/karb/yağ) toplamları.
- **AI ile fotoğraftan kalori:** Kamerayla çekilen veya galeriden seçilen yemeğin fotoğrafını Gemini'ye gönderip tahmini kaloriyi alma; değerleri düzeltip günlüğe ekleme.
- **Geçmiş:** Son 7 günün grafiği ve tüm günlerin toplamları.
- **Yerel saklama:** Veriler cihazda SQLite ile tutulur (hesap/internet gerektirmez; arama ve AI için internet gerekir).

## Kurulum

```bash
flutter pub get
```

### Gemini API anahtarı (AI özelliği için)

Fotoğraftan kalori tahmini için ücretsiz bir Gemini API anahtarı gerekir:

1. https://aistudio.google.com/app/apikey adresinden anahtar alın.
2. Aşağıdakilerden **birini** yapın:
   - Proje kökündeki `.env` dosyasına `GEMINI_API_KEY=anahtarınız` yazın, **veya**
   - Uygulamayı açıp **Ayarlar** ekranından anahtarı girin.

> `.env` dosyası `.gitignore` ile sürüm kontrolünden hariç tutulmuştur; anahtarınız paylaşılmaz.

## Çalıştırma

Bir Android cihaz bağlayın veya emülatör başlatın, sonra:

```bash
flutter run
```

> Not: Kamera özelliğini test etmek için gerçek cihaz önerilir.

## Testler

```bash
flutter test
```

## Proje Yapısı

```
lib/
  models/        # Food, FoodEntry, DailySummary, enums
  services/      # database_service, off_service (Open Food Facts), gemini_service
  repositories/  # food_log_repository (yerel; bulut için soyutlanmış)
  providers/     # diary_provider, settings_provider (Provider/ChangeNotifier)
  screens/       # home, add_food, camera_estimate, history, settings
  widgets/       # calorie_ring, meal_section, food_entry_tile, log_food_sheet
  utils/         # date_helpers
```

## Sonraki Adımlar (planlanan)

- Bulut + hesap (Firebase) — repository katmanı buna hazır.
- Barkod tarayıcı, su takibi, kilo grafiği, makro hedefleri.
