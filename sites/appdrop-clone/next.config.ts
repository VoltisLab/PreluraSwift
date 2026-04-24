import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  devIndicators: false,
  // Framer CDN URLs can time out via the default optimizer in dev; serve originals for a stable clone.
  images: {
    unoptimized: true,
    remotePatterns: [
      { protocol: "https", hostname: "framerusercontent.com", pathname: "/**" },
      { protocol: "https", hostname: "fonts.gstatic.com", pathname: "/**" },
      { protocol: "https", hostname: "mywearhouse.co.uk", pathname: "/**" },
      { protocol: "https", hostname: "**.voltislabs.uk", pathname: "/**" },
      { protocol: "https", hostname: "**.amazonaws.com", pathname: "/**" },
      { protocol: "https", hostname: "**.cloudfront.net", pathname: "/**" },
    ],
  },
  // Omit `allowedDevOrigins` unless you add extra dev hosts; when set, Next blocks `/_next/*`
  // for disallowed origins (use hostname only, e.g. `127.0.0.1` — not `http://127.0.0.1:3010`).
};

export default nextConfig;
