import { Hero } from "@/components/Hero";
import { ProblemStatement } from "@/components/ProblemStatement";
import { LiveDemo } from "@/components/LiveDemo";
import { Methodology } from "@/components/Methodology";
import { Results } from "@/components/Results";
import { PaperSection } from "@/components/PaperSection";
import { Footer } from "@/components/Footer";

export default function Home() {
  return (
    <main>
      <Hero />
      <ProblemStatement />
      <LiveDemo />
      <Methodology />
      <Results />
      <PaperSection />
      <Footer />
    </main>
  );
}
