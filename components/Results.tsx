import { SectionHeading } from "./SectionHeading";
import { Reveal } from "./Reveal";
import { ResultsChart } from "./ResultsChart";
import { ConfusionMatrix } from "./ConfusionMatrix";

export function Results() {
  return (
    <section id="results" className="relative bg-canopy-900 py-28 sm:py-36">
      <div className="section-shell">
        <SectionHeading
          kicker="Results"
          title="Featurization edged out fine-tuning — barely."
          description="ConvNeXt-XLarge's feature vectors, fed into a small MLP, beat full ResNet-50 fine-tuning on every metric — while costing a fraction of the compute. Here's the full comparison from the paper."
        />

        <div className="mt-14">
          <ResultsChart />
        </div>

        <div className="mt-20">
          <Reveal>
            <h3 className="font-serif text-2xl text-parchment-50 sm:text-3xl">
              Where each model gets confused
            </h3>
            <p className="mt-3 max-w-2xl text-parchment-200/60">
              Both models mix up Complex (multi-disease) leaves with Scab and Frog Eye
              Leaf Spot most often — the same subtle, overlapping symptoms that make this
              hard for human inspectors too.
            </p>
          </Reveal>
          <div className="mt-8">
            <ConfusionMatrix />
          </div>
        </div>
      </div>
    </section>
  );
}
