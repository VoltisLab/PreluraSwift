import type { Metadata } from "next";
import { DM_Sans, Inter } from "next/font/google";
import { WearhouseCoverFooter } from "@/components/wearhouse/WearhouseCoverFooter";
import "./globals.css";

const inter = Inter({
  subsets: ["latin"],
  variable: "--font-inter",
  display: "swap",
});
const dmSans = DM_Sans({
  subsets: ["latin"],
  weight: ["500", "600", "700"],
  variable: "--font-dm",
  display: "swap",
});

export const metadata: Metadata = {
  metadataBase: new URL("https://mywearhouse.co.uk"),
  title: "WEARHOUSE - preloved fashion marketplace",
  description:
    "Buy and sell quality second-hand clothes on WEARHOUSE. Browse mywearhouse.co.uk or use our app - listings, inbox, and checkout in one place.",
  openGraph: {
    title: "WEARHOUSE - preloved fashion marketplace",
    description:
      "Buy and sell quality second-hand clothes on WEARHOUSE. Browse mywearhouse.co.uk or use our app - listings, inbox, and checkout in one place.",
    url: "https://mywearhouse.co.uk",
    siteName: "WEARHOUSE",
    images: ["/phone-22.png"],
  },
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en" className={`${inter.variable} ${dmSans.variable}`}>
      <body className="min-h-screen bg-white font-sans text-ink antialiased">
        {children}
        <WearhouseCoverFooter />
      </body>
    </html>
  );
}
