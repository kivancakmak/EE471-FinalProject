# Gemma On-Device (Edge LLM) — Kurulum ve Kıyas

Bu doküman, **AI Kam** ekranındaki 3. tahmin kaynağı olan **Gemma** (cihaz-içi LLM)
için model dosyasının telefona nasıl yükleneceğini ve Edge vs Cloud kıyasındaki
yerini anlatır.

## Mimari: Üç tahmin kaynağı

| Kaynak | Tür | Model | Boyut | İnternet | Donanım |
|---|---|---|---|---|---|
| **Bulut** | Cloud LLM | Gemini 2.5 Flash | — (sunucu) | Gerekir | — |
| **CNN** | Edge CNN | Food-101 TFLite (kendi eğitimimiz) | ~3.5 MB | Gerekmez | Orta telefon |
| **Gemma** | **Edge LLM** | CNN → Gemma 3 1B (LiteRT `.task`) | ~550 MB | Gerekmez | 4 GB+ RAM |

Üçü de aynı çıktı sözleşmesini (`AiEstimate`: yemek adı + gram + kalori + makrolar +
güven) döndürür → kıyas adildir.

## Edge LLM hattı: CNN → Gemma 1B

Telefonda fotoğrafı doğrudan multimodal bir LLM'e vermek yerine **iki aşamalı**
cihaz-içi hat kullanılır:

1. **Algı (CNN):** Kendi eğittiğimiz Food-101 TFLite sınıflandırıcısı fotoğraftaki
   yemeği tanır (~94 ms).
2. **Muhakeme (LLM):** Bulunan yemek adı **Gemma 3 1B**'ye (MediaPipe LiteRT) verilir;
   model o yemek için tipik porsiyon + kalori + protein/karb/yağ değerlerini metin
   muhakemesiyle üretir (~13.8 sn, CPU).

İkisi de offline çalışır. Kod: `lib/services/on_device_food_service.dart` (CNN) +
`lib/services/gemma_vision_service.dart` (Gemma).

### Neden multimodal Gemma 3n E2B değil?

Gemma 3n E2B (~3 GB, multimodal) fotoğrafı doğrudan işleyebilir, ama **8 GB+ RAM**
ister. 6 GB'lık bir telefonda (Redmi Note 10S) denendiğinde işletim sistemi
uygulamayı **yükleme anında öldürdü** (lowmemorykill — logcat: `has died ... low mem!`).
Bu somut bir bulgudur: *Edge LLM'in en güçlü hâli orta sınıf telefonda çalışmaz;
bu segmentte CNN algı + küçük LLM muhakeme hattı gerçekçi olandır.*

## 1) Model dosyasını edin

Gemma 3 1B'nin MediaPipe LiteRT `.task` sürümü gerekir (~550 MB):

- HuggingFace: `litert-community/Gemma3-1B-IT` → `gemma3-1b-it-int4.task`

> Düz `.gguf`/`.safetensors` **değil**, MediaPipe `.task` dosyası lazım.

## 2) Telefona adb push ile yükle

Model uygulamaya gömülmez; bir kez uygulamaya özel harici dizine atılır
(uygulama izinsiz okur):

```bash
adb push gemma3-1b-it-int4.task \
  /sdcard/Android/data/com.ee471.kalori_takip/files/gemma3-1b-it-int4.task
```

> Dizin uygulama ilk kez açıldığında oluşur. Yoksa önce uygulamayı bir kez çalıştır,
> sonra push et. Uygulama bu yolu `getExternalStorageDirectory` ile bulur.

Dosya yoksa **AI Kam → Gemma** sekmesi tam bu adb komutunu ekranda gösterir.

## 3) Kullan

AI Kam → kaynak seçici → **Gemma** → fotoğraf çek/seç. İlk çalıştırmada model
belleğe yüklenir. Sonuç kartında kaynak satırı gecikmeyi ve backend'i gösterir:
`CNN→Gemma 1B (cihaz) • 94+13767 ms • cpu`.

Yetersiz boş RAM'de uygulama, çökmeyi önlemek için yüklemeden önce `/proc/meminfo`'yu
kontrol eder ve net bir uyarı verir.

## Kıyas tablosu (ölçülen)

Redmi Note 10S (6 GB RAM), CPU backend:

| Metrik | Gemini (Cloud) | TFLite CNN (Edge, fp16) | CNN→Gemma 1B (Edge LLM) |
|---|---|---|---|
| Top-1 doğruluk | serbest | **%66.8** | ≤ %83.6 (top-3 tavanı) |
| Gecikme | ~1–3 sn (ağ) | **~0.1 sn** | **~13.8 sn** |
| Model boyutu | — | ~6 MB (fp16) | ~550 MB |
| Offline | ✗ | ✓ | ✓ |
| Gizlilik (foto cihazda) | ✗ | ✓ | ✓ |
| Makro üretir | ✓ | ✗ | ✓ |
| Yemek kapsamı | serbest | 101 sınıf | 101 sınıf (CNN) + LLM bilgisi |
| Maliyet | API kotası | yok | yok |
| Min. donanım | düşük | orta | 4 GB+ RAM |

> int8 sürümü MobileNetV3'te %8'e düştüğü için fp16 tercih edildi (bkz. ana README).

> Doğruluk kıyası için Food-101 test setinden örneklerle `evaluate_vs_gemini.py`
> kullanılabilir (Faz 3).
