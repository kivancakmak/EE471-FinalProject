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

## AI Beslenme Koçu Backend

Beslenme Koçu internetsiz yerel planla çalışır. Daha çeşitli planlar üretmek
için ücretsiz Groq kotasını kullanan backend isteğe bağlı olarak çalıştırılabilir.
Groq API anahtarı mobil uygulamaya değil yalnızca backend `.env` dosyasına yazılır.

```powershell
cd backend
py -m venv .venv
.\.venv\Scripts\pip.exe install -r requirements.txt
Copy-Item .env.example .env
```

https://console.groq.com/keys adresinden ücretsiz anahtar oluşturup
`backend/.env` içindeki `GROQ_API_KEY` değerini değiştirin. Ardından:

```powershell
.\.venv\Scripts\python.exe -m uvicorn app.main:app --host 0.0.0.0 --port 8000
```

Android emülatöründe varsayılan backend adresi `http://10.0.2.2:8000`'dir.
Gerçek telefonda telefon ve bilgisayar aynı Wi-Fi ağında olmalı; uygulamadaki
**Ayarlar > Beslenme AI Backend** alanına bilgisayarın yerel IP adresi
(`http://192.168.x.x:8000` gibi) girilmelidir.

> Not: Kamera özelliğini test etmek için gerçek cihaz önerilir.

## Testler

```bash
flutter test
```

## CI, Lint, Test ve Versiyonlama

Bu proje GitHub Actions ile `main` branch'e push yapıldığında ve pull request açıldığında otomatik olarak lint ve test çalıştırır. CI pipeline'ı Flutter stable kurar, bağımlılıkları `flutter pub get` ile yükler, sonra aşağıdaki komutları çalıştırır.

Lint:

```bash
flutter analyze
```

Test:

```bash
flutter test
```

Versiyon `pubspec.yaml` içindeki `version` alanında Semantic Versioning formatında tutulur. Güncel versiyon `1.1.0+2` değeridir; `+2` Flutter build number değeridir.

Versiyon artırma:

```bash
dart run tool/bump_version.dart patch
dart run tool/bump_version.dart minor
dart run tool/bump_version.dart major
```

Release çıkarmak için önce versiyonu artırın, değişikliği commit'leyin, sonra `vX.Y.Z` formatında tag oluşturup push'layın:

```bash
git add pubspec.yaml
git commit -m "Bump version to 1.1.0"
git tag v1.1.0
git push origin main
git push origin v1.1.0
```

`vX.Y.Z` tag'i pushlandığında release workflow lint ve test çalıştırır; başarılı olursa GitHub Release oluşturur.

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
