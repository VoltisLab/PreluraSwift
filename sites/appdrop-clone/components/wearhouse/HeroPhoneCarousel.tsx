"use client";

import Image from "next/image";
import { useCallback, useEffect, useRef, useState } from "react";
import { HERO_PHONE_SLIDES } from "./site";

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

  const go = useCallback(
    (dir: -1 | 1) => {
      setIndex((i) => (i + dir + HERO_PHONE_SLIDES.length) % HERO_PHONE_SLIDES.length);
    },
    []
  );

  useEffect(() => {
    if (reducedMotion) return;
    const id = window.setInterval(() => {
      if (!pausedRef.current) setIndex((i) => (i + 1) % HERO_PHONE_SLIDES.length);
    }, AUTO_MS);
    return () => window.clearInterval(id);
  }, [reducedMotion]);

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
        <div className="relative w-full pb-1">
          <div
            className="relative w-full overflow-hidden rounded-[2rem]"
            style={{ aspectRatio: `${HERO_PHONE_SLIDES[0].width} / ${HERO_PHONE_SLIDES[0].height}` }}
          >
            {HERO_PHONE_SLIDES.map((slide, i) => {
              const active = i === index;
              return (
                <div
                  key={slide.src}
                  className={`absolute inset-0 ${
                    reducedMotion
                      ? active
                        ? "z-[1] opacity-100"
                        : "z-0 opacity-0"
                      : `transition-[opacity,transform] duration-500 ease-out ${active ? "z-[1] opacity-100 scale-100" : "z-0 opacity-0 scale-[0.97]"}`
                  }`}
                  aria-hidden={!active}
                >
                  <Image
                    src={slide.src}
                    alt={slide.alt}
                    width={slide.width}
                    height={slide.height}
                    className="h-full w-full object-contain"
                    sizes="(max-width:640px) 280px, 320px"
                    priority={i === 0}
                    draggable={false}
                  />
                </div>
              );
            })}
          </div>
        </div>
      </div>

      <div className="mt-5 flex items-center justify-center gap-3">
        <button
          type="button"
          className="inline-flex h-11 w-11 items-center justify-center rounded-full border border-black/12 bg-white text-[#AB28B2] shadow-sm ring-1 ring-black/[0.04] transition hover:border-[#AB28B2]/40 hover:bg-[#f5e8f7] active:scale-95"
          aria-label="Previous screen"
          onClick={() => go(-1)}
        >
          <ChevronLeft />
        </button>
        <div className="flex gap-1.5" aria-hidden>
          {HERO_PHONE_SLIDES.map((_, i) => (
            <span
              key={i}
              className={`h-1.5 rounded-full transition-all duration-300 ${i === index ? "w-5 bg-[#AB28B2]" : "w-1.5 bg-black/15"}`}
            />
          ))}
        </div>
        <button
          type="button"
          className="inline-flex h-11 w-11 items-center justify-center rounded-full border border-black/12 bg-white text-[#AB28B2] shadow-sm ring-1 ring-black/[0.04] transition hover:border-[#AB28B2]/40 hover:bg-[#f5e8f7] active:scale-95"
          aria-label="Next screen"
          onClick={() => go(1)}
        >
          <ChevronRight />
        </button>
      </div>
    </div>
  );
}
