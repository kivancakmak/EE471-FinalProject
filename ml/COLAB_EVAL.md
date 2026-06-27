# Faz 3 — Kıyas Tablosunu Colab'de Üretme

Doğruluk ölçümü için Food-101 **test** görselleri gerekir (~5 GB). Bunlar eğitimi
yaptığın Colab ortamında zaten indirilebilir. Aşağıdaki hücreleri sırayla çalıştır;
sonunda `out/comparison.md` rapora hazır tabloyu üretir.

> Çıktı tablosu üç sütunludur: **Edge CNN** (top-1/top-3 doğruluk + kalori MAE),
> **Edge LLM (Gemma)** (tanıma tavanı = top-3) ve **Cloud LLM (Gemini)** (kalori MAE).

## 1) Repo + model + bağımlılıklar

```python
!pip -q install pillow numpy tensorflow
!git clone https://github.com/kivancakmak/EE471-FinalProject.git
%cd EE471-FinalProject/ml
# Uygulamaya gömülü eğitilmiş modeli değerlendirme için out/'a kopyala
!mkdir -p out
!cp ../assets/models/food_classifier.tflite out/
!cp ../assets/models/labels.txt out/
```

## 2) Food-101 test setini indir (~5 GB, birkaç dk)

```python
!wget -q --show-progress http://data.vision.ee.ethz.ch/cvl/food-101.tar.gz
!tar xzf food-101.tar.gz   # food-101/images + food-101/meta
```

## 3a) Sadece Edge CNN (hızlı, internet/anahtar gerektirmez)

```python
!python evaluate_vs_gemini.py --samples 500 --data-dir food-101
```

Bu; top-1 doğruluk, top-3 doğruluk (Gemma tavanı) ve CNN kalori MAE'yi verir.

## 3b) Gemini ile birlikte (kalori MAE kıyası için)

Gemini her örnek için API çağrısı yapar (kota harcar). Küçük tut:

```python
import os
os.environ["GEMINI_API_KEY"] = "BURAYA_ANAHTARINI_YAZ"  # AI Studio anahtarı
!python evaluate_vs_gemini.py --samples 500 --with-gemini --gemini-samples 40 --data-dir food-101
```

## 4) Sonucu al

```python
print(open("out/comparison.md", encoding="utf-8").read())
```

Üretilen `out/comparison.md` içeriğini doğrudan rapora / slayta yapıştırabilirsin.
Gecikme sütunundaki CNN değeri masaüstü/Colab CPU'sundadır; **telefon** ölçümleri
(CNN ~94 ms, Gemma ~13.8 sn) [GEMMA_3N_SETUP.md](GEMMA_3N_SETUP.md) ve README'dedir.

---

### Notlar
- `--samples` arttıkça doğruluk daha güvenilir olur (500–1000 iyi).
- Gemini'yi az tut (`--gemini-samples 30–50`) — kota ve süre için.
- Top-3 tavanı, "doğru sınıf ilk 3'teyse Gemma kurtarabilir" payını gösterir;
  Edge LLM'in tek başına bağımsız görüşü yoktur (CNN adaylarına dayanır).
