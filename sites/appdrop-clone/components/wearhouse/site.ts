/** WEARHOUSE consumer site + invite (matches `Constants` in the iOS app). */
export const WEARHOUSE = {
  site: "https://mywearhouse.co.uk",
  /** Marketplace browse feed (WEARHOUSE-web); cover “Shop” links here when not same-origin. */
  shopHome: "https://mywearhouse.co.uk/home",
  /** Mobile app download / info (same as live marketplace footer). */
  app: "https://mywearhouse.co.uk/app",
  join: "https://mywearhouse.co.uk/join/",
  about: "https://mywearhouse.co.uk/about",
  privacy: "https://mywearhouse.co.uk/privacy",
  helpDelivery: "https://mywearhouse.co.uk/help/delivery",
  helpRefunds: "https://mywearhouse.co.uk/help/refunds",
} as const;

/** Pixel size of hero device image - must match `public/phone-22.png`. */
export const HERO_PHONE = { width: 2560, height: 5284 } as const;

/** Hero carousel frames (2560×5284; slide 1 home, slides 2–4 Pinnacle exports). */
export const HERO_PHONE_SLIDES = [
  { src: "/phone-22.png", alt: "WEARHOUSE app - home and discover", width: 2560, height: 5284 },
  { src: "/hero-phone-slide-2.png", alt: "WEARHOUSE app - discover and listings", width: 2560, height: 5284 },
  { src: "/hero-phone-slide-3.png", alt: "WEARHOUSE app - profile and shop", width: 2560, height: 5284 },
  { src: "/hero-phone-slide-4.png", alt: "WEARHOUSE app - inbox and orders", width: 2560, height: 5284 },
] as const;

/** Pinnacle exports for benefit cards (PHONE-1 / 4 / 5, 2560×5284). */
export const BENEFIT_PHONE = { width: 2560, height: 5284 } as const;

/** Hero avatars: local Pexels crops (`public/hero-avatar-*.jpg`). */
export const HERO_AVATAR = { width: 128, height: 128 } as const;

/** Public marketing assets (benefit mockups + hero row). */
export const IMG = {
  heroPhone: "/phone-22.png",
  /** Benefit row: Discover & follow · List · Chat (Pinnacle PHONE-1, 4, 5). */
  benefitDiscover: "/phone-benefit-discover.png",
  benefitSell: "/phone-benefit-sell.png",
  benefitChat: "/phone-benefit-chat.png",
  avatarA: "/hero-avatar-a.jpg",
  avatarB: "/hero-avatar-b.jpg",
  avatarC: "/hero-avatar-c.jpg",
  reviewer: "https://framerusercontent.com/images/jjqexNcMLN6AF4Cc71TDBJKelo.png?width=400&height=400",
} as const;
