"""
Food-101 veri yükleyici (tensorflow-datasets'siz).

Veri seti resmi tar'dan elle indirilir (Colab hücresinde):
    !wget -q --show-progress http://data.vision.ee.ethz.ch/cvl/food-101.tar.gz
    !tar xzf food-101.tar.gz

Klasör yapısı:
    food-101/images/<sinif>/<id>.jpg
    food-101/meta/train.txt , test.txt   (satır: "sinif/id")

Bu modül hem eğitim hem değerlendirme tarafından kullanılır, böylece sınıf
sırası (etiket indexleri) her yerde aynıdır ve food101_calories.csv ile eşleşir.
"""

import os

import tensorflow as tf

IMG_SIZE = 224
AUTOTUNE = tf.data.AUTOTUNE


def list_split(data_dir: str, split: str):
    """split: 'train' | 'test'. (paths, labels, class_names) döndürür."""
    images_dir = os.path.join(data_dir, "images")
    class_names = sorted(
        d for d in os.listdir(images_dir)
        if os.path.isdir(os.path.join(images_dir, d))
    )
    idx = {c: i for i, c in enumerate(class_names)}

    paths, labels = [], []
    with open(os.path.join(data_dir, "meta", f"{split}.txt"), encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            cls = line.split("/")[0]
            paths.append(os.path.join(images_dir, line + ".jpg"))
            labels.append(idx[cls])
    return paths, labels, class_names


def _load(path, label):
    img = tf.io.read_file(path)
    img = tf.io.decode_jpeg(img, channels=3)
    img = tf.image.resize(img, (IMG_SIZE, IMG_SIZE))
    return tf.cast(img, tf.float32), label  # 0..255; model ölçeklemeyi içeride yapar


def make_dataset(paths, labels, batch: int, training: bool):
    ds = tf.data.Dataset.from_tensor_slices((paths, labels))
    if training:
        ds = ds.shuffle(min(len(paths), 4000))
    ds = ds.map(_load, num_parallel_calls=AUTOTUNE)
    return ds.batch(batch).prefetch(AUTOTUNE)
