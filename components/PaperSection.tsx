"use client";

import { useState } from "react";
import { Reveal } from "./Reveal";
import { SectionHeading } from "./SectionHeading";
import { DATASET_STATS } from "@/lib/data/results";

const CITATION = `H. Acharla, "Data-Driven Solutions in Agriculture: Machine Learning for
Apple Disease Classification," IEEE SusTech.`;

export function PaperSection() {
  const [copied, setCopied] = useState(false);

  return (
    <section id="paper" className="relative bg-canopy-950 py-28 sm:py-36">
      <div className="section-shell">
        <div className="grid gap-14 lg:grid-cols-5">
          <div className="lg:col-span-3">
            <SectionHeading
              kicker="The Research"
              title="Data-Driven Solutions in Agriculture"
              description="Published at IEEE SusTech. This work compares fine-tuning against feature-extraction pipelines for classifying apple leaf disease, using the Plant Pathology dataset."
            />

            <Reveal delay={0.15}>
              <div className="mt-8 space-y-4 text-parchment-200/75">
                <p className="leading-relaxed">
                  Visual inspection is still the primary way orchards catch disease —
                  slow, inconsistent, and dependent on a farmer&rsquo;s experience. This
                  paper asks whether a pretrained CNN can do better, comparing two
                  strategies: fine-tuning ResNet-50 end-to-end, versus extracting
                  ConvNeXt-XLarge feature embeddings and classifying them with a
                  lightweight model.
                </p>
                <p className="leading-relaxed">
                  Trained and evaluated on {DATASET_STATS.totalImages.toLocaleString()}{" "}
                  images across {DATASET_STATS.finalCategories} disease categories, the
                  featurization approach — ConvNeXt-XLarge embeddings classified by a
                  multilayer perceptron — came out ahead, reaching 90.32% test accuracy
                  versus ResNet-50&rsquo;s 85%, while requiring far less compute to train.
                </p>
              </div>
            </Reveal>

            <Reveal delay={0.2}>
              <div className="mt-8 flex flex-wrap gap-4">
                <a
                  href="/paper.pdf"
                  download
                  className="inline-flex items-center gap-2 rounded-full bg-parchment-100 px-6 py-3 font-medium text-canopy-950 transition-transform hover:scale-[1.03] active:scale-[0.98]"
                >
                  Download the full paper (PDF)
                </a>
              </div>
            </Reveal>
          </div>

          <Reveal delay={0.1} className="lg:col-span-2">
            <div className="rounded-2xl border border-parchment-100/10 bg-canopy-900/60 p-6">
              <p className="font-mono text-xs uppercase tracking-widest text-parchment-200/50">
                Author
              </p>
              <p className="mt-2 font-serif text-xl text-parchment-50">Hanish Acharla</p>
              <p className="text-sm text-parchment-200/60">Mountain House High School</p>

              <div className="mt-6 border-t border-parchment-100/10 pt-6">
                <p className="font-mono text-xs uppercase tracking-widest text-parchment-200/50">
                  Cite this work
                </p>
                <pre className="thin-scroll mt-3 overflow-x-auto rounded-lg bg-canopy-950/70 p-4 font-mono text-xs leading-relaxed text-parchment-200/80">
{CITATION}
                </pre>
                <button
                  onClick={() => {
                    navigator.clipboard.writeText(CITATION);
                    setCopied(true);
                    setTimeout(() => setCopied(false), 1800);
                  }}
                  className="mt-3 text-xs font-medium text-rust-400 hover:text-rust-300"
                >
                  {copied ? "Copied ✓" : "Copy citation"}
                </button>
              </div>
            </div>
          </Reveal>
        </div>
      </div>
    </section>
  );
}
