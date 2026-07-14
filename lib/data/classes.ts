export type ClassId =
  | "complex"
  | "frog_eye_leaf_spot"
  | "healthy"
  | "powdery_mildew"
  | "rust"
  | "scab";

// Alphabetical order — matches the sorted-folder-name label indexing used when the
// ResNet-50 model was trained/tested, and the axis order of the paper's confusion matrices.
export const CLASS_IDS: ClassId[] = [
  "complex",
  "frog_eye_leaf_spot",
  "healthy",
  "powdery_mildew",
  "rust",
  "scab",
];

export const CLASS_INFO: Record<
  ClassId,
  { label: string; description: string; tone: "healthy" | "disease" | "mixed" }
> = {
  complex: {
    label: "Complex",
    description: "Multiple co-occurring diseases on one leaf — the hardest case to call.",
    tone: "mixed",
  },
  frog_eye_leaf_spot: {
    label: "Frog Eye Leaf Spot",
    description: "Fungal spotting (Botryosphaeria obtusa) with a dark ring and pale center.",
    tone: "disease",
  },
  healthy: {
    label: "Healthy",
    description: "No visible signs of disease.",
    tone: "healthy",
  },
  powdery_mildew: {
    label: "Powdery Mildew",
    description: "A white-grey fungal coating, thrives in warm, dry conditions.",
    tone: "disease",
  },
  rust: {
    label: "Rust",
    description: "Orange-yellow fungal pustules caused by Gymnosporangium species.",
    tone: "disease",
  },
  scab: {
    label: "Scab",
    description: "Olive-brown lesions from Venturia inaequalis, the most common apple disease.",
    tone: "disease",
  },
};
