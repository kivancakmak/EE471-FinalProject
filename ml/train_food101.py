"""
Faz 1 — Food-101 üzerinde yemek sınıflandırma modeli eğitimi.

MobileNetV3Small ile transfer learning yapar, int8 TFLite olarak dışa aktarır.
Çıktılar (out_dir):
  - food_classifier.tflite       (int8, telefon için)
  - food_classifier_fp16.tflite  (float16, daha doğru/biraz büyük)
  - labels.txt                   (sınıf adları, model çıktı sırasıyla)

Colab'da çalıştırma (öneri):
    !pip install -q tensorflow-datasets
    !python train_food101.py --epochs-head 3 --epochs-finetune 5

Hızlı deneme (küçük altküme):
    !python train_food101.py --subset 0.1 --epochs-head 1 --epochs-finetune 1
"""

import argparse
import os

import tensorflow as tf
import tensorflow_datasets as tfds

IMG_SIZE = 224
NUM_CLASSES = 101
AUTOTUNE = tf.data.AUTOTUNE


def build_datasets(batch: int, subset: float):
    """Food-101'i yükler; (train, val, label_names) döndürür."""
    (ds_train, ds_val), info = tfds.load(
        "food101",
        split=["train", "validation"],
        as_supervised=True,
        with_info=True,
    )
    label_names = info.features["label"].names

    if subset < 1.0:
        n_train = int(info.splits["train"].num_examples * subset)
        n_val = int(info.splits["validation"].num_examples * subset)
        ds_train = ds_train.take(n_train)
        ds_val = ds_val.take(n_val)

    def prep(image, label):
        image = tf.image.resize(image, (IMG_SIZE, IMG_SIZE))
        return tf.cast(image, tf.float32), label  # 0..255; base ölçeklemeyi içeride yapar

    ds_train = (
        ds_train.map(prep, num_parallel_calls=AUTOTUNE)
        .shuffle(2000)
        .batch(batch)
        .prefetch(AUTOTUNE)
    )
    ds_val = ds_val.map(prep, num_parallel_calls=AUTOTUNE).batch(batch).prefetch(AUTOTUNE)
    return ds_train, ds_val, label_names


def build_model() -> tf.keras.Model:
    augment = tf.keras.Sequential(
        [
            tf.keras.layers.RandomFlip("horizontal"),
            tf.keras.layers.RandomRotation(0.1),
            tf.keras.layers.RandomZoom(0.1),
        ],
        name="augment",
    )
    base = tf.keras.applications.MobileNetV3Small(
        input_shape=(IMG_SIZE, IMG_SIZE, 3),
        include_top=False,
        weights="imagenet",
        include_preprocessing=True,  # 0..255 girdiyi içeride normalize eder
    )
    base.trainable = False

    inputs = tf.keras.Input(shape=(IMG_SIZE, IMG_SIZE, 3))
    x = augment(inputs)
    x = base(x, training=False)
    x = tf.keras.layers.GlobalAveragePooling2D()(x)
    x = tf.keras.layers.Dropout(0.2)(x)
    outputs = tf.keras.layers.Dense(NUM_CLASSES, activation="softmax")(x)
    model = tf.keras.Model(inputs, outputs)
    return model, base


def export_tflite(model, ds_train, out_dir):
    """float16 ve int8 TFLite dosyalarını yazar."""
    # float16
    conv = tf.lite.TFLiteConverter.from_keras_model(model)
    conv.optimizations = [tf.lite.Optimize.DEFAULT]
    conv.target_spec.supported_types = [tf.float16]
    with open(os.path.join(out_dir, "food_classifier_fp16.tflite"), "wb") as f:
        f.write(conv.convert())

    # int8 (tam tamsayı) — kalibrasyon için temsili veri
    def rep_data():
        for images, _ in ds_train.take(50):
            for i in range(images.shape[0]):
                yield [tf.expand_dims(images[i], 0)]

    conv = tf.lite.TFLiteConverter.from_keras_model(model)
    conv.optimizations = [tf.lite.Optimize.DEFAULT]
    conv.representative_dataset = rep_data
    conv.target_spec.supported_ops = [tf.lite.OpsSet.TFLITE_BUILTINS_INT8]
    conv.inference_input_type = tf.uint8
    conv.inference_output_type = tf.uint8
    with open(os.path.join(out_dir, "food_classifier.tflite"), "wb") as f:
        f.write(conv.convert())


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--epochs-head", type=int, default=3)
    ap.add_argument("--epochs-finetune", type=int, default=5)
    ap.add_argument("--batch", type=int, default=64)
    ap.add_argument("--subset", type=float, default=1.0, help="0-1 arası veri oranı")
    ap.add_argument("--out-dir", default="out")
    args = ap.parse_args()

    os.makedirs(args.out_dir, exist_ok=True)
    ds_train, ds_val, label_names = build_datasets(args.batch, args.subset)

    # Etiketleri model çıktı sırasıyla kaydet (kalori CSV ile eşleşir).
    with open(os.path.join(args.out_dir, "labels.txt"), "w", encoding="utf-8") as f:
        f.write("\n".join(label_names))

    model, base = build_model()

    # 1) Sadece başlığı eğit
    model.compile(
        optimizer=tf.keras.optimizers.Adam(1e-3),
        loss="sparse_categorical_crossentropy",
        metrics=["accuracy"],
    )
    model.fit(ds_train, validation_data=ds_val, epochs=args.epochs_head)

    # 2) İnce ayar: üst katmanları çöz
    base.trainable = True
    for layer in base.layers[:-40]:
        layer.trainable = False
    model.compile(
        optimizer=tf.keras.optimizers.Adam(1e-5),
        loss="sparse_categorical_crossentropy",
        metrics=["accuracy"],
    )
    model.fit(ds_train, validation_data=ds_val, epochs=args.epochs_finetune)

    loss, acc = model.evaluate(ds_val)
    print(f"\nValidation doğruluk: {acc:.3f}")

    model.save(os.path.join(args.out_dir, "food_classifier.keras"))
    export_tflite(model, ds_train, args.out_dir)
    print(f"TFLite + labels '{args.out_dir}' klasörüne yazıldı.")


if __name__ == "__main__":
    main()
