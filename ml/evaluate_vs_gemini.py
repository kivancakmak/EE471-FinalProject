"""
Faz 3 — Edge (TFLite CNN + Gemma) vs Cloud (Gemini) kıyas harness'ı.

Food-101 TEST setinden örnekler alır; CNN için top-1 ve top-3 doğruluğu
(top-3 = Edge LLM/Gemma'nın tanıma tavanı) ile kalori MAE'sini ölçer, isteğe
bağlı olarak Gemini'nin kalori MAE'siyle kıyaslar. Çıktı: out/comparison.md.

Veri seti Colab'de indirilir; adım adım: COLAB_EVAL.md.

Kullanım:
    python evaluate_vs_gemini.py --samples 500 --data-dir food-101
    GEMINI_API_KEY=... python evaluate_vs_gemini.py --samples 500 \
        --with-gemini --gemini-samples 40 --data-dir food-101
"""

import argparse
import base64
import csv
import json
import os
import random
import time
import urllib.error
import urllib.request

import numpy as np
import tensorflow as tf
from PIL import Image

from food101_data import list_split

IMG_SIZE = 224
GEMINI_MODEL = "gemini-2.5-flash"


def load_calories(path):
    cal = {}
    with open(path, encoding="utf-8") as f:
        for row in csv.DictReader(f):
            cal[row["label"]] = float(row["kcal_per_100g"])
    return cal


def tflite_predict(interp, inp, out, image_uint8):
    """(top1_idx, top3_idx_list, latency_ms) döndürür."""
    # Modelin beklediği girdi tipine çevir: int8 model uint8 (0..255) bekler,
    # fp16/float model float32 (0..255) bekler — ölçekleme model içinde yapılır.
    x = np.expand_dims(image_uint8, 0).astype(inp["dtype"])
    interp.set_tensor(inp["index"], x)
    t0 = time.perf_counter()
    interp.invoke()
    dt = (time.perf_counter() - t0) * 1000
    probs = interp.get_tensor(out["index"])[0].astype(np.float32)
    top3 = probs.argsort()[-3:][::-1].tolist()
    return int(probs.argmax()), top3, dt


