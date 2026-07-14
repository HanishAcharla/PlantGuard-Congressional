# Apple Leaf Disease Detection — Research Showcase

An interactive showcase for "Data-Driven Solutions in Agriculture: Machine Learning
for Apple Disease Classification" (Hanish Acharla, IEEE SusTech). Visitors can upload
a leaf photo and run the paper's fine-tuned ResNet-50 model live, entirely in their
browser, via TensorFlow.js — no backend required.

## Stack

- Next.js 14 (App Router) + TypeScript + Tailwind CSS
- Framer Motion for animation
- `@tensorflow/tfjs` for fully client-side inference (TF.js Graph model)

## Local development

```bash
npm install
npm run dev
```

Open http://localhost:3000.

## Deploying to Vercel

This is a standard Next.js app, so it deploys to Vercel with zero configuration:

1. Push this repository to GitHub (or GitLab/Bitbucket).
2. Go to https://vercel.com/new and import the repository.
3. Vercel auto-detects Next.js — no build settings need to change. Click **Deploy**.

Or, from the CLI:

```bash
npx vercel        # first deploy, follow the prompts
npx vercel --prod # subsequent production deploys
```

The model files under `public/model/resnet50/` (~46MB) ship as static assets and are
served with a long-lived immutable cache header (see `next.config.mjs`).

## Re-converting the model

The trained model isn't checked into this repo path directly — `public/model/resnet50/`
already contains the converted TensorFlow.js Graph model. If you ever need to
re-convert it from a Keras `.h5` file (e.g. a newly retrained version), the model was
originally saved with a Keras 3 config that TF.js's `loadLayersModel` can't parse
directly, so the conversion goes through an intermediate TF SavedModel:

```bash
# 1. Re-export the .h5 as a SavedModel (needs a recent TF/Keras 3, e.g. tensorflow>=2.19)
python3 -c "
import tensorflow as tf
m = tf.keras.models.load_model('YourModel.h5')
m.export('/tmp/saved_model')
"

# 2. Convert the SavedModel to a TF.js Graph model (needs tensorflowjs==4.22.0 + tensorflow==2.15.*
#    in a *separate* venv — tensorflowjs pins tensorflow-decision-forces to 2.15 exactly)
tensorflowjs_converter \
  --input_format=tf_saved_model \
  --output_format=tfjs_graph_model \
  --signature_name=serving_default \
  --saved_model_tags=serve \
  "--quantize_uint16=*" \
  /tmp/saved_model public/model/resnet50
```

Bump the version query string in `lib/model.ts` (`MODEL_URL`) after re-converting —
the model files are served with an immutable cache header, so the query string is
what busts client caches for anyone who already loaded the old version.

Preprocessing (in `lib/model.ts`) replicates `keras.applications.resnet.preprocess_input`
exactly: resize to 224×224, convert RGB → BGR, subtract ImageNet channel means
`[103.939, 116.779, 123.68]`, no `/255` scaling.
