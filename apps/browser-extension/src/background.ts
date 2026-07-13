export {};

type Provider = "openAI" | "anthropic" | "xAI";

interface EvaluateMessage {
  type: "delegate:evaluate";
  provider: Provider;
  text: string;
  sourceURL: string;
}

interface PolicyDecision {
  verdict: "allow" | "ask" | "deny";
  reasons: string[];
  redactions: string[];
}

const gateway = "http://127.0.0.1:43121";

chrome.runtime.onInstalled.addListener(() => {
  void chrome.sidePanel.setPanelBehavior({ openPanelOnActionClick: true });
});

chrome.runtime.onMessage.addListener(
  (message: EvaluateMessage, _sender, sendResponse) => {
    if (message.type !== "delegate:evaluate") return false;

    evaluate(message)
      .then((decision) => sendResponse({ ok: true, decision }))
      .catch((error: unknown) =>
        sendResponse({
          ok: false,
          error: error instanceof Error ? error.message : "Delegate gateway unavailable"
        })
      );
    return true;
  }
);

async function evaluate(message: EvaluateMessage): Promise<PolicyDecision> {
  const stored = await chrome.storage.local.get("pairingToken");
  const pairingToken = typeof stored.pairingToken === "string" ? stored.pairingToken : "";
  if (!pairingToken) {
    throw new Error("Open Delegate settings and add the pairing token first.");
  }

  const endpointByProvider: Record<Provider, string> = {
    openAI: "https://api.openai.com/v1/responses",
    anthropic: "https://api.anthropic.com/v1/messages",
    xAI: "https://api.x.ai/v1/responses"
  };
  const byteLength = new TextEncoder().encode(message.text).byteLength;

  const response = await fetch(`${gateway}/v1/evaluate`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "X-Delegate-Token": pairingToken
    },
    body: JSON.stringify({
      provider: message.provider,
      endpoint: endpointByProvider[message.provider],
      purpose: `Capture selected text from ${new URL(message.sourceURL).hostname}`,
      paths: [],
      contentSample: message.text,
      estimatedBytes: byteLength,
      approvedBytes: byteLength,
      includesGitHistory: false,
      classification: "internalData"
    })
  });

  if (!response.ok) {
    throw new Error(
      response.status === 401 ? "Pairing token is incorrect." : "Policy evaluation failed."
    );
  }
  return response.json() as Promise<PolicyDecision>;
}
