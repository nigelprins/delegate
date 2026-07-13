import { build } from "esbuild";
import { cp, mkdir, rm } from "node:fs/promises";

await rm("dist", { recursive: true, force: true });
await mkdir("dist", { recursive: true });

await build({
  entryPoints: {
    background: "src/background.ts",
    content: "src/content.ts",
    sidepanel: "src/sidepanel.ts"
  },
  bundle: true,
  outdir: "dist",
  format: "iife",
  target: "chrome114",
  sourcemap: true
});

await Promise.all([
  cp("src/manifest.json", "dist/manifest.json"),
  cp("src/sidepanel.html", "dist/sidepanel.html"),
  cp("src/sidepanel.css", "dist/sidepanel.css")
]);
