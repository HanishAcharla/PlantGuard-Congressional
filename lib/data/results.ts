// All figures below are transcribed directly from Table I and the results text of
// "Data-Driven Solutions in Agriculture: Machine Learning for Apple Disease
// Classification" (Hanish Acharla, IEEE SusTech). Nothing here is estimated.

export interface ModelResult {
  id: string;
  name: string;
  short: string;
  accuracy: number; // validation accuracy, Table I
  precision: number;
  recall: number;
  f1: number;
  testAccuracy?: number; // held-out test set accuracy, reported separately in the text
  isLive: boolean;
  blurb: string;
}

export const MODEL_RESULTS: ModelResult[] = [
  {
    id: "resnet50",
    name: "ResNet-50 (fine-tuned)",
    short: "ResNet-50",
    accuracy: 86.5,
    precision: 0.85,
    recall: 0.85,
    f1: 84,
    testAccuracy: 85,
    isLive: true,
    blurb:
      "50-layer residual network, fine-tuned end-to-end on the Plant Pathology dataset. This is the exact model running in the live demo above.",
  },
  {
    id: "convnext-mlp",
    name: "ConvNeXt-XLarge + MLP",
    short: "ConvNeXt+MLP",
    accuracy: 87.5,
    precision: 0.88,
    recall: 0.88,
    f1: 87,
    testAccuracy: 90.32,
    isLive: false,
    blurb:
      "ConvNeXt-XLarge features (2048-d, ImageNet-pretrained) classified by a tuned multilayer perceptron. The paper's best-performing configuration overall.",
  },
  {
    id: "convnext-knn",
    name: "ConvNeXt-XLarge + KNN",
    short: "ConvNeXt+KNN",
    accuracy: 79.41,
    precision: 0.8,
    recall: 0.79,
    f1: 69,
    isLive: false,
    blurb:
      "Same ConvNeXt feature vectors, classified with k-nearest neighbors (k=13). Reasonable accuracy but a weaker precision/recall balance.",
  },
  {
    id: "convnext-rf",
    name: "ConvNeXt-XLarge + Random Forest",
    short: "ConvNeXt+RF",
    accuracy: 73.27,
    precision: 0.75,
    recall: 0.73,
    f1: 73,
    isLive: false,
    blurb:
      "Same ConvNeXt feature vectors, classified with a 100-tree random forest (max depth 7). The most balanced but least accurate of the featurization models.",
  },
];

export const DATASET_STATS = {
  name: "Plant Pathology 2021 (FGVC8)",
  totalImages: 17826,
  train: 14288,
  validation: 1790,
  test: 1748,
  originalCategories: 12,
  finalCategories: 6,
};

export const PROBLEM_STATS = [
  {
    value: 10,
    suffix: "%+",
    label: "of global food production lost to plant disease every year",
  },
  {
    value: 95.84,
    suffix: "M",
    label: "metric tons of apples produced worldwide in 2022 alone",
  },
  {
    value: 23,
    suffix: "B",
    prefix: "$",
    label: "in downstream U.S. apple industry revenue every year",
  },
  {
    value: 20,
    suffix: "%+",
    label: "of apple production lost annually to disease",
  },
];
