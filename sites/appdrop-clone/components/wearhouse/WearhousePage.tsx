import Image from "next/image";
import Link from "next/link";
import { FaqAccordion } from "./FaqAccordion";
import { FeaturedProductsSlider } from "./FeaturedProductsSlider";
import { HeroPhoneCarousel } from "./HeroPhoneCarousel";
import { WearhouseCoverHeader, WearhouseLogo } from "./WearhouseCoverHeader";
import {
  BENEFIT_PHONE,
  HERO_AVATAR,
  IMG,
  WEARHOUSE,
} from "./site";

/** Brand purple for section / card titles (matches Wearhouse wordmark). */
const whPrimary = "text-[#AB28B2]";

function StarRow() {
  return (
    <div className="flex items-center gap-1" aria-hidden>
      {[0, 1, 2, 3].map((k) => (
        <svg key={k} className="h-[17px] w-[17px] text-ink" viewBox="0 0 24 24" fill="currentColor">
          <path d="M12 2l2.9 6.26L22 9.27l-5 4.87L18.18 22 12 18.56 5.82 22 7 14.14 2 9.27l7.1-1.01L12 2z" />
        </svg>
      ))}
      <span className="relative inline-block h-[17px] w-[17px] text-ink">
        <svg className="absolute inset-0 text-ink/50" viewBox="0 0 24 24" fill="currentColor">
          <path d="M12 2l2.9 6.26L22 9.27l-5 4.87L18.18 22 12 18.56 5.82 22 7 14.14 2 9.27l7.1-1.01L12 2z" />
        </svg>
        <svg className="absolute inset-0 overflow-visible" viewBox="0 0 24 24" fill="currentColor">
          <defs>
            <clipPath id="halfStarWh">
              <rect x="0" y="0" width="12" height="24" />
            </clipPath>
          </defs>
          <path clipPath="url(#halfStarWh)" d="M12 2l2.9 6.26L22 9.27l-5 4.87L18.18 22 12 18.56 5.82 22 7 14.14 2 9.27l7.1-1.01L12 2z" />
        </svg>
      </span>
    </div>
  );
}

function PrimaryCtas({ className = "" }: { className?: string }) {
  return (
    <div className={`flex flex-wrap items-center justify-center gap-3 ${className}`}>
      <a
        href={WEARHOUSE.shopHome}
        className="inline-flex items-center gap-2 rounded-full border border-black/10 bg-[#AB28B2] px-5 py-2.5 text-[0.8125rem] font-semibold text-white shadow-sm transition hover:bg-[#8f1f96]"
      >
        <svg className="h-5 w-5 shrink-0" viewBox="0 0 24 24" fill="currentColor" aria-hidden>
          <path d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm-1 17.93c-3.95-.49-7-3.85-7-7.93 0-.62.08-1.21.21-1.79L9 15v1c0 1.1.9 2 2 2v1.93zm6.9-2.54c-.26-.81-1-1.39-1.9-1.39h-1v-3c0-.55-.45-1-1-1H8v-2h2c.55 0 1-.45 1-1V7h2c1.1 0 2-.9 2-2v-.41c2.93 1.19 5 4.06 5 7.41 0 2.08-.8 3.97-2.1 5.39z" />
        </svg>
        <span>
          Shop on <span className="font-bold">mywearhouse.co.uk</span>
        </span>
      </a>
      <a
        href={WEARHOUSE.join}
        target="_blank"
        rel="noopener noreferrer"
        className="inline-flex items-center gap-2 rounded-full border border-black/10 bg-ink px-5 py-2.5 text-[0.8125rem] font-semibold text-white shadow-sm transition hover:bg-neutral-800"
      >
        <svg className="h-5 w-5 shrink-0" viewBox="0 0 24 24" fill="currentColor" aria-hidden>
          <path d="M15 12c2.21 0 4-1.79 4-4s-1.79-4-4-4-4 1.79-4 4 1.79 4 4 4zm-9-2V7H4v3H1v2h3v3h2v-3h3v-2H6zm9 4c-2.67 0-8 1.34-8 4v2h16v-2c0-2.66-5.33-4-8-4z" />
        </svg>
        <span>
          Join <span className="font-bold">WEARHOUSE</span>
        </span>
      </a>
    </div>
  );
}

