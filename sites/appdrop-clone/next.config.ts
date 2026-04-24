import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  devIndicators: false,
  // Framer CDN URLs can time out via the default optimizer in dev; serve originals for a stable clone.
  images: {
    unoptimized: true,
    remotePatterns: [
      { protocol: "https", hostname: "framerusercontent.com", pathname: "/**" },
      { protocol: "https", hostname: "fonts.gstatic.com", pathname: "/**" },
    ],
  },
  allowedDevOrigins: ["http://127.0.0.1:3010", "http://localhost:3010"],
};

export default nextConfig;
