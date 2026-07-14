import * as tf from "@tensorflow/tfjs";
import { CLASS_IDS, ClassId } from "./data/classes";

// Versioned so we can safely bust the immutable cache header (next.config.mjs) if
// the model is ever re-converted/updated.
const MODEL_URL = "/model/resnet50/model.json?v=2";

// ImageNet BGR channel means used by keras.applications.resnet.preprocess_input
// ("caffe" mode: RGB -> BGR, then zero-center per channel, no /255 scaling).
const BGR_MEANS = [103.939, 116.779, 123.68] as const;

let modelPromise: Promise<tf.GraphModel> | null = null;

export function loadModel(onProgress?: (fraction: number) => void) {
  if (!modelPromise) {
    modelPromise = tf.loadGraphModel(MODEL_URL, { onProgress }).then(async (model) => {
      // warm up the WebGL backend so the first real prediction isn't slow
      const warmup = tf.zeros([1, 224, 224, 3]);
      const out = model.predict(warmup) as tf.Tensor;
      await out.data();
      tf.dispose([warmup, out]);
      return model;
    });
  }
  return modelPromise;
}

export interface Prediction {
  classId: ClassId;
  probability: number;
}

function preprocess(imgElement: HTMLImageElement): tf.Tensor4D {
  return tf.tidy(() => {
    const img = tf.browser.fromPixels(imgElement, 3);
    const resized = tf.image.resizeBilinear(img, [224, 224]);
    const [r, g, b] = tf.split(resized.toFloat(), 3, -1);
    const bChan = b.sub(BGR_MEANS[0]);
    const gChan = g.sub(BGR_MEANS[1]);
    const rChan = r.sub(BGR_MEANS[2]);
    const bgr = tf.concat([bChan, gChan, rChan], -1);
    return bgr.expandDims(0) as tf.Tensor4D;
  });
}

export async function classify(
  model: tf.GraphModel,
  imgElement: HTMLImageElement
): Promise<Prediction[]> {
  const input = preprocess(imgElement);
  const output = model.predict(input) as tf.Tensor;
  const data = await output.data();
  tf.dispose([input, output]);

  return CLASS_IDS.map((classId, i) => ({
    classId,
    probability: data[i],
  })).sort((a, b) => b.probability - a.probability);
}