/** App Store / Google Play badges (same SVGs as mywearhouse.co.uk). */
function StoreBadgeLinks({ className = "" }: { className?: string }) {
  return (
    <div
      className={`flex flex-wrap items-center justify-center gap-4 sm:gap-5 lg:justify-start ${className}`}
      aria-label="Download our mobile apps"
    >
      <a
        href={WEARHOUSE.app}
        target="_blank"
        rel="noopener noreferrer"
        className="inline-block shrink-0 transition-opacity hover:opacity-90"
      >
        {/* eslint-disable-next-line @next/next/no-img-element -- SVG store badges from mywearhouse.co.uk */}
        <img
          src="/badges/app-store.svg"
          alt="Download on the App Store"
          width={120}
          height={40}
          className="h-10 w-auto md:h-11"
          loading="lazy"
        />
      </a>
      <a
        href={WEARHOUSE.app}
        target="_blank"
        rel="noopener noreferrer"
        className="inline-block shrink-0 transition-opacity hover:opacity-90"
      >
        {/* eslint-disable-next-line @next/next/no-img-element -- SVG store badges from mywearhouse.co.uk */}
        <img
          src="/badges/google-play.svg"
          alt="Get it on Google Play"
          width={135}
          height={40}
          className="h-10 w-auto md:h-11"
          loading="lazy"
        />
      </a>
    </div>
  );
}

