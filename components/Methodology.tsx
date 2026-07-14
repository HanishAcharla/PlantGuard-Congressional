import { SectionHeading } from "./SectionHeading";
import { Reveal, RevealGroup, RevealItem } from "./Reveal";

const lanes = [
  {
    id: "resnet",
    title: "Fine-Tuning",
    model: "ResNet-50",
    accent: "border-canopy-400/40 bg-canopy-400/5",
    dot: "bg-canopy-400",
    steps: [
      {
        title: "Load pretrained ResNet-50",
        detail: "ImageNet weights, 50-layer residual architecture.",
      },
      {
        title: "Freeze base, add a custom head",
        detail: "Global average pooling → dense ReLU → dense softmax (6 classes).",
      },
      {
        title: "Sweep learning rate & epochs",
        detail: "lr ∈ {0.01, 0.001, 0.0001}, epochs ∈ {10…50}, early stopping on val loss.",
      },
      {
        title: "Best config: lr = 0.0001, 10 epochs",
        detail: "86.50% validation accuracy — this is the model running in the live demo.",
      },
    ],
  },
  {
    id: "convnext",
    title: "Featurization",
    model: "ConvNeXt-XLarge",
    accent: "border-rust-500/40 bg-rust-500/5",
    dot: "bg-rust-500",
    steps: [
      {
        title: "Load pretrained ConvNeXt-XLarge",
        detail: "ImageNet weights, depthwise convolutions for efficiency.",
      },
      {
        title: "Extract 2048-d feature vectors",
        detail: "Global average pooling collapses each image to one dense embedding.",
      },
      {
        title: "Train shallow classifiers",
        detail: "KNN (k=13), Random Forest (100 trees, depth 7), MLP (lr=0.001, 160 iters).",
      },
      {
        title: "Best config: ConvNeXt + MLP",
        detail: "87.50% validation accuracy — the paper's top performer.",
      },
    ],
  },
];

export function Methodology() {
  return (
    <section id="methodology" className="relative bg-canopy-950 py-28 sm:py-36">
      <div className="section-shell">
        <SectionHeading
          kicker="Methodology"
          title="Two ways to squeeze a prediction out of a pretrained network."
          description="The paper compares full fine-tuning against a lighter featurization approach — trading compute for a shot at higher accuracy."
        />

        <Reveal delay={0.1}>
          <div className="mx-auto mt-14 max-w-md rounded-2xl border border-parchment-100/15 bg-canopy-900/60 px-6 py-5 text-center">
            <p className="font-mono text-xs uppercase tracking-widest text-parchment-200/50">Dataset</p>
            <p className="mt-2 font-serif text-xl text-parchment-50">Plant Pathology 2021 (FGVC8)</p>
            <p className="mt-1 text-sm text-parchment-200/60">
              17,826 images · split 14,288 / 1,790 / 1,748 (train / val / test)
            </p>
          </div>
        </Reveal>

        <div className="mt-10 grid gap-6 md:grid-cols-2">
          {lanes.map((lane, laneIdx) => (
            <RevealGroup key={lane.id} className="relative" stagger={0.1}>
              <RevealItem>
                <div className={`mb-6 rounded-xl border px-5 py-4 ${lane.accent}`}>
                  <p className="font-mono text-xs uppercase tracking-widest text-parchment-200/60">
                    {lane.title}
                  </p>
                  <p className="mt-1 font-serif text-2xl text-parchment-50">{lane.model}</p>
                </div>
              </RevealItem>

              <div className="relative border-l border-parchment-100/15 pl-6">
                {lane.steps.map((step, i) => (
                  <RevealItem key={step.title} className="relative pb-8 last:pb-0">
                    <span
                      className={`absolute -left-[1.9rem] top-1 h-3 w-3 rounded-full ring-4 ring-canopy-950 ${lane.dot}`}
                    />
                    <p className="font-medium text-parchment-100">{step.title}</p>
                    <p className="mt-1 text-sm leading-relaxed text-parchment-200/60">
                      {step.detail}
                    </p>
                  </RevealItem>
                ))}
              </div>
            </RevealGroup>
          ))}
        </div>

        <Reveal delay={0.15}>
          <div className="mx-auto mt-4 max-w-md rounded-2xl border border-parchment-100/15 bg-canopy-900/60 px-6 py-5 text-center">
            <p className="font-mono text-xs uppercase tracking-widest text-parchment-200/50">
              Evaluation
            </p>
            <p className="mt-2 text-sm text-parchment-200/70">
              Both branches are scored on the same held-out test set with accuracy,
              precision, recall, and F1 — see the results below.
            </p>
          </div>
        </Reveal>
      </div>
    </section>
  );
}
