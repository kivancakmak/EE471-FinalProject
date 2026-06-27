"""Tek bir görselde int8 TFLite modelini test eder (akıl sağlığı kontrolü)."""

import argparse
import csv
import os

import numpy as np
import tensorflow as tf
from PIL import Image

IMG_SIZE = 224


def load_calories(path):
    cal = {}
    with open(path, encoding="utf-8") as f:
        for row in csv.DictReader(f):
            cal[row["label"]] = float(row["kcal_per_100g"])
    return cal


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--image", required=True)
    ap.add_argument("--model", default="out/food_classifier.tflite")
    ap.add_argument("--labels", default="out/labels.txt")
    ap.add_argument("--calories", default="food101_calories.csv")
    ap.add_argument("--grams", type=float, default=300, help="tahmini porsiyon gram")
    args = ap.parse_args()

    labels = open(args.labels, encoding="utf-8").read().splitlines()
    calories = load_calories(args.calories)

    img = Image.open(args.image).convert("RGB").resize((IMG_SIZE, IMG_SIZE))
    arr = np.expand_dims(np.array(img, dtype=np.uint8), 0)  # int8 model uint8 girdi bekler

    # Varsayılan XNNPACK delegesi bazı int8 modellerinde hata verir → delegesiz aç.
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
    inp = interp.get_input_details()[0]
    out = interp.get_output_details()[0]
    interp.set_tensor(inp["index"], arr)
    interp.invoke()
    probs = interp.get_tensor(out["index"])[0].astype(np.float32)

    top = probs.argsort()[-3:][::-1]
    print("En olası 3 sınıf:")
    for i in top:
        name = labels[i]
        kcal100 = calories.get(name, 0)
        total = kcal100 * args.grams / 100
        print(f"  {name:<28} %{probs[i] * 100:5.1f}  "
              f"({kcal100:.0f} kcal/100g → {total:.0f} kcal / {args.grams:.0f} g)")


if __name__ == "__main__":
    main()
