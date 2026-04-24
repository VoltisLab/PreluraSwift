import type { Config } from "tailwindcss";

const config: Config = {
  content: [
    "./pages/**/*.{js,ts,jsx,tsx,mdx}",
    "./components/**/*.{js,ts,jsx,tsx,mdx}",
    "./app/**/*.{js,ts,jsx,tsx,mdx}",
  ],
  theme: {
    extend: {
      colors: {
        ink: "#000000",
        muted: "#787878",
        accent: "#04b7f9",
        surface: "#fafafa",
        line: "#f2f2f2",
      },
      fontFamily: {
        sans: ["var(--font-inter)", "system-ui", "sans-serif"],
        display: ["var(--font-dm)", "var(--font-inter)", "system-ui", "sans-serif"],
      },
      maxWidth: {
        screen2xl: "1536px",
      },
    },
  },
  plugins: [],
};

export default config;
