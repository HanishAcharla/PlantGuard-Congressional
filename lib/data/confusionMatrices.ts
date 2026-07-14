import { CLASS_IDS, ClassId } from "./classes";

// Transcribed directly from Fig. 4 (ResNet-50) and Fig. 5 (ConvNeXt-XLarge+MLP) of the
// paper. Rows = true label, columns = predicted label, in CLASS_IDS order.
export const CONFUSION_MATRICES: Record<"resnet50" | "convnext-mlp", number[][]> = {
  resnet50: [
    [125, 35, 2, 6, 19, 16],
    [19, 265, 12, 1, 0, 19],
    [0, 1, 433, 0, 0, 25],
    [1, 1, 5, 81, 0, 2],
    [3, 12, 2, 0, 173, 4],
    [11, 9, 31, 3, 3, 405],
  ],
  "convnext-mlp": [
    [159, 12, 2, 4, 18, 8],
    [18, 273, 6, 1, 4, 14],
    [0, 2, 431, 0, 0, 26],
    [1, 0, 0, 89, 0, 0],
    [12, 1, 1, 0, 180, 2],
    [7, 8, 18, 4, 0, 445],
  ],
};

export function matrixRowTotal(matrix: number[][], rowIndex: number): number {
  return matrix[rowIndex].reduce((a, b) => a + b, 0);
}

export const CONFUSION_CLASS_ORDER: ClassId[] = CLASS_IDS;
