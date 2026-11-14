#!/usr/bin/env bash
# import-ng-aio.sh — Bootstrap a new NG-AIO into the local dev environment
#
# Usage:
#   bash ~/.config/herdr-spreader/import-ng-aio.sh <ng-aio-name>
#
# Example:
#   bash ~/.config/herdr-spreader/import-ng-aio.sh vaughan-vm
#   bash ~/.config/herdr-spreader/import-ng-aio.sh wired3-c9
#
# What it does:
#   1. SSH to <name>g1-console.qa.xcloudiq.com, pull /etc/rancher/k3s.yaml,
#      replace 127.0.0.1 with the console's real external IP → ~/.private-kube-<name>.yaml
#   2. Append an alias to ~/.private_bash_aliases under the "# NVO - NG-AIO" section
#   3. Create the herdr-spreader launcher → ~/.config/herdr-spreader/ng-aio-<name>.sh
#   4. Create the herdr-plus quick-action → ~/.config/herdr/plugins/config/cloudmanic.herdr-plus/quick-actions/ws-ng-aio-<name>.toml

set -euo pipefail

# ── Args ──────────────────────────────────────────────────────────────────────
NAME="${1:-}"
if [[ -z "$NAME" ]]; then
  echo "Usage: $0 <ng-aio-name>"
  echo "  e.g. $0 vaughan-vm"
  exit 1
fi

CONSOLE_HOST="${NAME}g1-console.qa.xcloudiq.com"
SSH_PASS="aerohive"
SSH_CMD="sshpass -p $SSH_PASS ssh -o PubkeyAuthentication=no -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@$CONSOLE_HOST"

KUBE_FILE="$HOME/.private-kube-${NAME}.yaml"
ALIASES_FILE="$HOME/.private_bash_aliases"
SPREADER_SCRIPT="$HOME/.config/herdr-spreader/ng-aio-${NAME}.sh"
QUICK_ACTION_TOML="$HOME/.config/herdr/plugins/config/cloudmanic.herdr-plus/quick-actions/ws-ng-aio-${NAME}.toml"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Importing NG-AIO: $NAME"
echo "  Console: $CONSOLE_HOST"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# ── Step 1: Pull k3s.yaml and fix server IP ────────────────────────────────
echo ""
echo "▶ Step 1: Pulling kubeconfig from $CONSOLE_HOST ..."

# Resolve external IP of the console host
EXTERNAL_IP=$(sshpass -p "$SSH_PASS" ssh \
  -o PubkeyAuthentication=no \
  -o StrictHostKeyChecking=no \
  -o UserKnownHostsFile=/dev/null \
  root@"$CONSOLE_HOST" \
  "hostname -I | awk '{print \$1}'" 2>/dev/null | tr -d '[:space:]')

if [[ -z "$EXTERNAL_IP" ]]; then
  echo "  ❌ Could not resolve external IP for $CONSOLE_HOST"
  exit 1
fi
echo "  External IP: $EXTERNAL_IP"

# Pull k3s.yaml and rewrite 127.0.0.1 → external IP
sshpass -p "$SSH_PASS" ssh \
  -o PubkeyAuthentication=no \
  -o StrictHostKeyChecking=no \
  -o UserKnownHostsFile=/dev/null \
  root@"$CONSOLE_HOST" \
  "cat /etc/rancher/k3s/k3s.yaml" 2>/dev/null \
  | sed "s/127\.0\.0\.1/$EXTERNAL_IP/g" \
  > "$KUBE_FILE"

chmod 600 "$KUBE_FILE"
echo "  ✅ Saved → $KUBE_FILE"

# ── Step 2: Add alias to ~/.private_bash_aliases ──────────────────────────
echo ""
echo "▶ Step 2: Adding bash alias ..."

ALIAS_LINE="alias ngaio-${NAME}=\"sshpass -p aerohive ssh -o PubkeyAuthentication=no -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@${CONSOLE_HOST}\""

if grep -qF "ngaio-${NAME}" "$ALIASES_FILE" 2>/dev/null; then
  echo "  ⏭  Alias 'ngaio-${NAME}' already exists — skipping"
else
  # Insert after the last existing ngaio-* alias line in the NVO - NG-AIO section
  python3 - "$ALIASES_FILE" "$ALIAS_LINE" <<'PYEOF'
import sys, re

aliases_file = sys.argv[1]
new_alias = sys.argv[2]

with open(aliases_file, 'r') as f:
    lines = f.readlines()

# Find the last line in the NVO - NG-AIO section that starts with "alias ngaio-"
last_ngaio_idx = None
in_ngaio_section = False
for i, line in enumerate(lines):
    if '# NVO - NG-AIO' in line:
        in_ngaio_section = True
    if in_ngaio_section and line.startswith('alias ngaio-'):
        last_ngaio_idx = i
    # Stop at next section header
    if in_ngaio_section and i > 0 and line.startswith('#') and '# NVO - NG-AIO' not in line and line.strip() != '#':
        if last_ngaio_idx is not None:
            break

if last_ngaio_idx is None:
    print("  ❌ Could not find '# NVO - NG-AIO' section in aliases file")
    sys.exit(1)

lines.insert(last_ngaio_idx + 1, new_alias + '\n')

with open(aliases_file, 'w') as f:
    f.writelines(lines)

print(f"  ✅ Alias added after line {last_ngaio_idx + 1}")
PYEOF
fi

# ── Step 3: Create herdr-spreader launcher script ─────────────────────────
echo ""
echo "▶ Step 3: Creating herdr-spreader launcher ..."

if [[ -f "$SPREADER_SCRIPT" ]]; then
  echo "  ⏭  $SPREADER_SCRIPT already exists — skipping"
