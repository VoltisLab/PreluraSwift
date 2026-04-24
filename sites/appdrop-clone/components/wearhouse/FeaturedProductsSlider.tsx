"use client";

import Image from "next/image";
import { useEffect, useMemo, useState } from "react";
import { WEARHOUSE } from "./site";

type FeaturedItem = {
  id: string;
  listingCode: string | null;
  name: string;
  price: number;
  brand: string | null;
  seller: string | null;
  image: string;
};

function formatGBP(value: number): string {
  return new Intl.NumberFormat("en-GB", { style: "currency", currency: "GBP", maximumFractionDigits: 0 }).format(value);
}

export function FeaturedProductsSlider() {
  const [items, setItems] = useState<FeaturedItem[]>([]);

  useEffect(() => {
    let mounted = true;
    const run = async () => {
      try {
        const response = await fetch("/api/featured-products", { cache: "no-store" });
        if (!response.ok) return;
        const data = (await response.json()) as { items?: FeaturedItem[] };
        if (!mounted) return;
        const next = (data.items ?? []).filter((item) => item.image && item.name);
        setItems(next.slice(0, 12));
      } catch {
        // Keep section hidden when unavailable.
      }
    };
    run();
    return () => {
      mounted = false;
    };
  }, []);

  const loopItems = useMemo(() => {
    if (items.length === 0) return [];
    return [...items, ...items];
  }, [items]);

  if (items.length === 0) return null;

  // 30% slower than previous speed.
  const durationSeconds = Math.max(18, items.length * 3 * 1.3);

  return (
    <div className="mt-8" aria-label="Featured products">
      <p className="mb-4 text-center text-sm font-semibold tracking-[-0.01em] text-[#AB28B2]">Featured products</p>
      <div className="group overflow-hidden [mask-image:linear-gradient(to_right,transparent,black_8%,black_92%,transparent)]">
        <div
          className="flex w-max gap-4 py-1 group-hover:[animation-play-state:paused]"
          style={{
            animation: `wearhouse-marquee ${durationSeconds}s linear infinite`,
          }}
        >
          {loopItems.map((item, index) => (
            <a
              key={`${item.id}-${index}`}
              href={`${WEARHOUSE.site}/item/${encodeURIComponent(item.listingCode || item.id)}`}
              className="block w-[200px] shrink-0 overflow-hidden rounded-2xl border border-black/10 bg-white shadow-sm transition hover:-translate-y-0.5"
            >
              <div className="relative aspect-[3/4] w-full bg-[#f6f6f6]">
                <Image src={item.image} alt={item.name} fill className="object-cover" sizes="200px" />
              </div>
              <div className="space-y-0.5 p-3">
                <p className="truncate text-xs font-semibold text-[#AB28B2]">{item.brand ?? "Featured"}</p>
                <p className="truncate text-sm font-semibold text-ink">{item.name}</p>
                <p className="text-sm font-medium text-ink">{formatGBP(item.price)}</p>
                <p className="truncate text-xs text-muted">@{item.seller ?? "wearhouse"}</p>
              </div>
            </a>
          ))}
        </div>
      </div>
      <style jsx>{`
        @keyframes wearhouse-marquee {
          from {
            transform: translateX(0);
          }
          to {
            transform: translateX(-50%);
          }
        }
      `}</style>
    </div>
  );
}
