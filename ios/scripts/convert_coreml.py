"""Convert the fine-tuned ResNet-50 Keras model to a Core ML package for the iOS app.

Run from a venv with `tensorflow` (Keras 3, to read the .h5) and `coremltools`:

    python ios/scripts/convert_coreml.py "ResNet_50_Best_Model (1).h5" ios/PlantGuard/ML/PlantGuardClassifier.mlpackage

The image preprocessing used at training time (keras.applications.resnet.preprocess_input,
"caffe" mode: RGB -> BGR, subtract ImageNet channel means, no /255 scaling) is folded into
the Core ML image input, so the app hands Core ML an ordinary 224x224 photo.
"""

import sys

import coremltools as ct
import tensorflow as tf

# Alphabetical folder order the model was trained with (see best_model_testing_resnet_50.py).
CLASS_LABELS = ["complex", "frog_eye_leaf_spot", "healthy", "powdery_mildew", "rust", "scab"]

# Per-channel bias in the network's channel order (B, G, R) after Core ML converts to BGR.
BGR_BIAS = [-103.939, -116.779, -123.68]


def main(h5_path: str, out_path: str) -> None:
    model = tf.keras.models.load_model(h5_path, compile=False)

    @tf.function(input_signature=[tf.TensorSpec([1, 224, 224, 3], tf.float32, name="image")])
    def serve(image):
        return model(image, training=False)

    mlmodel = ct.convert(
        [serve.get_concrete_function()],
        source="tensorflow",
        inputs=[
            ct.ImageType(
                name="image",
                shape=(1, 224, 224, 3),
                color_layout=ct.colorlayout.BGR,
                bias=BGR_BIAS,
                scale=1.0,
            )
        ],
        classifier_config=ct.ClassifierConfig(CLASS_LABELS),
        minimum_deployment_target=ct.target.iOS17,
        compute_precision=ct.precision.FLOAT16,
    )

    mlmodel.short_description = (
        "Apple leaf disease classifier (fine-tuned ResNet-50, Plant Pathology 2021). "
        "Acharla & Kandasamy, IEEE SusTech."
    )
    mlmodel.author = "Hanish Acharla"
    mlmodel.license = "Research use"
    mlmodel.input_description["image"] = "Photo of a single apple leaf, 224x224"
    mlmodel.save(out_path)
    print("saved", out_path)


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
