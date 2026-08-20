import { cp, mkdir, rm } from "node:fs/promises";

await rm("dist", { recursive: true, force: true });
await mkdir("dist/vendor", { recursive: true });
await Promise.all([
  cp("src/index.html", "dist/index.html"),
  cp("src/terminal.css", "dist/terminal.css"),
  cp("src/terminal.js", "dist/terminal.js"),
  cp("node_modules/@xterm/xterm/lib/xterm.js", "dist/vendor/xterm.js"),
  cp("node_modules/@xterm/xterm/css/xterm.css", "dist/vendor/xterm.css"),
  cp("node_modules/@xterm/addon-fit/lib/addon-fit.js", "dist/vendor/addon-fit.js")
]);
