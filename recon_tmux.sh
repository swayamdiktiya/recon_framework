#!/bin/bash
# ============================================================
# recon_tmux.sh — Tmux wrapper for recon.sh
#
# WHY THIS EXISTS:
#   recon.sh produces thousands of lines over 83 steps. A normal
#   terminal scrollback buffer gets exhausted quickly, so you
#   can't scroll back to Step 1 output when you're at Step 20+.
#
# THIS WRAPPER:
#   • Launches recon.sh inside a tmux session (unlimited scroll)
#   • Opens a second split pane that tail -f follows the log file
#   • After the scan, you can scroll freely through ALL output
#
# USAGE:
#   ./recon_tmux.sh [all recon.sh options] <target>
#
# EXAMPLES:
#   ./recon_tmux.sh -y example.com
#   ./recon_tmux.sh -y -m full -c "session=abc123" https://example.com
#   ./recon_tmux.sh -y -m quick -s 0,1,2,3 example.com
#   ./recon_tmux.sh -y -x -n 2 example.com         # with OOB + full nuclei
#
# TMUX CONTROLS (once inside):
#   Ctrl+b [           → enter scroll mode (use arrow keys / PgUp/PgDn)
#   q                  → exit scroll mode
#   Ctrl+b 0           → switch to recon pane
#   Ctrl+b 1           → switch to log tail pane
#   Ctrl+b d           → detach (scan keeps running in background)
#   tmux attach        → re-attach to a detached session
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RECON_SCRIPT="$SCRIPT_DIR/recon.sh"
SESSION_NAME="recon_$(date +%H%M%S)"

if ! command -v tmux &>/dev/null; then
    echo "[!] tmux not found. Install with: sudo apt install tmux"
    echo "[*] Falling back to plain execution..."
    exec bash "$RECON_SCRIPT" "$@"
fi

if [[ $# -eq 0 ]]; then
    echo "Usage: $0 [recon.sh OPTIONS] <target>"
    echo ""
    echo "Examples:"
    echo "  $0 -y example.com"
    echo "  $0 -y -m full -c 'session=abc' https://example.com"
    echo "  $0 -y -x -n 2 example.com"
    echo ""
    bash "$RECON_SCRIPT" -h
    exit 0
fi

# Determine output dir from args (to find the log file later)
# We pass all args to recon.sh; it will print the log path
TARGET="${*: -1}"          # last argument is the target
DOMAIN=$(echo "$TARGET" | sed 's~https\?://~~' | sed 's~/.*~~')
EXPECTED_LOG_GLOB="recon_${DOMAIN}_*/recon.log"

echo ""
echo "╔══════════════════════════════════════════════╗"
echo "║         Recon Framework — tmux Launcher      ║"
echo "╚══════════════════════════════════════════════╝"
echo ""
echo "  Session : $SESSION_NAME"
echo "  Target  : $TARGET"
echo ""
echo "  Tip: Inside tmux, press Ctrl+b then [ to enter"
echo "       scroll mode — scroll through ALL output freely."
echo "  Tip: Press Ctrl+b then d to detach (scan continues)."
echo "       Re-attach with: tmux attach -t $SESSION_NAME"
echo ""
echo "  Starting in 2 seconds..."
sleep 2

# Create a small init script that recon.sh will run, then opens the log tail
INIT_SCRIPT=$(mktemp /tmp/.recon_init_XXXXXX.sh)
cat > "$INIT_SCRIPT" << INIT_EOF
#!/bin/bash
cd "$SCRIPT_DIR"
# Unlimited scrollback for this pane
# Run recon.sh with all original arguments
bash "$RECON_SCRIPT" $(printf '%q ' "$@")
echo ""
echo "══════════════════════════════════════════"
echo "  Scan complete. Press any key to exit."
echo "══════════════════════════════════════════"
read -n1
INIT_EOF
chmod +x "$INIT_SCRIPT"

# Launch tmux session:
#   Pane 0 (top, 80%):  recon.sh running
#   Pane 1 (bottom, 20%): live log tail (switches to full log viewer when scan ends)
tmux new-session -d -s "$SESSION_NAME" \
    -x "$(tput cols 2>/dev/null || echo 220)" \
    -y "$(tput lines 2>/dev/null || echo 50)"

# Set unlimited scrollback
tmux set-option -t "$SESSION_NAME" history-limit 50000

# Pane 0: run the scan
tmux send-keys -t "${SESSION_NAME}:0" "bash '$INIT_SCRIPT'; tmux kill-session -t $SESSION_NAME" Enter

# Split horizontally — bottom 20% is the live log viewer
tmux split-window -t "${SESSION_NAME}:0" -v -p 20

# Pane 1: wait for log file then tail -f it
tmux send-keys -t "${SESSION_NAME}:0.1" \
    "echo 'Waiting for log file...'; \
     until ls $SCRIPT_DIR/recon_${DOMAIN}_*/recon.log 2>/dev/null | head -1 | grep -q .; do sleep 1; done; \
     LOG=\$(ls -t $SCRIPT_DIR/recon_${DOMAIN}_*/recon.log 2>/dev/null | head -1); \
     echo \"Tailing: \$LOG\"; \
     tail -f \"\$LOG\"" Enter

# Focus back on the main pane
tmux select-pane -t "${SESSION_NAME}:0.0"

# Enable mouse support for easy scrolling
tmux set-option -t "$SESSION_NAME" mouse on

# Attach to the session
tmux attach-session -t "$SESSION_NAME"

# Cleanup
rm -f "$INIT_SCRIPT"
