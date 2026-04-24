import type { ReactNode } from "react";
import Link from "next/link";

export const WEARHOUSE_COVER_NAV = [
  { label: "Why WEARHOUSE", href: "/#benefits" },
  { label: "Features", href: "/#features" },
  { label: "Reviews", href: "/#reviews" },
  { label: "Selling", href: "/#pricing" },
  { label: "FAQs", href: "/#faqs" },
] as const;

export function WearhouseLogo({ className = "" }: { className?: string }) {
  return (
    <span className={`inline-flex items-center ${className}`}>
      {/* eslint-disable-next-line @next/next/no-img-element -- SVG wordmark */}
      <img
        src="/wearhouse-wordmark.svg"
        alt="WEARHOUSE"
        className="h-[24px] w-auto max-w-[min(240px,58vw)] md:h-[26px]"
      />
    </span>
  );
}

type WearhouseCoverHeaderProps = {
  /** Log in / sign up / search - same bar, cover styling. */
  trailing?: ReactNode;
};

export function WearhouseCoverHeader({ trailing }: WearhouseCoverHeaderProps) {
  return (
    <header className="sticky top-0 z-50 border-b border-black/[0.06] bg-white/90 pt-[env(safe-area-inset-top)] backdrop-blur-md">
      <div className="mx-auto flex w-full max-w-screen-2xl min-[1680px]:max-w-none items-center justify-between gap-4 px-5 py-4 md:px-10">
        <Link href="/" className="flex min-w-0 shrink-0 items-center gap-2">
          <WearhouseLogo />
        </Link>

        <nav
          className="hidden flex-1 items-center justify-center gap-1 lg:flex"
          aria-label="Primary"
        >
          {WEARHOUSE_COVER_NAV.map((item) => (
            <Link
              key={item.href}
              href={item.href}
              className="rounded-full px-3.5 py-2 text-[0.9375rem] font-semibold text-[#171717]/85 transition hover:bg-black/[0.04]"
            >
              {item.label}
            </Link>
          ))}
          <Link
            href="/#download"
            className="rounded-full bg-[#AB28B2] px-4 py-2 text-[0.9375rem] font-semibold text-white shadow-sm transition hover:bg-[#8f1f96]"
          >
            Get the App
          </Link>
        </nav>

        <div className="flex shrink-0 items-center gap-1.5 sm:gap-2">
          {trailing}
          <Link
            href="/#download"
            className="rounded-full bg-[#AB28B2] px-3.5 py-2 text-sm font-semibold text-white shadow-sm transition hover:bg-[#8f1f96] lg:hidden"
          >
            Get the App
          </Link>
        </div>
      </div>
    </header>
  );
}
