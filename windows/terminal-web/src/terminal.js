(() => {
  const host = window.chrome?.webview;
  const terminal = new Terminal({
    allowProposedApi: false,
    cursorBlink: true,
    cursorStyle: "block",
    fontFamily: '"Cascadia Mono", "Cascadia Code", Consolas, monospace',
    fontSize: 14,
    lineHeight: 1.15,
    letterSpacing: 0,
    scrollback: 10000,
    convertEol: false,
    rightClickSelectsWord: false,
    theme: {
      background: "#181825",
      foreground: "#cdd6f4",
      cursor: "#89b4fa",
      selectionBackground: "#45475a"
    }
  });
  const fitAddon = new FitAddon.FitAddon();
  terminal.loadAddon(fitAddon);
  terminal.open(document.getElementById("terminal"));

  const post = (message) => host?.postMessage(message);
  let resizeTimer;
  const fit = () => {
    clearTimeout(resizeTimer);
    resizeTimer = setTimeout(() => {
      fitAddon.fit();
      post({ type: "resize", cols: terminal.cols, rows: terminal.rows });
    }, 25);
  };

  terminal.onData((data) => post({ type: "input", data }));
  terminal.onBinary((data) => post({ type: "input", data }));
  new ResizeObserver(fit).observe(document.body);

  document.addEventListener("contextmenu", (event) => {
    if (!event.shiftKey) {
      event.preventDefault();
      terminal.focus();
      post({ type: "rightClick", x: event.clientX, y: event.clientY });
    }
  });

  host?.addEventListener("message", (event) => {
    const message = event.data;
    if (!message || typeof message.type !== "string") return;
    if (message.type === "output") {
      terminal.write(message.data ?? "");
    } else if (message.type === "reset") {
      terminal.reset();
    } else if (message.type === "focus") {
      terminal.focus();
    } else if (message.type === "theme" && message.theme) {
      terminal.options.theme = message.theme;
      document.documentElement.style.background = message.theme.background;
      document.body.style.background = message.theme.background;
      document.getElementById("terminal").style.background = message.theme.background;
    }
  });

  window.herdrTerminal = {
    getSelection: () => terminal.getSelection(),
    focus: () => terminal.focus()
  };

  requestAnimationFrame(() => {
    fitAddon.fit();
    terminal.focus();
    post({ type: "ready", cols: terminal.cols, rows: terminal.rows });
  });
})();