else
  NVO_DB_CMD="kubectl -n gdc exec -it postgresql-ha-postgresql-0 -- bash -c \\\"export PGPASSWORD=aerohive; psql -h localhost -U postgres nvo_db -P pager=off\\\""
  PCM_DB_CMD="kubectl -n xiq exec -it postgresql-ha-postgresql-0 -- bash -c \\\"export PGPASSWORD=aerohive; psql -h localhost -U postgres platform_common_db -P pager=off\\\""

  cat > "$SPREADER_SCRIPT" <<SCRIPT
#!/usr/bin/env bash
# ng-aio-${NAME}.sh — herdr workspace for ${NAME} NG-AIO
#
# Converted from ~/.private-kube-${NAME}.yaml
# Usage: bash ~/.config/herdr-spreader/ng-aio-${NAME}.sh

set -euo pipefail

pane_id() { python3 -c "import sys,json; print(json.load(sys.stdin)['result']['pane']['pane_id'])"; }

echo "Creating ng-aio-${NAME} workspace..."

WS_JSON=\$(herdr workspace create --cwd "\$HOME/workspace/badaniya" --label NG-AIO-${NAME} --focus)
WS_ID=\$(echo "\$WS_JSON" | python3 -c "import sys,json; print(json.load(sys.stdin)['result']['workspace']['workspace_id'])")
P1=\$(echo "\$WS_JSON"   | python3 -c "import sys,json; print(json.load(sys.stdin)['result']['root_pane']['pane_id'])")
T1=\$(echo "\$WS_JSON"   | python3 -c "import sys,json; print(json.load(sys.stdin)['result']['tab']['tab_id'])")
herdr tab rename "\$T1" "1 - Console" >/dev/null

# ── 1 - console ──────────────────────────────────────────────────────────
#
# ┌────────────┬──────────────────────────────────────┐
# │  k9s       │  shell                               │ ~25% h
# │            ├──────────────────────────────────────┤
# │  (37% w    │  shell                               │ ~25% h
# │  full h)   ├──────────────────────────────────────┤
# │            │  psql nvo_db                         │ ~25% h
# │            ├──────────────────────────────────────┤
# │            │  psql platform_common_db             │ ~25% h
# └────────────┴──────────────────────────────────────┘

P_RIGHT=\$(herdr pane split "\$P1"      --direction right --ratio 0.45 --no-focus | pane_id)
P_R2=\$(herdr pane split "\$P_RIGHT"   --direction down  --ratio 0.25 --no-focus | pane_id)
P_R3=\$(herdr pane split "\$P_R2"      --direction down  --ratio 0.33 --no-focus | pane_id)
P_R4=\$(herdr pane split "\$P_R3"      --direction down  --ratio 0.5  --no-focus | pane_id)

NVO_DB_CMD='kubectl -n gdc exec -it postgresql-ha-postgresql-0 -- bash -c "export PGPASSWORD=aerohive; psql -h localhost -U postgres nvo_db -P pager=off"'
PCM_DB_CMD='kubectl -n xiq exec -it postgresql-ha-postgresql-0 -- bash -c "export PGPASSWORD=aerohive; psql -h localhost -U postgres platform_common_db -P pager=off"'

herdr pane run "\$P1"      "kube_ctx ${NAME}; k9s"
herdr pane run "\$P_RIGHT" "ngaio-${NAME}"
herdr pane run "\$P_R2"    "ngaio-${NAME}"
herdr pane run "\$P_R3"    "ngaio-${NAME} -t '\$NVO_DB_CMD'"
herdr pane run "\$P_R4"    "ngaio-${NAME} -t '\$PCM_DB_CMD'"

echo "✅ ng-aio-${NAME} ready (workspace \$WS_ID)"
SCRIPT

  chmod +x "$SPREADER_SCRIPT"
  echo "  ✅ Saved → $SPREADER_SCRIPT"
fi

# ── Step 4: Create herdr-plus quick-action toml ───────────────────────────
echo ""
echo "▶ Step 4: Creating herdr-plus quick-action ..."

QUICK_ACTION_DIR="$(dirname "$QUICK_ACTION_TOML")"
mkdir -p "$QUICK_ACTION_DIR"

if [[ -f "$QUICK_ACTION_TOML" ]]; then
  echo "  ⏭  $QUICK_ACTION_TOML already exists — skipping"
else
  cat > "$QUICK_ACTION_TOML" <<TOML
name = "Open workspace: NG-AIO-${NAME}"
command = "python3 ~/.config/herdr-spreader/herdr-action-errors.py run --name 'Open workspace: NG-AIO-${NAME}' -- bash ~/.config/herdr-spreader/ng-aio-${NAME}.sh"
TOML
  echo "  ✅ Saved → $QUICK_ACTION_TOML"
fi

# ── Done ──────────────────────────────────────────────────────────────────
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  ✅ NG-AIO '$NAME' imported successfully!"
echo ""
echo "  Files created:"
echo "    ~/.private-kube-${NAME}.yaml"
echo "    ~/.config/herdr-spreader/ng-aio-${NAME}.sh"
echo "    ~/.config/herdr/plugins/config/cloudmanic.herdr-plus/quick-actions/ws-ng-aio-${NAME}.toml"
echo ""
echo "  Alias added to ~/.private_bash_aliases:"
echo "    alias ngaio-${NAME}=..."
echo ""
echo "▶ Reloading herdr config ..."
herdr server reload-config >/dev/null && echo "  ✅ herdr config reloaded — quick-action is live"

echo ""
echo "  Next steps:"
echo "    source ~/.private_bash_aliases   # reload aliases in current shell"
echo "    bash ~/.config/herdr-spreader/ng-aio-${NAME}.sh   # open workspace"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
