import Link from "next/link";
import { WearhouseLogo } from "./WearhouseCoverHeader";
import { WEARHOUSE } from "./site";

/** Shared marketing footer (cover style) — mount from `app/layout.tsx` so every route uses the same footer. */
export function WearhouseCoverFooter() {
  return (
    <footer className="border-t border-line bg-white px-5 py-14 md:px-10">
      <div className="mx-auto max-w-6xl">
        <div className="grid gap-10 md:grid-cols-[1fr_auto] md:items-start">
          <div>
            <Link href="/" className="inline-flex min-w-0 items-center gap-2">
              <WearhouseLogo />
            </Link>
            <p className="mt-4 max-w-sm text-sm leading-relaxed text-muted">
              WEARHOUSE is the preloved fashion marketplace from Voltis Labs - list, discover, and message in one place on mywearhouse.co.uk and in our mobile app.
            </p>
          </div>
          <div>
            <p className="text-xs font-semibold uppercase tracking-[0.2em] text-muted">Get the app</p>
            <div className="mt-4 flex flex-wrap items-center gap-4">
              <a href={WEARHOUSE.app} target="_blank" rel="noopener noreferrer" className="inline-block transition-opacity hover:opacity-90">
                {/* eslint-disable-next-line @next/next/no-img-element */}
                <img src="/badges/app-store.svg" alt="Download on the App Store" width={120} height={40} className="h-10 w-auto" />
              </a>
              <a href={WEARHOUSE.app} target="_blank" rel="noopener noreferrer" className="inline-block transition-opacity hover:opacity-90">
                {/* eslint-disable-next-line @next/next/no-img-element */}
                <img src="/badges/google-play.svg" alt="Get it on Google Play" width={135} height={40} className="h-10 w-auto" />
              </a>
            </div>
            <a
              href={WEARHOUSE.app}
              target="_blank"
              rel="noopener noreferrer"
              className="mt-4 inline-block text-sm font-semibold text-[#AB28B2] underline-offset-2 hover:underline"
            >
              Mobile Apps
            </a>
          </div>
        </div>

        <div className="mt-10 grid gap-10 border-t border-line pt-8 md:grid-cols-5">
          <div>
            <p className="text-xs font-semibold uppercase tracking-[0.2em] text-muted">Menu</p>
            <ul className="mt-4 space-y-2 text-sm text-muted">
              <li>
                <Link href="/#benefits" className="hover:text-ink">
                  Why WEARHOUSE
                </Link>
              </li>
              <li>
                <Link href="/#features" className="hover:text-ink">
                  Features
                </Link>
              </li>
              <li>
                <Link href="/#pricing" className="hover:text-ink">
                  Selling
                </Link>
              </li>
              <li>
                <Link href="/#download" className="hover:text-ink">
                  Get started
                </Link>
              </li>
            </ul>
          </div>

          <div>
            <p className="text-xs font-semibold uppercase tracking-[0.2em] text-muted">Wearhouse</p>
            <ul className="mt-4 space-y-2 text-sm text-muted">
              <li>
                <a href={WEARHOUSE.about} className="hover:text-ink" target="_blank" rel="noopener noreferrer">
                  About us
                </a>
              </li>
              <li>
                <a href={WEARHOUSE.about} className="hover:text-ink" target="_blank" rel="noopener noreferrer">
                  Sustainability
                </a>
              </li>
              <li>
                <a href={WEARHOUSE.about} className="hover:text-ink" target="_blank" rel="noopener noreferrer">
                  Press
                </a>
              </li>
              <li>
                <a href={WEARHOUSE.about} className="hover:text-ink" target="_blank" rel="noopener noreferrer">
                  Advertising
                </a>
              </li>
              <li>
                <a href={WEARHOUSE.helpDelivery} className="hover:text-ink" target="_blank" rel="noopener noreferrer">
                  Accessibility
                </a>
              </li>
            </ul>
          </div>

          <div>
            <p className="text-xs font-semibold uppercase tracking-[0.2em] text-muted">Discover</p>
            <ul className="mt-4 space-y-2 text-sm text-muted">
              <li>
                <Link href="/#benefits" className="hover:text-ink">
                  How it works
                </Link>
              </li>
              <li>
                <Link href="/#features" className="hover:text-ink">
                  Item verification
                </Link>
              </li>
              <li>
                <a href={WEARHOUSE.app} className="hover:text-ink" target="_blank" rel="noopener noreferrer">
                  Mobile apps
                </a>
              </li>
              <li>
                <Link href="/#reviews" className="hover:text-ink">
                  Infoboard
                </Link>
              </li>
            </ul>
          </div>

          <div>
            <p className="text-xs font-semibold uppercase tracking-[0.2em] text-muted">Help</p>
            <ul className="mt-4 space-y-2 text-sm text-muted">
              <li>
                <a href={WEARHOUSE.helpDelivery} className="hover:text-ink" target="_blank" rel="noopener noreferrer">
                  Help Centre
                </a>
              </li>
              <li>
                <Link href="/#pricing" className="hover:text-ink">
                  Selling
                </Link>
              </li>
              <li>
                <Link href="/#pricing" className="hover:text-ink">
                  Buying
                </Link>
              </li>
              <li>
                <a href={WEARHOUSE.helpRefunds} className="hover:text-ink" target="_blank" rel="noopener noreferrer">
                  Trust and safety
                </a>
              </li>
            </ul>
          </div>

          <div>
            <p className="text-xs font-semibold uppercase tracking-[0.2em] text-muted">Legal</p>
            <ul className="mt-4 space-y-2 text-sm text-muted">
              <li>
                <a href={WEARHOUSE.privacy} className="hover:text-ink" target="_blank" rel="noopener noreferrer">
                  Privacy Centre
                </a>
              </li>
              <li>
                <a href={WEARHOUSE.privacy} className="hover:text-ink" target="_blank" rel="noopener noreferrer">
                  Cookie Policy
                </a>
              </li>
              <li>
                <a href={WEARHOUSE.about} className="hover:text-ink" target="_blank" rel="noopener noreferrer">
                  Terms & Conditions
                </a>
              </li>
              <li>
                <a href="https://voltislabs.uk" className="hover:text-ink" target="_blank" rel="noopener noreferrer">
                  Voltis Labs
                </a>
              </li>
            </ul>
          </div>
        </div>

        <div className="mt-10 border-t border-line pt-6">
          <div className="flex flex-col items-center justify-center gap-2 text-sm text-muted text-center">
            <p>WEARHOUSE © {new Date().getFullYear()} Voltis Labs. All rights reserved.</p>
          </div>
        </div>
      </div>
    </footer>
  );
}
