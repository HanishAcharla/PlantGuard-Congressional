import { Reveal } from "./Reveal";

export function SectionHeading({
  kicker,
  title,
  description,
  align = "left",
  tone = "light",
}: {
  kicker: string;
  title: string;
  description?: string;
  align?: "left" | "center";
  tone?: "light" | "dark";
}) {
  return (
    <div className={align === "center" ? "text-center" : "text-left"}>
      <Reveal>
        <span
          className={`inline-flex items-center gap-2 font-mono text-xs uppercase tracking-[0.25em] ${
            tone === "light" ? "text-rust-400" : "text-rust-600"
          }`}
        >
          <span className="h-px w-6 bg-current" />
          {kicker}
        </span>
      </Reveal>
      <Reveal delay={0.08}>
        <h2
          className={`mt-4 font-serif text-3xl sm:text-4xl md:text-5xl leading-[1.1] text-balance ${
            tone === "light" ? "text-parchment-50" : "text-canopy-950"
          }`}
        >
          {title}
        </h2>
      </Reveal>
      {description && (
        <Reveal delay={0.16}>
          <p
            className={`mt-4 max-w-2xl text-base sm:text-lg leading-relaxed ${
              align === "center" ? "mx-auto" : ""
            } ${tone === "light" ? "text-parchment-200/80" : "text-canopy-800/80"}`}
          >
            {description}
          </p>
        </Reveal>
      )}
    </div>
  );
}
