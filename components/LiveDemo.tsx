"use client";

import { useCallback, useEffect, useRef, useState } from "react";
import type * as tfTypes from "@tensorflow/tfjs";
import { motion, AnimatePresence, useInView } from "framer-motion";
import { loadModel, classify, type Prediction } from "@/lib/model";
import { CLASS_INFO } from "@/lib/data/classes";
import { SectionHeading } from "./SectionHeading";
import { Reveal } from "./Reveal";
import { LockIcon, UploadIcon } from "./icons";

const toneStyles: Record<string, { bar: string; text: string; chip: string }> = {
  healthy: { bar: "bg-canopy-400", text: "text-canopy-300", chip: "bg-canopy-400/15 text-canopy-300" },
  disease: { bar: "bg-rust-500", text: "text-rust-400", chip: "bg-rust-500/15 text-rust-400" },
  mixed: { bar: "bg-amber-500", text: "text-amber-400", chip: "bg-amber-500/15 text-amber-400" },
};

export function LiveDemo() {
  const [modelReady, setModelReady] = useState(false);
  const [modelError, setModelError] = useState<string | null>(null);
  const [progress, setProgress] = useState(0);
  const [imageSrc, setImageSrc] = useState<string | null>(null);
  const [imageReadyTick, setImageReadyTick] = useState(0);
  const [predicting, setPredicting] = useState(false);
  const [predictions, setPredictions] = useState<Prediction[] | null>(null);
  const [inferenceError, setInferenceError] = useState<string | null>(null);
  const [dragActive, setDragActive] = useState(false);
  const [inferenceMs, setInferenceMs] = useState<number | null>(null);

  const modelRef = useRef<tfTypes.GraphModel | null>(null);
  const imgRef = useRef<HTMLImageElement>(null);
  const fileInputRef = useRef<HTMLInputElement>(null);
  const sectionRef = useRef<HTMLElement>(null);
  const startedLoadingRef = useRef(false);
  // Only start pulling down the ~46MB model (and compiling its WebGL shaders) once
  // this section is actually about to be seen — keeps the hero's entrance animation
  // smooth instead of fighting the model warm-up for the main thread on page load.
  const sectionInView = useInView(sectionRef, { once: true, margin: "400px" });

  const startLoadingModel = useCallback(() => {
    if (startedLoadingRef.current) return;
    startedLoadingRef.current = true;
    loadModel((fraction) => setProgress(fraction))
      .then((model) => {
        modelRef.current = model;
        setModelReady(true);
      })
      .catch((err) => {
        console.error(err);
        setModelError("Couldn't load the model. Check your connection and reload the page.");
      });
  }, []);

  useEffect(() => {
    // Anchor links (e.g. a shared "#demo" URL) can land the section in view before
    // this effect's IntersectionObserver ever attaches, so it never fires — fall
    // back to starting the load unconditionally once mounted, on top of the
    // scroll-triggered path below.
    if (sectionRef.current && sectionRef.current.getBoundingClientRect().top < window.innerHeight) {
      startLoadingModel();
    }
  }, [startLoadingModel]);

  useEffect(() => {
    if (sectionInView) startLoadingModel();
  }, [sectionInView, startLoadingModel]);

  const runInference = useCallback(async () => {
    if (!modelRef.current || !imgRef.current) return;
    setPredicting(true);
    setInferenceError(null);
    const start = performance.now();
    try {
      const result = await classify(modelRef.current, imgRef.current);
      setPredictions(result);
      setInferenceMs(Math.round(performance.now() - start));
    } catch (err) {
      console.error(err);
      setInferenceError("Couldn't analyze that image — try a different photo.");
    } finally {
      setPredicting(false);
    }
  }, []);

  useEffect(() => {
    if (modelReady && imageReadyTick > 0) {
      runInference();
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [modelReady, imageReadyTick]);

  const handleFile = useCallback(
    (file: File | undefined | null) => {
      if (!file) return;
      if (!file.type.startsWith("image/")) {
        setInferenceError("Please upload an image file (JPG or PNG).");
        return;
      }
      startLoadingModel();
      setInferenceError(null);
      setPredictions(null);
      const reader = new FileReader();
      reader.onload = () => setImageSrc(reader.result as string);
      reader.readAsDataURL(file);
    },
    [startLoadingModel]
  );

  const topPrediction = predictions?.[0];
  const topInfo = topPrediction ? CLASS_INFO[topPrediction.classId] : null;
  const topTone = topInfo ? toneStyles[topInfo.tone] : null;

  return (
    <section id="demo" ref={sectionRef} className="relative bg-canopy-900 py-28 sm:py-36">
      <div className="section-shell">
        <SectionHeading
          kicker="Live Demo"
          title="Upload a leaf. Watch the model think."
          description="This runs the real fine-tuned ResNet-50 from the paper, converted to TensorFlow.js. Everything happens on your device — nothing is uploaded anywhere."
        />

        <div className="mt-14 grid gap-8 lg:grid-cols-5">
          {/* Upload / preview panel */}
          <Reveal className="lg:col-span-2">
            <div
              onDragOver={(e) => {
                e.preventDefault();
                setDragActive(true);
              }}
              onDragLeave={() => setDragActive(false)}
              onDrop={(e) => {
                e.preventDefault();
                setDragActive(false);
                handleFile(e.dataTransfer.files?.[0]);
              }}
              onClick={() => fileInputRef.current?.click()}
              className={`group relative flex h-full min-h-[22rem] cursor-pointer flex-col items-center justify-center overflow-hidden rounded-2xl border-2 border-dashed p-6 text-center transition-colors ${
                dragActive
                  ? "border-rust-400 bg-rust-500/5"
                  : "border-parchment-100/15 bg-canopy-950/40 hover:border-parchment-100/30"
              }`}
            >
              <input
                ref={fileInputRef}
                type="file"
                accept="image/*"
                className="hidden"
                onChange={(e) => handleFile(e.target.files?.[0])}
              />

              <AnimatePresence mode="wait">
                {imageSrc ? (
                  <motion.img
                    key={imageSrc}
                    ref={imgRef}
                    src={imageSrc}
                    alt="Uploaded leaf"
                    initial={{ opacity: 0, scale: 0.97 }}
                    animate={{ opacity: 1, scale: 1 }}
                    onLoad={() => setImageReadyTick((t) => t + 1)}
                    className="absolute inset-0 h-full w-full object-cover"
                  />
                ) : (
                  <motion.div
                    key="placeholder"
                    initial={{ opacity: 0 }}
                    animate={{ opacity: 1 }}
                    className="flex flex-col items-center gap-3 text-parchment-200/60"
                  >
                    <UploadIcon className="h-8 w-8 text-parchment-200/40 transition-colors group-hover:text-rust-400" />
                    <p className="font-medium text-parchment-100/80">
                      Drop an apple leaf photo here
                    </p>
                    <p className="text-sm">or click to browse — JPG or PNG</p>
                  </motion.div>
                )}
              </AnimatePresence>

              {imageSrc && (
                <div className="absolute inset-x-0 bottom-0 flex justify-center bg-gradient-to-t from-canopy-950/90 to-transparent p-4">
                  <span className="rounded-full bg-canopy-950/80 px-4 py-1.5 text-xs text-parchment-100/80 backdrop-blur">
                    Click to try a different photo
                  </span>
                </div>
              )}
            </div>

            <div className="mt-4 flex items-center gap-2 text-xs text-parchment-200/50">
              <LockIcon className="h-4 w-4 shrink-0" />
              Runs 100% client-side. Your photo never leaves this device.
            </div>
          </Reveal>

          {/* Results panel */}
          <Reveal delay={0.1} className="lg:col-span-3">
            <div className="flex h-full min-h-[22rem] flex-col rounded-2xl border border-parchment-100/10 bg-canopy-950/60 p-6 sm:p-8">
              {!modelReady && !modelError && (
                <div className="flex flex-1 flex-col items-center justify-center gap-4 text-center">
                  <div className="h-1.5 w-48 overflow-hidden rounded-full bg-parchment-100/10">
                    <motion.div
                      className="h-full bg-rust-500"
                      animate={{ width: `${Math.max(4, progress * 100)}%` }}
                      transition={{ ease: "easeOut" }}
                    />
                  </div>
                  <p className="text-sm text-parchment-200/60">
                    Loading the model — {Math.round(progress * 100)}%
                    <br />
                    <span className="text-xs text-parchment-200/40">
                      ~45MB, once per visit, then cached by your browser
                    </span>
                  </p>
                </div>
              )}

              {modelError && (
                <div className="flex flex-1 items-center justify-center text-center text-sm text-rust-400">
                  {modelError}
                </div>
              )}

              {modelReady && !imageSrc && (
                <div className="flex flex-1 items-center justify-center text-center text-sm text-parchment-200/50">
                  Model loaded and ready. Upload a photo to see live predictions.
                </div>
              )}

              {modelReady && imageSrc && predicting && (
                <div className="flex flex-1 flex-col items-center justify-center gap-3">
                  <div className="flex gap-1.5">
                    {[0, 1, 2].map((i) => (
                      <motion.span
                        key={i}
                        className="h-2 w-2 rounded-full bg-rust-400"
                        animate={{ opacity: [0.3, 1, 0.3] }}
                        transition={{ duration: 1, repeat: Infinity, delay: i * 0.15 }}
                      />
                    ))}
                  </div>
                  <p className="text-sm text-parchment-200/60">Running inference in your browser…</p>
                </div>
              )}

              {inferenceError && (
                <div className="flex flex-1 items-center justify-center text-center text-sm text-rust-400">
                  {inferenceError}
                </div>
              )}

              {predictions && !predicting && topInfo && topTone && (
                <motion.div
                  initial={{ opacity: 0, y: 12 }}
                  animate={{ opacity: 1, y: 0 }}
                  className="flex flex-1 flex-col"
                >
                  <div className="mb-6 flex items-start justify-between gap-4">
                    <div>
                      <span className={`inline-block rounded-full px-3 py-1 text-xs font-medium uppercase tracking-wide ${topTone.chip}`}>
                        Top prediction
                      </span>
                      <h3 className="mt-3 font-serif text-2xl text-parchment-50 sm:text-3xl">
                        {topInfo.label}
                      </h3>
                      <p className="mt-1 text-sm text-parchment-200/60">{topInfo.description}</p>
                    </div>
                    <div className="text-right">
                      <div className={`font-mono text-3xl ${topTone.text}`}>
                        {(topPrediction!.probability * 100).toFixed(1)}%
                      </div>
                      {inferenceMs !== null && (
                        <div className="mt-1 text-xs text-parchment-200/40">{inferenceMs}ms</div>
                      )}
                    </div>
                  </div>

                  <div className="mt-auto space-y-3">
                    {predictions.map((p) => {
                      const info = CLASS_INFO[p.classId];
                      const tone = toneStyles[info.tone];
                      return (
                        <div key={p.classId}>
                          <div className="mb-1 flex justify-between text-xs">
                            <span className="text-parchment-200/70">{info.label}</span>
                            <span className="font-mono text-parchment-200/50">
                              {(p.probability * 100).toFixed(1)}%
                            </span>
                          </div>
                          <div className="h-2 overflow-hidden rounded-full bg-parchment-100/10">
                            <motion.div
                              className={`h-full rounded-full ${tone.bar}`}
                              initial={{ width: 0 }}
                              animate={{ width: `${p.probability * 100}%` }}
                              transition={{ duration: 0.8, ease: [0.16, 1, 0.3, 1] }}
                            />
                          </div>
                        </div>
                      );
                    })}
                  </div>
                </motion.div>
              )}
            </div>
          </Reveal>
        </div>
      </div>
    </section>
  );
}
