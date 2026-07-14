"use client";

import { motion } from "framer-motion";
import { MODEL_RESULTS } from "@/lib/data/results";
import { RevealGroup, RevealItem } from "./Reveal";

// Fixed categorical order, validated against the dark canopy surface (#0c1e16) with
// scripts/validate_palette.js from the dataviz skill — lightness band, chroma floor,
// CVD adjacent-pair separation, and contrast all pass.
const SERIES_COLOR: Record<string, string> = {
  resnet50: "#c96a35",
  "convnext-mlp": "#3a9c5c",
  "convnext-knn": "#a87a1f",
  "convnext-rf": "#7b8fe0",
};

export function ResultsChart() {
  const maxAccuracy = Math.max(...MODEL_RESULTS.map((m) => m.accuracy));

  return (
    <div>
      <RevealGroup className="space-y-5" stagger={0.08}>
        {MODEL_RESULTS.map((model) => (
          <RevealItem key={model.id}>
            <div className="mb-1.5 flex flex-wrap items-baseline justify-between gap-x-4 gap-y-1">
              <div className="flex items-center gap-2.5">
                <span
                  className="h-2.5 w-2.5 shrink-0 rounded-full"
                  style={{ backgroundColor: SERIES_COLOR[model.id] }}
                  aria-hidden
                />
                <span className="font-medium text-parchment-100">{model.name}</span>
                {model.isLive && (
                  <span className="rounded-full bg-rust-500/15 px-2 py-0.5 font-mono text-[0.65rem] uppercase tracking-wide text-rust-400">
                    Live above
                  </span>
                )}
              </div>
              <span className="font-mono text-sm tabular-nums text-parchment-200/70">
                {model.accuracy.toFixed(2)}%
                <span className="ml-2 text-parchment-200/40">
                  P {model.precision.toFixed(2)} · R {model.recall.toFixed(2)} · F1 {model.f1}%
                </span>
              </span>
            </div>
            <div className="h-2.5 overflow-hidden rounded-full bg-parchment-100/10">
              <motion.div
                className="h-full rounded-full"
                style={{ backgroundColor: SERIES_COLOR[model.id] }}
                initial={{ width: 0 }}
                whileInView={{ width: `${(model.accuracy / maxAccuracy) * 100}%` }}
                viewport={{ once: true }}
                transition={{ duration: 0.9, ease: [0.16, 1, 0.3, 1] }}
              />
            </div>
            <p className="mt-2 text-sm leading-relaxed text-parchment-200/50">{model.blurb}</p>
          </RevealItem>
        ))}
      </RevealGroup>

      <p className="mt-8 text-xs text-parchment-200/40">
        Accuracy, precision, and recall are validation-set figures from Table I of the
        paper. ResNet-50 additionally scored 85% and ConvNeXt-XLarge+MLP 90.32% on the
        held-out test set.
      </p>
    </div>
  );
}
