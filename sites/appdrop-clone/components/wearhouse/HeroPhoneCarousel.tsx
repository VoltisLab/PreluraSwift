"use client";

import Image from "next/image";
import { useEffect, useRef, useState } from "react";
import { HERO_PHONE, HERO_PHONE_SLIDES } from "./site";

const AUTO_MS = 4500;

function ChevronLeft({ className = "h-5 w-5" }: { className?: string }) {
  return (
    <svg className={className} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.2" strokeLinecap="round" strokeLinejoin="round" aria-hidden>
      <path d="M15 18l-6-6 6-6" />
    </svg>
  );
}

function ChevronRight({ className = "h-5 w-5" }: { className?: string }) {
  return (
    <svg className={className} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.2" strokeLinecap="round" strokeLinejoin="round" aria-hidden>
      <path d="M9 18l6-6-6-6" />
    </svg>
  );
}

export function HeroPhoneCarousel() {
  const slides = HERO_PHONE_SLIDES;
  const multi = slides.length > 1;
  const [index, setIndex] = useState(0);
  const [reducedMotion, setReducedMotion] = useState(false);
  const pausedRef = useRef(false);

  useEffect(() => {
    const mq = window.matchMedia("(prefers-reduced-motion: reduce)");
    setReducedMotion(mq.matches);
    const onChange = () => setReducedMotion(mq.matches);
    mq.addEventListener("change", onChange);
    return () => mq.removeEventListener("change", onChange);
  }, []);

  useEffect(() => {
    if (!multi || reducedMotion) return;
    const id = window.setInterval(() => {
      if (!pausedRef.current) setIndex((i) => (i + 1) % slides.length);
    }, AUTO_MS);
    return () => window.clearInterval(id);
  }, [multi, reducedMotion, slides.length]);

  const go = (dir: -1 | 1) => {
    if (!multi) return;
    setIndex((i) => (i + dir + slides.length) % slides.length);
  };

  return (
    <div
      className="flex w-full flex-col items-center"
      onMouseEnter={() => {
        pausedRef.current = true;
      }}
      onMouseLeave={() => {
        pausedRef.current = false;
      }}
    >
      <div className="relative mx-auto w-full max-w-[280px] sm:max-w-[300px] lg:max-w-[300px] xl:max-w-[320px]">
        <div
          className="relative w-full bg-white shadow-none"
          style={{ aspectRatio: `${HERO_PHONE.width} / ${HERO_PHONE.height}` }}
        >
          {slides.map((slide, i) => {
            const active = i === index;
            const motionClass = !multi
              ? "z-[1] opacity-100"
              : reducedMotion
                ? active
                  ? "z-[1] opacity-100"
                  : "z-0 opacity-0 pointer-events-none"
                : `transition-opacity duration-500 ease-out ${active ? "z-[1] opacity-100" : "z-0 opacity-0 pointer-events-none"}`;
            return (
              <div key={`hero-slide-${i}`} className={`absolute inset-0 ${motionClass}`} aria-hidden={!active}>
                <div className="relative block h-full w-full">
                  <Image
                    src={slide.src}
                    alt={slide.alt}
                    fill
                    sizes="(max-width:640px) 280px, 320px"
                    className="object-contain object-center shadow-none [filter:none]"
                    draggable={false}
                    priority={i === 0}
                    quality={95}
                  />
                </div>
              </div>
            );
          })}
        </div>
      </div>

      {multi ? (
        <div className="mt-5 flex items-center justify-center gap-3">
          <button
            type="button"
            className="inline-flex h-11 w-11 items-center justify-center rounded-full border border-black/12 bg-white text-[#AB28B2] ring-1 ring-black/[0.04] transition hover:border-[#AB28B2]/40 hover:bg-[#f5e8f7] active:scale-95"
            aria-label="Previous screen"
            onClick={() => go(-1)}
          >
            <ChevronLeft />
          </button>
          <div className="flex gap-1.5" aria-hidden>
            {slides.map((_, i) => (
              <span
                key={i}
                className={`h-1.5 rounded-full transition-all duration-300 ${i === index ? "w-5 bg-[#AB28B2]" : "w-1.5 bg-black/15"}`}
              />
            ))}
          </div>
          <button
            type="button"
            className="inline-flex h-11 w-11 items-center justify-center rounded-full border border-black/12 bg-white text-[#AB28B2] ring-1 ring-black/[0.04] transition hover:border-[#AB28B2]/40 hover:bg-[#f5e8f7] active:scale-95"
            aria-label="Next screen"
            onClick={() => go(1)}
          >
            <ChevronRight />
          </button>
        </div>
      ) : null}
    </div>
  );
}