def gemini_kcal_per_100g(jpeg_bytes, api_key, max_retries=4):
    """Gemini'den yemeğin kcal/100g tahminini ister. (kcal_per_100g, latency_ms).

    429 (oran sınırı) ve geçici 5xx hatalarında üstel beklemeyle yeniden dener.
    """
    b64 = base64.b64encode(jpeg_bytes).decode()
    prompt = (
        "Bu yemeğin 100 gramının yaklaşık kalorisini tahmin et. "
        'SADECE JSON döndür: {"kcal_per_100g": <sayı>}'
    )
    body = json.dumps({
        "contents": [{"parts": [
            {"text": prompt},
            {"inline_data": {"mime_type": "image/jpeg", "data": b64}},
        ]}],
        "generationConfig": {"responseMimeType": "application/json"},
    }).encode()
    url = (f"https://generativelanguage.googleapis.com/v1beta/models/"
           f"{GEMINI_MODEL}:generateContent?key={api_key}")

    for attempt in range(max_retries):
        req = urllib.request.Request(url, data=body,
                                     headers={"Content-Type": "application/json"})
        t0 = time.perf_counter()
        try:
            with urllib.request.urlopen(req, timeout=40) as r:
                data = json.loads(r.read())
            dt = (time.perf_counter() - t0) * 1000
            text = data["candidates"][0]["content"]["parts"][0]["text"]
            return float(json.loads(text)["kcal_per_100g"]), dt
        except urllib.error.HTTPError as e:
            # 429 = oran sınırı, 5xx = geçici. Bekle ve tekrar dene.
            if e.code in (429, 500, 502, 503, 504) and attempt < max_retries - 1:
                wait = 5 * (attempt + 1)  # 5, 10, 15 sn
                print(f"  Gemini {e.code}: {wait} sn bekleniyor...")
                time.sleep(wait)
                continue
            raise
    raise RuntimeError("Gemini: tüm denemeler başarısız")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--samples", type=int, default=200)
    ap.add_argument("--model", default="out/food_classifier.tflite")
    ap.add_argument("--labels", default="out/labels.txt")
    ap.add_argument("--calories", default="food101_calories.csv")
    ap.add_argument("--with-gemini", action="store_true")
    ap.add_argument("--gemini-samples", type=int, default=30)
    ap.add_argument("--gemini-delay", type=float, default=4.5,
                    help="Gemini çağrıları arası bekleme (sn) — oran sınırı için")
    ap.add_argument("--data-dir", default="food-101")
    ap.add_argument("--out", default="out/comparison.md")
    args = ap.parse_args()

    labels = open(args.labels, encoding="utf-8").read().splitlines()
    calories = load_calories(args.calories)
    api_key = os.environ.get("GEMINI_API_KEY", "")

    # Bazı int8 modelleri + yeni TF'te varsayılan XNNPACK delegesi bir düğümü
    # hazırlayamayıp "failed to create XNNPACK runtime" hatası verir. Delegesiz
    # (saf CPU referans çekirdekleri) oluşturmak bunu giderir; değerlendirme için
    # hız yeterli.
    try:
        interp = tf.lite.Interpreter(
            model_path=args.model,
            experimental_op_resolver_type=(
                tf.lite.experimental.OpResolverType.BUILTIN_WITHOUT_DEFAULT_DELEGATES
            ),
        )
        interp.allocate_tensors()
    except Exception:
        interp = tf.lite.Interpreter(model_path=args.model)
        interp.allocate_tensors()
    inp, out = interp.get_input_details()[0], interp.get_output_details()[0]

    paths, labels_idx, _ = list_split(args.data_dir, "test")
    items = list(zip(paths, labels_idx))
    random.shuffle(items)
    items = items[: args.samples]

    cnn_correct = 0
    cnn_top3_correct = 0
    cnn_abs_err, cnn_lat = [], []
    gem_abs_err, gem_lat = [], []
    gem_done = 0

    for i, (path, label) in enumerate(items):
        true_name = labels[int(label)]
        true_kcal = calories.get(true_name, 0)
        img = np.array(
            Image.open(path).convert("RGB").resize((IMG_SIZE, IMG_SIZE)),
            dtype=np.uint8,
        )

        pred_idx, top3, dt = tflite_predict(interp, inp, out, img)
        cnn_lat.append(dt)
        if pred_idx == int(label):
            cnn_correct += 1
        # Top-3: Edge LLM (Gemma) CNN'in ilk 3 adayından seçtiği için bu, o
        # hattın yemek-tanıma doğruluk TAVANIDIR.
        if int(label) in top3:
            cnn_top3_correct += 1
        cnn_abs_err.append(abs(calories.get(labels[pred_idx], 0) - true_kcal))

        if args.with_gemini and api_key and gem_done < args.gemini_samples:
            try:
                with open(path, "rb") as fh:
                    kcal, gdt = gemini_kcal_per_100g(fh.read(), api_key)
                gem_abs_err.append(abs(kcal - true_kcal))
                gem_lat.append(gdt)
                gem_done += 1
                # Oran sınırına takılmamak için çağrılar arası bekle.
                if gem_done < args.gemini_samples:
                    time.sleep(args.gemini_delay)
            except Exception as e:  # noqa: BLE001
                print(f"Gemini hatası ({i}): {e}")

    model_kb = os.path.getsize(args.model) / 1024
    n = len(cnn_lat)

    def mean(xs):
        return sum(xs) / len(xs) if xs else float("nan")

    top1 = cnn_correct / n * 100
    top3 = cnn_top3_correct / n * 100
    lines = [
        "# Edge vs Cloud — Kıyaslama (Food-101 test seti)",
        "",
        f"Örnek sayısı: {n} (Gemini: {gem_done}). "
        "Gecikmeler masaüstünde ölçülür; telefon değerleri için README'ye bakın.",
        "",
        "| Metrik | Edge CNN (TFLite) | Edge LLM (CNN→Gemma 1B) | Cloud LLM (Gemini) |",
        "|---|---|---|---|",
        f"| Yemek tanıma doğruluğu | %{top1:.1f} (top-1) | "
        f"≤ %{top3:.1f} (top-3 tavanı) | serbest (sınıf yok) |",
        f"| Kalori MAE (kcal/100g) | {mean(cnn_abs_err):.1f} | "
        f"CNN tablosu / LLM | {mean(gem_abs_err):.1f} |",
        f"| Ortalama gecikme | {mean(cnn_lat):.1f} ms | ~13.8 sn (telefon) | "
        f"{mean(gem_lat):.0f} ms |",
        f"| Model boyutu | {model_kb:.0f} KB | ~550 MB | bulutta (N/A) |",
        "| Makro üretir | Hayır | Evet | Evet |",
        "| İnternet gerekir | Hayır | Hayır | Evet |",
        "| Maliyet | Yok | Yok | API kotası |",
        "",
        "**Not:** Edge LLM (Gemma) yemeği CNN'in ilk 3 adayından seçtiği için "
        f"tanıma tavanı top-3 doğruluğudur (%{top3:.1f}); top-1'in (%{top1:.1f}) "
        "üstüne, doğru sınıf ilk 3'teyse kurtarma payı ekler ve ayrıca makro üretir.",
    ]
    report = "\n".join(lines)
    os.makedirs(os.path.dirname(args.out), exist_ok=True)
    with open(args.out, "w", encoding="utf-8") as f:
        f.write(report + "\n")
    print(report)
    print(f"\nTablo '{args.out}' dosyasına yazıldı.")


if __name__ == "__main__":
    main()
