import type { Metadata } from "next";
import { Fraunces, Inter, JetBrains_Mono } from "next/font/google";
import "./globals.css";

const fraunces = Fraunces({
  subsets: ["latin"],
  variable: "--font-fraunces",
  weight: ["400", "500", "600"],
  style: ["normal", "italic"],
  display: "swap",
});

const inter = Inter({
  subsets: ["latin"],
  variable: "--font-inter",
  display: "swap",
});

const jetbrainsMono = JetBrains_Mono({
  subsets: ["latin"],
  variable: "--font-jetbrains",
  display: "swap",
});

export const metadata: Metadata = {
  title: "Foliage — AI Apple Leaf Disease Detection",
  description:
    "An interactive showcase of a ResNet-50 & ConvNeXt research pipeline for apple leaf disease classification. Upload a leaf photo and run the real model, live, in your browser.",
  metadataBase: new URL("https://example.com"),
  openGraph: {
    title: "Foliage — AI Apple Leaf Disease Detection",
    description:
      "Run a real research-grade CNN on your own apple leaf photos, entirely client-side.",
    type: "website",
  },
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en" className={`${fraunces.variable} ${inter.variable} ${jetbrainsMono.variable}`}>
      <body className="font-sans antialiased">{children}</body>
    </html>
  );
}
