"use client";

function scrollToTop() {
  window.scrollTo({ top: 0, behavior: "smooth" });
}

export function Footer() {
  return (
    <footer className="border-t border-parchment-100/10 bg-canopy-950 py-10">
      <div className="section-shell flex flex-col items-center gap-4 text-center sm:flex-row sm:justify-between sm:text-left">
        <div>
          <p className="font-serif text-lg text-parchment-100">Hanish Acharla</p>
          <p className="mt-1 text-sm text-parchment-200/50">
            Apple leaf disease research, made interactive.
          </p>
        </div>
        <div className="flex flex-col items-center gap-2 sm:items-end">
          <a
            href="mailto:1079407@lammersvilleusd.net"
            className="text-sm text-parchment-200/60 hover:text-parchment-100"
          >
            1079407@lammersvilleusd.net
          </a>
          <button
            onClick={scrollToTop}
            className="text-xs text-parchment-200/40 hover:text-parchment-200/70"
          >
            Back to top ↑
          </button>
        </div>
      </div>
    </footer>
  );
}
