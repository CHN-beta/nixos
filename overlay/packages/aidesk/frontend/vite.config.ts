import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";
import { fileURLToPath } from "node:url";
import { readFileSync } from "node:fs";

const root = fileURLToPath(new URL(".", import.meta.url));
const pkg = JSON.parse(readFileSync(new URL("./package.json", import.meta.url), "utf8")) as { version: string };

// The SPA is served by the aidesk backend, which exposes the same `/api/*`
// routes the React code fetches. Everything below is build-time only: the
// output in `dist/` is plain static HTML, JS, CSS, and assets.
export default defineConfig({
  plugins: [react()],
  resolve: {
    alias: {
      "@": root.replace(/\/$/, ""),
    },
  },
  define: {
    __APP_VERSION__: JSON.stringify(pkg.version),
  },
  build: {
    outDir: "dist",
    emptyOutDir: true,
    sourcemap: false,
    target: "es2022",
  },
});
