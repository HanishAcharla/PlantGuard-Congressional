"""Check the Core ML package against the original Keras model on a set of synthetic images.

    python ios/scripts/verify_coreml.py "ResNet_50_Best_Model (1).h5" ios/PlantGuard/ML/PlantGuardClassifier.mlpackage

Images are generated at exactly 224x224 so resizing can't account for any difference;
what's left is preprocessing (BGR order, channel means) and FP16 precision.
"""

import sys

import coremltools as ct
import numpy as np
import tensorflow as tf
from PIL import Image
from tensorflow.keras.applications.resnet import preprocess_input

CLASS_LABELS = ["complex", "frog_eye_leaf_spot", "healthy", "powdery_mildew", "rust", "scab"]


def synthetic_images():
    rng = np.random.default_rng(7)
    yy, xx = np.mgrid[0:224, 0:224].astype(np.float32)
    images = {}

    r = 90 + 60 * np.sin(xx / 30.0) + 40 * np.cos(yy / 41.0)
    g = 130 + 50 * np.cos((xx + yy) / 45.0)
    b = 60 + 30 * np.sin(yy / 26.0)
    images["gradient"] = np.stack([r, g, b], -1)

    leaf = np.zeros((224, 224, 3), np.float32) + [70, 120, 50]
    for _ in range(25):
        cx, cy, rad = rng.uniform(20, 204), rng.uniform(20, 204), rng.uniform(4, 14)
        mask = (xx - cx) ** 2 + (yy - cy) ** 2 < rad**2
        leaf[mask] = [110, 95, 40]
    images["spotted_green"] = leaf

    images["noise"] = rng.uniform(0, 255, (224, 224, 3))
    images["warm_blotches"] = np.stack(
        [150 + 80 * np.sin(xx / 17.0), 110 + 40 * np.cos(yy / 13.0), 40 + 20 * np.sin((xx - yy) / 9.0)], -1
    )
    images["pale"] = np.zeros((224, 224, 3)) + [200, 205, 190] + rng.normal(0, 12, (224, 224, 3))
    # Strongly asymmetric R vs B, so a swapped channel order can't hide.
    images["red_left_blue_right"] = np.stack([255 * (xx < 112), 120 + 0 * xx, 255 * (xx >= 112)], -1)
    return {k: np.clip(v, 0, 255).astype(np.uint8) for k, v in images.items()}


def main(h5_path: str, mlpackage_path: str) -> None:
    keras_model = tf.keras.models.load_model(h5_path, compile=False)
    ml = ct.models.MLModel(mlpackage_path)
    prob_key = [o.name for o in ml.get_spec().description.output if o.type.WhichOneof("Type") == "dictionaryType"][0]

    worst = 0.0
    for name, arr in synthetic_images().items():
        ref = keras_model.predict(preprocess_input(arr[None].astype(np.float32)), verbose=0)[0]
        out = ml.predict({"image": Image.fromarray(arr, "RGB")})[prob_key]
        got = np.array([out[c] for c in CLASS_LABELS])
        diff = np.abs(ref - got).max()
        worst = max(worst, diff)
        print(f"{name:20s} keras={CLASS_LABELS[ref.argmax()]:18s} {ref.max():.3f}  coreml={CLASS_LABELS[got.argmax()]:18s} {got.max():.3f}  max|diff|={diff:.4f}")
        print("   keras ", np.round(ref, 3))
        print("   coreml", np.round(got, 3))
    print(f"\nworst max abs diff: {worst:.4f}")


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
