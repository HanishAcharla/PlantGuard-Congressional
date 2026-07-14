"use client";

import { motion } from "framer-motion";

function scrollTo(id: string) {
  document.getElementById(id)?.scrollIntoView({ behavior: "smooth" });
}

export function Hero() {
  return (
    <section className="grain-overlay relative flex min-h-[100svh] flex-col justify-between overflow-hidden bg-canopy-950">
      {/* organic gradient blobs */}
      <div className="pointer-events-none absolute inset-0 overflow-hidden">
        <div className="animate-drift absolute -left-32 -top-40 h-[32rem] w-[32rem] rounded-full bg-canopy-500/25 blur-[110px]" />
        <div className="animate-drift-slow absolute -right-24 top-10 h-[28rem] w-[28rem] rounded-full bg-rust-500/15 blur-[110px]" />
        <div className="animate-drift-slow absolute bottom-[-10rem] left-1/3 h-[26rem] w-[26rem] rounded-full bg-moss-400/10 blur-[120px]" />
      </div>

      <div className="section-shell relative flex flex-1 flex-col justify-center pt-32 pb-16">
        <motion.span
          initial={{ opacity: 0, y: 12 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.6 }}
          className="font-mono text-xs uppercase tracking-[0.3em] text-rust-400"
        >
          Research Showcase · IEEE SusTech
        </motion.span>

        <motion.h1
          initial={{ opacity: 0, y: 24 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.8, delay: 0.1, ease: [0.16, 1, 0.3, 1] }}
          className="mt-6 max-w-4xl font-serif text-[2.75rem] leading-[1.05] text-parchment-50 text-balance sm:text-6xl md:text-[5rem]"
        >
          Reading the leaf,{" "}
          <span className="italic text-canopy-300">before the orchard</span> feels it.
        </motion.h1>

        <motion.p
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.8, delay: 0.25 }}
          className="mt-6 max-w-xl text-lg leading-relaxed text-parchment-200/80"
        >
          A fine-tuned ResNet-50, trained on 17,826 apple leaf images, running live in your
          browser. Upload a photo and watch a real research model tell scab from rust
          from a healthy leaf — no server, no upload to the cloud, just math in your tab.
        </motion.p>

        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.8, delay: 0.4 }}
          className="mt-10 flex flex-wrap items-center gap-4"
        >
          <button
            onClick={() => scrollTo("demo")}
            className="group relative overflow-hidden rounded-full bg-rust-500 px-7 py-3.5 font-medium text-parchment-50 shadow-[0_8px_30px_-8px_rgba(201,106,53,0.6)] transition-transform hover:scale-[1.03] active:scale-[0.98]"
          >
            <span className="relative z-10">Try the model</span>
            <span className="absolute inset-0 -z-0 bg-rust-600 opacity-0 transition-opacity group-hover:opacity-100" />
          </button>
          <button
            onClick={() => scrollTo("paper")}
            className="rounded-full border border-parchment-100/20 px-7 py-3.5 font-medium text-parchment-100 transition-colors hover:border-parchment-100/50 hover:bg-parchment-100/5"
          >
            Read the research
          </button>
        </motion.div>
      </div>

      <div className="section-shell relative flex items-center justify-between pb-10 text-sm text-parchment-200/50">
        <span>Hanish Acharla · Mountain House High School</span>
        <motion.button
          onClick={() => scrollTo("problem")}
          animate={{ y: [0, 8, 0] }}
          transition={{ duration: 1.8, repeat: Infinity, ease: "easeInOut" }}
          aria-label="Scroll to learn more"
          className="flex h-10 w-10 items-center justify-center rounded-full border border-parchment-100/20 text-parchment-100/70 hover:border-parchment-100/50"
        >
          ↓
        </motion.button>
      </div>
    </section>
  );
}
