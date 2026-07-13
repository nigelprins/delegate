export {};

const gateway = "http://127.0.0.1:43121";
const form = document.querySelector<HTMLFormElement>("#pairing-form")!;
const tokenInput = document.querySelector<HTMLInputElement>("#token")!;
const status = document.querySelector<HTMLSpanElement>("#status")!;
const message = document.querySelector<HTMLParagraphElement>("#message")!;

void initialize();

form.addEventListener("submit", async (event) => {
  event.preventDefault();
  const pairingToken = tokenInput.value.trim();
  if (!/^[a-f0-9]{32}$/.test(pairingToken)) {
    message.textContent = "That token does not have the expected format.";
    return;
  }
  await chrome.storage.local.set({ pairingToken });
  tokenInput.value = "";
  message.textContent = "Browser paired. Selected text can now be evaluated locally.";
  await checkHealth();
});

async function initialize(): Promise<void> {
  const { pairingToken } = await chrome.storage.local.get("pairingToken");
  if (pairingToken) tokenInput.placeholder = "Token already saved";
  await checkHealth();
}

async function checkHealth(): Promise<void> {
  try {
    const response = await fetch(`${gateway}/health`);
    if (!response.ok) throw new Error();
    status.textContent = "Protected";
    status.className = "status online";
  } catch {
    status.textContent = "App offline";
    status.className = "status offline";
  }
}
