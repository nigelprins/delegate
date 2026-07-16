#!/bin/zsh
set -euo pipefail

ROOT="${0:A:h}"
TARGET="${HOME}/.cursor"
HOOK_DIR="${TARGET}/hooks"
CONFIG_DIR="${HOME}/.delegate"

mkdir -p "$HOOK_DIR" "$CONFIG_DIR"
cp "$ROOT/hooks.json" "$TARGET/hooks.json"
cp "$ROOT/hooks/"*.py "$HOOK_DIR/"
chmod +x "$HOOK_DIR"/delegate_*.py

if [[ ! -f "$CONFIG_DIR/config.json" ]]; then
  cat > "$CONFIG_DIR/config.json" <<'EOF'
{
  "pairingToken": "PASTE_TOKEN_FROM_DELEGATE_MENU_BAR"
}
EOF
  chmod 600 "$CONFIG_DIR/config.json"
  echo "Created $CONFIG_DIR/config.json — paste your Delegate pairing token."
else
  echo "Kept existing $CONFIG_DIR/config.json"
fi

echo "Installed Delegate Cursor hooks to $TARGET/hooks.json"
echo "Restart Cursor or reopen the workspace so hooks reload."
