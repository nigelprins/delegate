export {};

type Provider = "openAI" | "anthropic" | "xAI";
type Verdict = "allow" | "ask" | "deny";

const host = document.createElement("div");
host.id = "delegate-ai-guard";
document.documentElement.append(host);
const root = host.attachShadow({ mode: "closed" });

const style = document.createElement("style");
style.textContent = `
  :host { all: initial; }
  button {
    position: fixed; right: 18px; bottom: 18px; z-index: 2147483647;
    width: 44px; height: 44px; border: 1px solid rgba(255,255,255,.16);
    border-radius: 14px; color: white; background: #15171a;
    box-shadow: 0 8px 28px rgba(0,0,0,.28); cursor: pointer;
    font: 600 20px system-ui; transition: transform .16s, opacity .16s;
  }
  button:hover { transform: translateY(-2px); }
  button:disabled { opacity: .5; cursor: wait; }
  .toast {
    position: fixed; right: 18px; bottom: 72px; z-index: 2147483647;
    width: min(320px, calc(100vw - 36px)); box-sizing: border-box;
    padding: 12px 14px; border-radius: 12px; color: white;
    background: #15171a; box-shadow: 0 8px 28px rgba(0,0,0,.28);
    font: 13px/1.4 system-ui; opacity: 0; transform: translateY(8px);
    pointer-events: none; transition: opacity .18s, transform .18s;
  }
  .toast.show { opacity: 1; transform: translateY(0); }
  .toast.allow { border-left: 4px solid #30d158; }
  .toast.ask { border-left: 4px solid #ff9f0a; }
  .toast.deny, .toast.error { border-left: 4px solid #ff453a; }
  strong { display: block; margin-bottom: 3px; font: 650 13px system-ui; }
`;

const button = document.createElement("button");
button.textContent = "D";
button.title = "Check selected text with Delegate";
button.setAttribute("aria-label", "Check selected text with Delegate");

const toast = document.createElement("div");
toast.className = "toast";
root.append(style, button, toast);

button.addEventListener("click", async () => {
  const text = window.getSelection()?.toString().trim() ?? "";
  if (!text) {
    showToast("ask", "Select context first", "Delegate only reads text you explicitly select.");
    return;
  }
  if (text.length > 250_000) {
    showToast("deny", "Selection blocked", "The selection exceeds the 250,000 character safety limit.");
    return;
  }

  button.disabled = true;
  try {
    const response = await chrome.runtime.sendMessage({
      type: "delegate:evaluate",
      provider: detectProvider(),
      text,
      sourceURL: location.href
    });
    if (!response?.ok) throw new Error(response?.error ?? "Unknown gateway error");
    const decision = response.decision as { verdict: Verdict; reasons: string[] };
    const title = {
      allow: "Safe to capture",
      ask: "Approval required",
      deny: "Capture blocked"
    }[decision.verdict];
    showToast(decision.verdict, title, decision.reasons.join(" "));
  } catch (error) {
    showToast(
      "error",
      "Delegate unavailable",
      error instanceof Error ? error.message : "Open the Delegate menu bar app."
    );
  } finally {
    button.disabled = false;
  }
});

function detectProvider(): Provider {
  if (location.hostname.includes("claude")) return "anthropic";
  if (location.hostname.includes("grok") || location.hostname === "x.com") return "xAI";
  return "openAI";
}

let toastTimer: number | undefined;
function showToast(kind: Verdict | "error", title: string, detail: string): void {
  window.clearTimeout(toastTimer);
  toast.className = `toast ${kind} show`;
  toast.replaceChildren();
  const heading = document.createElement("strong");
  heading.textContent = title;
  const message = document.createElement("span");
  message.textContent = detail;
  toast.append(heading, message);
  toastTimer = window.setTimeout(() => {
    toast.classList.remove("show");
  }, 5_000);
}
