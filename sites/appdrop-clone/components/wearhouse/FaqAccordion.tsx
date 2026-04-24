"use client";

import { useState } from "react";
import { WEARHOUSE } from "./site";

type FaqItem = { q: string; a: string; link?: string; linkLabel?: string };

const FAQS: FaqItem[] = [
  {
    q: "What is WEARHOUSE?",
    a: "WEARHOUSE is a marketplace for preloved fashion. You can list items you no longer wear, discover second-hand clothes and accessories, and message buyers or sellers in one place - on the web at mywearhouse.co.uk and in our mobile app.",
  },
  {
    q: "Do I use the website or the app?",
    a: "Both use the same community. Browse listings, profiles, and share links on mywearhouse.co.uk; the app is best for day-to-day buying, selling, notifications, and inbox.",
  },
  {
    q: "How does delivery work?",
    a: "Sellers ship with supported carriers; home delivery and local pickup options depend on the listing and checkout choices. See our delivery help for timelines and what to expect after you pay.",
    link: WEARHOUSE.helpDelivery,
    linkLabel: "Delivery help",
  },
  {
    q: "What if something goes wrong with an order?",
    a: "You can get guidance on refunds, cancellations, and item-not-received cases from our help centre. We aim to keep buyers and sellers informed at every step.",
    link: WEARHOUSE.helpRefunds,
    linkLabel: "Refunds help",
  },
  {
    q: "Is it free to join?",
    a: "Yes. Create an account on mywearhouse.co.uk or through the app, set up your profile, and start browsing or listing. Any selling fees are only charged when you make a sale - details appear before you publish a listing.",
  },
];

export function FaqAccordion() {
  const [open, setOpen] = useState<number | null>(0);

  return (
    <div className="mx-auto flex w-full max-w-2xl flex-col gap-3">
      {FAQS.map((item, i) => {
        const isOpen = open === i;
        return (
          <div key={item.q} className="overflow-hidden rounded-2xl border border-black/10 bg-[#f6f6f6] shadow-sm">
            <button
              type="button"
              id={`faq-trigger-${i}`}
              className="flex w-full items-center justify-between gap-4 px-5 py-4 text-left"
              onClick={() => setOpen(isOpen ? null : i)}
              aria-expanded={isOpen}
              aria-controls={`faq-panel-${i}`}
            >
              <span className="text-[15px] font-medium leading-snug text-ink md:text-base">{item.q}</span>
              <span
                className={`flex h-8 w-8 shrink-0 items-center justify-center rounded-full border border-black/10 bg-white text-lg leading-none text-ink transition-transform duration-300 ease-out motion-reduce:rotate-0 motion-reduce:transition-none ${isOpen ? "rotate-45" : "rotate-0"}`}
                aria-hidden
              >
                +
              </span>
            </button>
            <div
              id={`faq-panel-${i}`}
              role="region"
              aria-labelledby={`faq-trigger-${i}`}
              className={`grid transition-[grid-template-rows] duration-300 ease-in-out motion-reduce:transition-none ${isOpen ? "grid-rows-[1fr]" : "grid-rows-[0fr]"}`}
            >
              <div className="min-h-0 overflow-hidden">
                <div
                  className="border-t border-black/10 px-5 pb-4 pt-1 text-[15px] leading-relaxed text-muted"
                  inert={!isOpen}
                >
                  <p>{item.a}</p>
                  {item.link && item.linkLabel ? (
                    <p className="mt-3">
                      <a
                        className="font-semibold text-[#AB28B2] underline underline-offset-2 hover:text-[#8f1f96]"
                        href={item.link}
                        target="_blank"
                        rel="noopener noreferrer"
                      >
                        {item.linkLabel}
                      </a>
                    </p>
                  ) : null}
                </div>
              </div>
            </div>
          </div>
        );
      })}
      <p className="mt-4 text-center text-sm text-muted">
        More answers on{" "}
        <a className="font-medium text-[#AB28B2] underline underline-offset-2" href={WEARHOUSE.site} target="_blank" rel="noopener noreferrer">
          mywearhouse.co.uk
        </a>
        .
      </p>
    </div>
  );
}
