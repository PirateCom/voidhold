import type { CapacitorConfig } from "@capacitor/cli";

const hosted = process.env.VOIDHOLD_SERVER_URL ?? "https://voidhold.vercel.app";

const config: CapacitorConfig = {
  appId: "com.voidhold.game",
  appName: "Voidhold",
  webDir: "public",
  server: {
    url: hosted,
    androidScheme: "https",
  },
  android: {
    allowMixedContent: false,
  },
};

export default config;
