import { AnimatedNumber } from "./AnimatedNumber";
import { Reveal, RevealGroup, RevealItem } from "./Reveal";
import { SectionHeading } from "./SectionHeading";
import { PROBLEM_STATS } from "@/lib/data/results";

export function ProblemStatement() {
  return (
    <section id="problem" className="relative bg-canopy-950 py-28 sm:py-36">
      <div className="section-shell">
        <SectionHeading
          kicker="The Problem"
          title="Farmers still diagnose disease by eye."
          description="Apples are the world's third most produced fruit, worth over $23B a year in the US alone — yet the most common way to catch scab, rust, or fireblight is still a human walking the rows. That's slow, inconsistent, and often too late."
        />

        <RevealGroup className="mt-16 grid grid-cols-2 gap-px overflow-hidden rounded-2xl bg-parchment-100/10 sm:grid-cols-4">
          {PROBLEM_STATS.map((stat) => (
            <RevealItem key={stat.label} className="bg-canopy-950 px-6 py-10">
              <div className="font-serif text-4xl text-parchment-50 sm:text-5xl">
                {stat.prefix}
                <AnimatedNumber
                  value={stat.value}
                  decimals={stat.value % 1 !== 0 ? 2 : 0}
                />
                {stat.suffix}
              </div>
              <p className="mt-3 text-sm leading-snug text-parchment-200/60">
                {stat.label}
              </p>
            </RevealItem>
          ))}
        </RevealGroup>

        <Reveal delay={0.1}>
          <div className="mt-12 rounded-2xl border border-rust-500/20 bg-rust-500/5 px-6 py-6 sm:px-8">
            <p className="font-serif text-lg italic leading-relaxed text-parchment-100/90 sm:text-xl">
              &ldquo;The Fireblight outbreak in Michigan led to the loss of over 220,000
              apple trees and $42 million in damages.&rdquo;
            </p>
            <p className="mt-3 font-mono text-xs uppercase tracking-wider text-parchment-200/50">
              Norelli, Jones & Aldwinckle, Plant Disease (2003)
            </p>
          </div>
        </Reveal>
      </div>
    </section>
  );
}