export default function WearhousePage() {
  return (
    <div className="flex min-h-screen w-full flex-col bg-white text-ink">
      <WearhouseCoverHeader />

      <main className="flex-1">
        <section id="hero" className="scroll-mt-28 px-5 pb-16 pt-10 md:px-10 md:pb-24 md:pt-14">
          <div className="mx-auto grid max-w-6xl items-center gap-12 lg:grid-cols-2 lg:gap-8">
            <div className="flex flex-col items-center text-center lg:items-start lg:text-left">
              <div className="mb-8 flex flex-col items-center gap-3 sm:flex-row sm:gap-4 lg:items-start">
                <div className="flex items-center gap-2">
                  <StarRow />
                  <span className="text-sm font-semibold tracking-tight text-ink">4.8</span>
                </div>
                <div className="hidden h-4 w-px bg-black/10 sm:block" aria-hidden />
                <div className="flex items-center gap-2">
                  <div className="flex -space-x-2">
                    <Image
                      src={IMG.avatarA}
                      alt=""
                      width={HERO_AVATAR.width}
                      height={HERO_AVATAR.height}
                      className="h-7 w-7 rounded-full border-2 border-white object-cover ring-1 ring-black/5"
                    />
                    <Image
                      src={IMG.avatarB}
                      alt=""
                      width={HERO_AVATAR.width}
                      height={HERO_AVATAR.height}
                      className="h-7 w-7 rounded-full border-2 border-white object-cover ring-1 ring-black/5"
                    />
                    <Image
                      src={IMG.avatarC}
                      alt=""
                      width={HERO_AVATAR.width}
                      height={HERO_AVATAR.height}
                      className="h-7 w-7 rounded-full border-2 border-white object-cover ring-1 ring-black/5"
                    />
                  </div>
                  <p className={`text-sm font-semibold tracking-[-0.02em] ${whPrimary}`}>Preloved fashion community</p>
                </div>
              </div>
              <h1 className="max-w-xl text-balance text-[2.5rem] font-semibold leading-[1.2] tracking-[-0.04em] md:text-5xl lg:text-[3rem]">
                <span className="text-[#AB28B2]">Buy & sell</span>
                <br />
                quality second-hand style.
              </h1>
              <p className="mt-5 max-w-lg text-[17px] font-medium leading-relaxed text-muted md:text-lg">
                WEARHOUSE brings listings, messages, and checkout together for UK fashion lovers - list pieces you no longer wear, discover brands you love, and keep great clothes in circulation.
              </p>
              <PrimaryCtas className="mt-8 justify-center lg:justify-start" />
              <StoreBadgeLinks className="mt-5 w-full max-w-lg lg:mx-0" />
            </div>
            <div className="relative mx-auto w-full max-w-[min(100%,440px)] lg:mx-0 lg:ml-auto lg:max-w-[min(100%,480px)]">
              <HeroPhoneCarousel />
            </div>
          </div>
        </section>

        <section id="challenge" className="scroll-mt-28 px-5 py-10 md:px-10">
          <div className="mx-auto flex max-w-[520px] flex-col items-center gap-[18px] pb-24 pt-5 text-center">
            <p className={`text-base font-semibold tracking-[-0.02em] ${whPrimary}`}>Why we built it</p>
            <h2 className="text-[26px] font-semibold leading-[1.4] tracking-[-0.04em]">
              <span className="text-muted">
                Jumping between random resale groups, DMs, and unclear postage makes second-hand shopping harder than it should be.{" "}
              </span>
              WEARHOUSE gives you one trusted place to browse, chat, and complete orders - on the web and in the app.
            </h2>
            <FeaturedProductsSlider />
          </div>
        </section>

        <section
          id="benefits"
          className="scroll-mt-28 border-t border-white/20 bg-[#AB28B2] px-5 py-16 md:px-10 md:py-24"
        >
          <div className="mx-auto max-w-6xl">
            <div className="mx-auto mb-12 max-w-3xl text-center md:mb-16">
              <p className="text-base font-semibold tracking-[-0.02em] text-white">Why WEARHOUSE</p>
              <h2 className="mt-2 text-3xl font-semibold tracking-[-0.04em] text-white md:text-4xl">
                <span className="text-white/85">Everything you need </span>to move preloved fashion.
              </h2>
            </div>
            <div className="grid gap-8 md:grid-cols-3 md:gap-6">
              {(
                [
                  {
                    t: "Discover & follow",
                    d: "Discover members, brand tags, lookbooks, and Try Cart - search, scroll, and save favourites the same way you do in the app.",
                    imageSrc: IMG.benefitDiscover,
                  },
                  {
                    t: "List in minutes",
                    d: "Photos, size, condition, and price in a guided flow. Share listings to Instagram or friends with a single link.",
                    imageSrc: IMG.benefitSell,
                  },
                  {
                    t: "Chat & checkout",
                    d: "Built-in inbox for buyers and sellers, with order updates and delivery options that match how UK parcels actually move.",
                    imageSrc: IMG.benefitChat,
                  },
                ] as const
              ).map((card) => (
                <div key={card.t} className="flex flex-col overflow-hidden rounded-[40px] border border-black/10 bg-white shadow-sm">
                  <div className="p-8 pb-4">
                    <h3 className={`text-lg font-semibold tracking-[-0.02em] ${whPrimary}`}>{card.t}</h3>
                    <p className="mt-3 text-[15px] leading-relaxed text-muted">{card.d}</p>
                  </div>
                  <div className="relative mt-auto flex w-full justify-center px-6 pb-10 pt-2 md:px-10 md:pb-12">
                    <div className="relative w-full max-w-[260px] overflow-hidden rounded-[28px] [filter:drop-shadow(0_28px_48px_rgba(15,23,42,0.18))_drop-shadow(0_10px_22px_rgba(15,23,42,0.1))] sm:max-w-[280px]">
                      <Image
                        src={card.imageSrc}
                        alt=""
                        width={BENEFIT_PHONE.width}
                        height={BENEFIT_PHONE.height}
                        className="h-auto w-full"
                        sizes="(max-width:768px) 100vw, 280px"
                      />
                    </div>
                  </div>
                </div>
              ))}
            </div>
          </div>
        </section>

        <section id="features" className="scroll-mt-28 px-5 py-16 md:px-10 md:py-24">
          <div className="mx-auto max-w-6xl">
            <div className="mx-auto mb-12 max-w-3xl text-center md:mb-16">
              <p className={`text-base font-semibold tracking-[-0.02em] ${whPrimary}`}>Features</p>
              <h2 className="mt-2 text-3xl font-semibold tracking-[-0.04em] md:text-4xl">
                <span className="text-muted">Built for wardrobes </span>
                <br className="md:hidden" />
                that deserve a second life.
              </h2>
            </div>
            <div className="grid gap-6 sm:grid-cols-2 lg:grid-cols-3">
              {(
                [
                  { t: "Home & Discover", d: "Scroll personalised picks, staff picks, and lookbooks styled like a magazine - not a spreadsheet." },
                  { t: "Search & filters", d: "Find items, brands, or vibes fast. Save searches and jump straight to what fits your budget." },
                  { t: "Sell flow", d: "List from your camera roll with prompts for condition and postage so buyers know exactly what they get." },
                  { t: "Inbox & offers", d: "Keep every question, offer, and order update in one thread - no more lost Instagram DMs." },
                  { t: "Orders & tracking", d: "See when an item is paid, shipped, or ready for pickup. Help articles cover delays, refunds, and more." },
                  { t: "Profiles & trust", d: "Public shop fronts, reviews, and clear policies so the community stays accountable and friendly." },
                ] as const
              ).map((f) => (
                <div key={f.t} className="flex flex-col rounded-[32px] border border-black/10 bg-[#fafafa] p-7">
                  <div className="mb-4 flex h-10 w-10 items-center justify-center rounded-xl bg-[#AB28B2]/12 text-lg font-bold text-[#AB28B2]">
                    ✓
                  </div>
                  <h3 className={`text-lg font-semibold ${whPrimary}`}>{f.t}</h3>
                  <p className="mt-2 text-[15px] leading-relaxed text-muted">{f.d}</p>
                </div>
              ))}
            </div>
          </div>
        </section>

        <section id="intelligence" className="scroll-mt-28 border-y border-line bg-white px-5 py-16 md:px-10 md:py-24">
          <div className="mx-auto max-w-6xl">
            <div className="mx-auto mb-12 max-w-3xl text-center md:mb-16">
              <p className={`text-base font-semibold tracking-[-0.02em] ${whPrimary}`}>Delivery & protection</p>
              <h2 className="mt-2 text-3xl font-semibold tracking-[-0.04em] md:text-4xl">
                <span className="text-muted">Straightforward guidance </span>
                for real parcels.
              </h2>
            </div>
            <div className="grid gap-10 md:grid-cols-3">
              {(
                [
                  {
                    t: "Shipping options",
                    d: "Home delivery and collection-friendly choices at checkout - explained in plain English before you pay.",
                  },
                  {
                    t: "Help when it matters",
                    d: "Articles for cancellations, refunds, vacation mode, and what to do if tracking says delivered but the box never arrived.",
                  },
                  {
                    t: "Same account everywhere",
                    d: "Use mywearhouse.co.uk in the browser and the WEARHOUSE app on your phone with one login and synced inbox.",
                  },
                ] as const
              ).map((row) => (
                <div key={row.t} className="flex flex-col items-center text-center">
                  <div className="mb-6 flex h-16 w-16 items-center justify-center rounded-2xl border border-[#AB28B2]/25 bg-[#AB28B2]/10 text-2xl shadow-sm">
                    📦
                  </div>
                  <h3 className={`text-lg font-semibold ${whPrimary}`}>{row.t}</h3>
                  <p className="mt-2 text-[15px] leading-relaxed text-muted">{row.d}</p>
                </div>
              ))}
            </div>
          </div>
        </section>

        <section id="connect" className="scroll-mt-28 px-5 py-16 md:px-10 md:py-24">
          <div className="mx-auto grid max-w-6xl items-center gap-12 lg:grid-cols-2">
            <div className="grid grid-cols-2 gap-3 sm:gap-4">
              <a
                href={WEARHOUSE.site}
                target="_blank"
                rel="noopener noreferrer"
                className="rounded-3xl border border-black/10 bg-[#fafafa] p-6 shadow-sm transition hover:border-[#AB28B2]/40 hover:bg-white"
              >
                <p className="text-xs font-bold uppercase tracking-wide text-[#AB28B2]">Website</p>
                <p className="mt-2 text-lg font-semibold">mywearhouse.co.uk</p>
                <p className="mt-2 text-sm text-muted">Profiles, item pages, lookbooks, and share links - ideal for desktop research.</p>
              </a>
              <a
                href={WEARHOUSE.join}
                target="_blank"
                rel="noopener noreferrer"
                className="rounded-3xl border border-black/10 bg-[#fafafa] p-6 shadow-sm transition hover:border-[#AB28B2]/40 hover:bg-white"
              >
                <p className="text-xs font-bold uppercase tracking-wide text-[#AB28B2]">Join</p>
                <p className="mt-2 text-lg font-semibold">Create an account</p>
                <p className="mt-2 text-sm text-muted">Start buying or listing in minutes - same account works in the app.</p>
              </a>
              <a
                href={WEARHOUSE.helpDelivery}
                target="_blank"
                rel="noopener noreferrer"
                className="rounded-3xl border border-black/10 bg-[#fafafa] p-6 shadow-sm transition hover:border-[#AB28B2]/40 hover:bg-white"
              >
                <p className="text-xs font-bold uppercase tracking-wide text-[#AB28B2]">Help</p>
                <p className="mt-2 text-lg font-semibold">Delivery guide</p>
                <p className="mt-2 text-sm text-muted">What happens after you tap buy, including pickup vs courier.</p>
              </a>
              <a
                href={WEARHOUSE.about}
                target="_blank"
                rel="noopener noreferrer"
                className="rounded-3xl border border-black/10 bg-[#fafafa] p-6 shadow-sm transition hover:border-[#AB28B2]/40 hover:bg-white"
              >
                <p className="text-xs font-bold uppercase tracking-wide text-[#AB28B2]">About</p>
                <p className="mt-2 text-lg font-semibold">Our story</p>
                <p className="mt-2 text-sm text-muted">Why WEARHOUSE exists and how we think about circular fashion.</p>
              </a>
            </div>
            <div>
              <p className={`text-base font-semibold tracking-[-0.02em] ${whPrimary}`}>Web + app</p>
              <h2 className="mt-2 text-3xl font-semibold tracking-[-0.04em] md:text-4xl">
                <span className="text-muted">Shop anywhere, </span>
                stay in sync.
              </h2>
              <p className="mt-5 text-[17px] leading-relaxed text-muted">
                Use the website when you want a big screen for comparing listings, then keep conversations going from your pocket with the WEARHOUSE app - notifications, offers, and order updates follow you.
              </p>
            </div>
          </div>
        </section>

        <section id="reviews" className="scroll-mt-28 border-t border-white/20 bg-[#AB28B2] px-5 py-16 md:px-10 md:py-24">
          <div className="mx-auto max-w-3xl text-center">
            <p className="text-base font-semibold tracking-[-0.02em] text-white">Community</p>
            <h2 className="mt-2 text-3xl font-semibold tracking-[-0.04em] text-white md:text-4xl">
              <span className="text-white/85">Made for people </span>
              who love clothes.
            </h2>
            <blockquote className="mt-10 rounded-[32px] border border-black/10 bg-white p-8 text-left shadow-sm md:p-10">
              <p className="text-xl font-semibold leading-snug tracking-[-0.02em] md:text-2xl">
                Finally one inbox for every offer. I sell on WEARHOUSE most weekends and the postage reminders actually match Royal Mail cut-offs.
              </p>
              <div className="mt-8 flex items-center gap-4">
                <Image
                  src={IMG.reviewer}
                  alt="Maya Chen"
                  width={56}
                  height={56}
                  className="rounded-full border border-black/10 grayscale"
                />
                <div>
                  <p className="font-semibold">Maya Chen</p>
                  <p className="text-sm text-muted">Seller, Manchester</p>
                </div>
              </div>
            </blockquote>
          </div>
        </section>

        <section id="pricing" className="scroll-mt-28 px-5 py-16 md:px-10 md:py-24">
          <div className="mx-auto max-w-4xl">
            <div className="mb-10 text-center">
              <h2 className={`text-base font-semibold ${whPrimary}`}>For buyers & sellers</h2>
              <p className="mx-auto mt-3 max-w-xl text-muted">
                No subscription wall to browse. Selling fees only apply when you make a sale - you&apos;ll see the exact breakdown before a listing goes live.
              </p>
            </div>
            <div className="grid gap-6 md:grid-cols-2">
              <div className="flex flex-col rounded-[32px] border border-black/10 bg-[#fafafa] p-8 shadow-sm">
                <p className={`text-sm font-semibold ${whPrimary}`}>Buyers</p>
                <p className="mt-2 flex items-baseline gap-1">
                  <span className="text-4xl font-bold tracking-tight">£0</span>
                  <span className="text-muted">to join</span>
                </p>
                <ul className="mt-6 space-y-2 text-left text-sm text-muted">
                  <li>Browse listings, lookbooks, and profiles on the web</li>
                  <li>Save favourites and message sellers securely</li>
                  <li>Checkout with clear delivery options</li>
                  <li>Help centre for refunds, delays, and pickups</li>
                </ul>
                <a
                  href={WEARHOUSE.site}
                  target="_blank"
                  rel="noopener noreferrer"
                  className="mt-8 inline-flex justify-center rounded-full border border-black/10 bg-white px-6 py-3 text-center text-sm font-semibold shadow-sm ring-1 ring-black/5 transition hover:bg-[#f6f6f6]"
                >
                  Start browsing
                </a>
              </div>
              <div className="relative flex flex-col rounded-[32px] border border-[#AB28B2] bg-[#AB28B2] p-8 text-white shadow-xl">
                <p className="text-sm font-semibold text-white/80">Sellers</p>
                <p className="mt-2 flex items-baseline gap-1">
                  <span className="text-4xl font-bold tracking-tight">£0</span>
                  <span className="text-white/85">to join</span>
                </p>
                <ul className="mt-6 space-y-2 text-left text-sm text-white/90">
                  <li>Unlimited drafts until you publish</li>
                  <li>Smart prompts for photos, sizing, and postage</li>
                  <li>Inbox + order timeline in one thread</li>
                  <li>Trusted seller tools & vacation mode</li>
                </ul>
                <a
                  href={WEARHOUSE.join}
                  target="_blank"
                  rel="noopener noreferrer"
                  className="mt-8 inline-flex justify-center rounded-full bg-white px-6 py-3 text-center text-sm font-semibold text-[#AB28B2] transition hover:bg-white/90"
                >
                  List your first item
                </a>
                <p className="mt-4 text-center text-xs text-white/70">Sellers pay £0 to join. Any selling fees are shown in-app before you publish.</p>
              </div>
            </div>
          </div>
        </section>

        <section id="faqs" className="scroll-mt-28 border-t border-line bg-white px-5 py-16 md:px-10 md:py-24">
          <div className="mx-auto max-w-3xl text-center">
            <p className={`text-base font-semibold tracking-[-0.02em] ${whPrimary}`}>FAQs</p>
            <h2 className="mt-2 text-3xl font-semibold tracking-[-0.04em] md:text-4xl">
              Answers before you hit checkout.
            </h2>
          </div>
          <div className="mx-auto mt-12 max-w-3xl">
            <FaqAccordion />
          </div>
        </section>

        <section id="download" className="scroll-mt-28 border-t border-line bg-surface/80 px-5 py-16 md:px-10 md:py-24">
          <div className="mx-auto max-w-6xl text-center">
            <p className={`text-base font-semibold tracking-[-0.02em] ${whPrimary}`}>Get started in a few steps</p>
            <h2 className="mt-2 text-3xl font-semibold tracking-[-0.04em] md:text-4xl">
              <span className="text-muted">Open WEARHOUSE </span>
              on the web or your phone.
            </h2>
            <div className="mx-auto mt-12 grid max-w-4xl gap-6 text-left sm:grid-cols-2 lg:grid-cols-4">
              {(
                [
                  { t: "Visit", d: "Head to mywearhouse.co.uk or install the WEARHOUSE app from your usual store." },
                  { t: "Sign up", d: "Create a profile with a username shoppers will recognise." },
                  { t: "Browse or list", d: "Favourite pieces you love, or photograph something you want to rehome." },
                  { t: "Chat & ship", d: "Agree on postage, pack carefully, and keep proof of posting handy." },
                ] as const
              ).map((step) => (
                <div key={step.t} className="rounded-2xl border border-black/10 bg-white p-6 shadow-sm">
                  <p className={`text-xs font-semibold uppercase tracking-wide ${whPrimary}`}>{step.t}</p>
                  <p className="mt-2 text-[15px] leading-relaxed text-ink">{step.d}</p>
                </div>
              ))}
            </div>

            <PrimaryCtas className="mt-12" />
          </div>
        </section>
      </main>

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
    </div>
  );
}
