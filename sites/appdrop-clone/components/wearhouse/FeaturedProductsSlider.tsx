"use client";

import Image from "next/image";
import type { CSSProperties } from "react";
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

function ProductCard({ item }: { item: FeaturedItem }) {
  return (
    <a
      href={`${WEARHOUSE.site}/item/${encodeURIComponent(item.listingCode || item.id)}`}
      className="block w-[200px] shrink-0 overflow-hidden rounded-2xl border border-black/10 bg-white shadow-sm transition hover:-translate-y-0.5"
    >
      <div className="relative aspect-[3/4] w-full bg-[#f6f6f6]">
        <Image
          src={item.image}
          alt={item.name}
          fill
          className="object-cover"
          sizes="200px"
        />
      </div>
      <div className="space-y-0.5 p-3">
        <p className="truncate text-xs font-semibold text-[#AB28B2]">{item.brand ?? "Featured"}</p>
        <p className="truncate text-sm font-semibold text-ink">{item.name}</p>
        <p className="text-sm font-medium text-ink">{formatGBP(item.price)}</p>
        <p className="truncate text-xs text-muted">@{item.seller ?? "wearhouse"}</p>
      </div>
    </a>
  );
}

type FeaturedProductsSliderProps = {
  className?: string;
};

export function FeaturedProductsSlider({ className = "" }: FeaturedProductsSliderProps) {
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

  const durationSeconds = useMemo(() => {
    if (items.length === 0) return 40;
    return Math.max(28, items.length * 3 * 1.2);
  }, [items.length]);

  if (items.length === 0) return null;

  const marqueeStyle = {
    ["--wmq-dur" as string]: `${durationSeconds}s`,
  } as CSSProperties;

  return (
    <div
      className={`mt-8 w-full ${className}`}
      aria-label="Featured products"
    >
      <p className="mb-4 text-center text-sm font-semibold tracking-[-0.01em] text-[#AB28B2]">Featured products</p>
      <div className="group overflow-hidden [mask-image:linear-gradient(to_right,transparent,black_6%,black_94%,transparent)]">
        <div className="inline-flex w-max wh-featured-marquee-track" style={marqueeStyle}>
          <div className="flex shrink-0 gap-4 py-1">
            {items.map((item) => (
              <ProductCard key={item.id} item={item} />
            ))}
          </div>
          <div className="flex shrink-0 gap-4 py-1" aria-hidden>
            {items.map((item) => (
              <ProductCard key={`dup-${item.id}`} item={item} />
            ))}
          </div>
        </div>
      </div>
    </div>
  );
}
