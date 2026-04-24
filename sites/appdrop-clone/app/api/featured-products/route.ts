import { NextResponse } from "next/server";

type GraphQLImageValue = {
  url?: string;
  thumbnail?: string;
};

type FeaturedProductRow = {
  id?: string | number;
  listingCode?: string | null;
  name?: string;
  price?: number;
  discountPrice?: string | null;
  imagesUrl?: string[];
  brand?: { name?: string | null } | null;
  seller?: { username?: string | null } | null;
};

type FeaturedResponse = {
  discoverFeaturedProducts?: FeaturedProductRow[];
};

const QUERY = `
  query DiscoverFeaturedProducts {
    discoverFeaturedProducts {
      id
      listingCode
      name
      price
      discountPrice
      imagesUrl
      brand { name }
      seller { username }
    }
  }
`;

function extractImageURL(imagesUrl?: string[]): string | null {
  if (!imagesUrl || imagesUrl.length === 0) return null;
  for (const entry of imagesUrl) {
    if (!entry) continue;
    if (entry.startsWith("http://") || entry.startsWith("https://")) return entry;
    try {
      const parsed = JSON.parse(entry) as GraphQLImageValue;
      if (parsed.url && (parsed.url.startsWith("http://") || parsed.url.startsWith("https://"))) {
        return parsed.url;
      }
      if (parsed.thumbnail && (parsed.thumbnail.startsWith("http://") || parsed.thumbnail.startsWith("https://"))) {
        return parsed.thumbnail;
      }
    } catch {
      // Ignore malformed JSON entries and continue scanning.
    }
  }
  return null;
}

function resolvePrice(price?: number, discountPrice?: string | null): number {
  const base = typeof price === "number" ? price : 0;
  if (!discountPrice) return base;
  const discount = Number(discountPrice);
  if (!Number.isFinite(discount) || discount <= 0) return base;
  return Math.max(0, base - (base * discount) / 100);
}

export async function GET() {
  try {
    const response = await fetch("https://prelura.voltislabs.uk/graphql/", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ query: QUERY }),
      cache: "no-store",
    });

    if (!response.ok) {
      return NextResponse.json({ items: [] }, { status: 200 });
    }

    const payload = (await response.json()) as { data?: FeaturedResponse };
    const rows = payload.data?.discoverFeaturedProducts ?? [];
    const items = rows
      .map((row) => ({
        id: String(row.id ?? ""),
        listingCode: row.listingCode?.trim() || null,
        name: (row.name ?? "").trim(),
        price: resolvePrice(row.price, row.discountPrice),
        brand: row.brand?.name?.trim() || null,
        seller: row.seller?.username?.trim() || null,
        image: extractImageURL(row.imagesUrl),
      }))
      .filter((item) => item.id && item.name && item.image);

    return NextResponse.json({ items }, { status: 200 });
  } catch {
    return NextResponse.json({ items: [] }, { status: 200 });
  }
}
