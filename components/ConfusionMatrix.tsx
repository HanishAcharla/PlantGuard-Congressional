"use client";

import { useState } from "react";
import { motion } from "framer-motion";
import { CONFUSION_MATRICES, matrixRowTotal } from "@/lib/data/confusionMatrices";
import { CLASS_IDS, CLASS_INFO } from "@/lib/data/classes";
import { heatColor } from "@/lib/colorScale";

const SHORT_LABEL: Record<string, string> = {
  complex: "CPX",
  frog_eye_leaf_spot: "FES",
  healthy: "HLT",
  powdery_mildew: "PM",
  rust: "RST",
  scab: "SCB",
};

const TABS = [
  { id: "resnet50" as const, label: "ResNet-50", sub: "Live model" },
  { id: "convnext-mlp" as const, label: "ConvNeXt-XLarge + MLP", sub: "Best reported" },
];

export function ConfusionMatrix() {
  const [active, setActive] = useState<"resnet50" | "convnext-mlp">("resnet50");
  const matrix = CONFUSION_MATRICES[active];
  const max = Math.max(...matrix.flat());

  return (
    <div>
      <div className="mb-6 inline-flex rounded-full border border-parchment-100/15 bg-canopy-950/50 p-1">
        {TABS.map((tab) => (
          <button
            key={tab.id}
            onClick={() => setActive(tab.id)}
            className={`relative rounded-full px-4 py-2 text-sm font-medium transition-colors ${
              active === tab.id ? "text-canopy-950" : "text-parchment-200/60 hover:text-parchment-100"
            }`}
          >
            {active === tab.id && (
              <motion.span
                layoutId="cm-tab"
                className="absolute inset-0 rounded-full bg-parchment-100"
                transition={{ type: "spring", duration: 0.5, bounce: 0.15 }}
              />
            )}
            <span className="relative z-10">
              {tab.label}
              <span className="ml-1.5 hidden font-mono text-xs opacity-60 sm:inline">
                · {tab.sub}
              </span>
            </span>
          </button>
        ))}
      </div>

      <div className="thin-scroll overflow-x-auto rounded-2xl border border-parchment-100/10 bg-canopy-950/40 p-5 sm:p-6">
        <table className="w-full min-w-[560px] border-separate border-spacing-1.5">
          <thead>
            <tr>
              <th className="w-24" />
              <th
                colSpan={CLASS_IDS.length}
                className="pb-2 text-center font-mono text-[0.65rem] uppercase tracking-widest text-parchment-200/40"
              >
                Predicted
              </th>
            </tr>
            <tr>
              <th />
              {CLASS_IDS.map((id) => (
                <th
                  key={id}
                  className="pb-1 text-center font-mono text-xs font-medium text-parchment-200/60"
                  title={CLASS_INFO[id].label}
                >
                  {SHORT_LABEL[id]}
                </th>
              ))}
            </tr>
          </thead>
          <tbody>
            {CLASS_IDS.map((rowId, rowIdx) => {
              const rowTotal = matrixRowTotal(matrix, rowIdx);
              const recall = matrix[rowIdx][rowIdx] / rowTotal;
              return (
                <tr key={rowId}>
                  <th
                    className="whitespace-nowrap pr-2 text-right font-mono text-xs font-medium text-parchment-200/60"
                    title={CLASS_INFO[rowId].label}
                  >
                    {SHORT_LABEL[rowId]}
                  </th>
                  {matrix[rowIdx].map((value, colIdx) => (
                    <td key={colIdx} className="p-0">
                      <div
                        className={`flex h-12 w-12 items-center justify-center rounded-lg font-mono text-sm tabular-nums transition-transform hover:scale-105 sm:h-14 sm:w-14 ${
                          rowIdx === colIdx ? "ring-2 ring-parchment-50/50" : ""
                        }`}
                        style={{ backgroundColor: heatColor(value, max) }}
                      >
                        <span className={value / max > 0.35 ? "text-parchment-50" : "text-parchment-100/70"}>
                          {value}
                        </span>
                      </div>
                    </td>
                  ))}
                  <td className="pl-3 text-left">
                    <span className="font-mono text-xs text-parchment-200/50">
                      {(recall * 100).toFixed(0)}% recall
                    </span>
                  </td>
                </tr>
              );
            })}
          </tbody>
        </table>

        <div className="mt-5 flex items-center gap-3 text-xs text-parchment-200/40">
          <span>Fewer</span>
          <div
            className="h-2 w-32 rounded-full"
            style={{
              background: `linear-gradient(to right, ${heatColor(0, max)}, ${heatColor(max, max)})`,
            }}
          />
          <span>More</span>
          <span className="ml-auto">Rows = true label · columns = predicted label</span>
        </div>
      </div>
    </div>
  );
}
