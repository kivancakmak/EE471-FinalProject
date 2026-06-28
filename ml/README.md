# NutriTrack — Edge ML (Faz 1–3)

Bu klasör, "fotoğraftan kalori" problemini **cihaz-içi (on-device) kendi modelimizle**
çözüp **Gemini (cloud)** ile kıyaslamak için gereken makine öğrenmesi pipeline'ını içerir.

## Yaklaşım

Tek bir RGB fotoğraftan mutlak kaloriyi sıfırdan regresyonla tahmin etmek zor bir
problemdir (porsiyon/hacim belirsiz). Bunun yerine **iki adımlı** çözüm:

1. **Sınıflandırma:** MobileNetV3Small (transfer learning) ile yemeği Food-101'in 101
   sınıfından birine ata.
2. **Kalori eşleme:** Tahmin edilen sınıfı `food101_calories.csv` ile `kcal/100g`'a çevir,
   porsiyon gramıyla çarp.

Çıktı, telefonda çalışacak **int8 TFLite** modelidir (~küçük, hızlı, internetsiz).

## Dosyalar

| Dosya | Açıklama |
|---|---|
| `train_food101.py` | Eğitim + int8/fp16 TFLite export |
| `food101_calories.csv` | sınıf → kcal/100g eşlemesi (yaklaşık, düzenlenebilir) |
| `predict.py` | Tek görselde TFLite'ı test et (akıl sağlığı kontrolü) |
| `evaluate_vs_gemini.py` | On-device TFLite vs Gemini kıyas tablosu (Faz 3) |
| `requirements.txt` | Python bağımlılıkları |

## Kurulum

> `tensorflow-datasets` KULLANILMIYOR (Colab'da protobuf çakışması yaratıyordu).
> Veri seti resmi tar'dan indiriliyor.

**Colab (önerilen, ücretsiz GPU):** Runtime → GPU seç. Repoyu klonla:
```python
!git clone https://github.com/kivancakmak/EE471-FinalProject.git
%cd EE471-FinalProject/ml
```

**Yerel:**
```bash
cd ml
python -m venv .venv && source .venv/bin/activate   # Windows: .venv\Scripts\activate
pip install -r requirements.txt
```

## 0) Veri setini indir (bir kez, ~5 GB)

```python
!wget -q --show-progress http://data.vision.ee.ethz.ch/cvl/food-101.tar.gz
!tar xzf food-101.tar.gz
```
Bu, `ml/food-101/` klasörünü oluşturur (images/ + meta/).

## 1) Eğitim (Faz 1)

```bash
python train_food101.py --epochs-head 3 --epochs-finetune 5
```
Hızlı deneme (küçük altküme, dakikalar):
```bash
python train_food101.py --subset 0.1 --epochs-head 1 --epochs-finetune 1
```
Çıktılar `out/` klasörüne yazılır:
- `food_classifier.tflite` (int8, telefon için)
- `food_classifier_fp16.tflite` (daha doğru)
- `labels.txt` (model çıktı sırasıyla sınıf adları)

> Ölçülen doğruluk (MobileNetV3Large, Food-101 test, 500 örnek): **fp16 %66.8 top-1
> / %83.6 top-3**. Tam-int8 sürümü MobileNetV3'ün kuantizasyon zorluğundan ~%8'e
> düşer; bu yüzden uygulama **fp16** kullanır.

## 2) Hızlı test

```bash
python predict.py --image ornek_yemek.jpg
```

## 3) Kıyaslama (Faz 3)

Üç-yönlü kıyas: **Edge CNN** vs **Edge LLM (CNN→Gemma)** vs **Cloud LLM (Gemini)**.
Paste-ready Colab adımları: **[COLAB_EVAL.md](COLAB_EVAL.md)**.

Sadece on-device CNN (top-1 + top-3 doğruluk + kalori MAE):
```bash
python evaluate_vs_gemini.py --samples 500 --data-dir food-101
```
Gemini ile birlikte (API anahtarı gerekir, sınırlı örnek önerilir):
```bash
export GEMINI_API_KEY=...        # Windows: set GEMINI_API_KEY=...
python evaluate_vs_gemini.py --samples 500 --with-gemini --gemini-samples 40 --data-dir food-101
```
Çıktı (`out/comparison.md`): top-1/top-3 doğruluk, kalori MAE, gecikme, model boyutu
içeren markdown tablo. **top-3 doğruluk = Edge LLM (Gemma) tanıma tavanı** (Gemma yemeği
CNN'in ilk 3 adayından seçer). Rapora doğrudan eklenebilir.

## Telefona gömme (Faz 2 — sonraki adım)

`out/food_classifier.tflite` ve `labels.txt`, Flutter uygulamasında
`assets/models/` altına konup `tflite_flutter` ile yüklenecek; AI Kam ekranına
**Cloud (Gemini) / On-device (TFLite)** kaynak seçici eklenecek.

> Not: `food101_calories.csv` değerleri yaklaşıktır; raporun doğruluğu için
> referans bir besin tablosuyla (ör. USDA) güncellenebilir.
