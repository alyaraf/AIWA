import { defineConfig } from "vitest/config";
import react from "@vitejs/plugin-react";

export default defineConfig({
  plugins: [react()],
  test: {
    environment: "jsdom",
    globals: true,
    setupFiles: ["./src/test/setup.js"],
    css: false,
    // The app reads import.meta.env.VITE_USE_MOCKS to decide whether to hit
    // the real backend. Tests need the real code path (not the mock router)
    // so we can control fetch directly — force it off here.
    env: {
      VITE_USE_MOCKS: "false",
      VITE_API_BASE_URL: "http://api.test/api"
    }
  }
});
