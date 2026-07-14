function hexToRgb(hex: string) {
  const n = parseInt(hex.replace("#", ""), 16);
  return { r: (n >> 16) & 255, g: (n >> 8) & 255, b: n & 255 };
}

function rgbToHex(r: number, g: number, b: number) {
  return (
    "#" +
    [r, g, b]
      .map((v) => Math.round(v).toString(16).padStart(2, "0"))
      .join("")
  );
}

// Sequential single-hue ramp (rust), validated for the dark canopy surface.
// Low counts recede toward the surface; high counts read as vivid rust.
const COLD = "#171310";
const HOT = "#c96a35";

export function heatColor(value: number, max: number): string {
  const t = max <= 0 ? 0 : Math.sqrt(Math.max(0, value) / max);
  const cold = hexToRgb(COLD);
  const hot = hexToRgb(HOT);
  return rgbToHex(
    cold.r + (hot.r - cold.r) * t,
    cold.g + (hot.g - cold.g) * t,
    cold.b + (hot.b - cold.b) * t
  );
}
