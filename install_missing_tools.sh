#!/bin/bash
# ============================================================
# Recon Framework - Missing Tools Installer
# Installs: x8, semgrep, gitleaks, trufflehog, sstimap
# ============================================================

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'
BOLD='\033[1m'

log_ok()   { echo -e "${GREEN}[+] $*${NC}"; }
log_info() { echo -e "${CYAN}[*] $*${NC}"; }
log_warn() { echo -e "${YELLOW}[!] $*${NC}"; }
log_err()  { echo -e "${RED}[!] $*${NC}"; }

check() { command -v "$1" &>/dev/null; }

echo -e "${CYAN}${BOLD}"
echo "╔══════════════════════════════════════════════╗"
echo "║   Recon Framework — Missing Tools Installer  ║"
echo "║   Installing: x8, semgrep, gitleaks,         ║"
echo "║               trufflehog, sstimap            ║"
echo "╚══════════════════════════════════════════════╝"
echo -e "${NC}"

# ── 1. x8 (hidden parameter discovery) ─────────────────────────
if check x8; then
    log_ok "x8 already installed — skipping"
else
    log_info "Installing x8 (hidden parameter discovery)..."
    # x8 is a Rust binary — install via cargo or download prebuilt
    if check cargo; then
        cargo install x8 2>/dev/null && log_ok "x8 installed via cargo" || {
            log_warn "cargo install failed, trying prebuilt binary..."
            # Download latest prebuilt from github releases
            local_arch="x86_64-unknown-linux-musl"
            latest=$(curl -s https://api.github.com/repos/Sh1Yo/x8/releases/latest \
                | grep browser_download_url \
                | grep "$local_arch" | head -1 | cut -d'"' -f4)
            if [[ -n "$latest" ]]; then
                curl -sL "$latest" -o /tmp/x8.tar.gz
                tar -xzf /tmp/x8.tar.gz -C /tmp/
                sudo mv /tmp/x8 /usr/local/bin/x8
                sudo chmod +x /usr/local/bin/x8
                rm -f /tmp/x8.tar.gz
                log_ok "x8 installed from prebuilt binary"
            else
                log_err "Could not find x8 prebuilt binary. Install Rust and run: cargo install x8"
            fi
        }
    else
        log_warn "Rust/cargo not found. Installing cargo first..."
        curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --no-modify-path
        source "$HOME/.cargo/env"
        cargo install x8 2>/dev/null && log_ok "x8 installed via cargo" || log_err "x8 install failed"
    fi
fi

# ── 2. semgrep (static analysis) ──────────────────────────────
if check semgrep; then
    log_ok "semgrep already installed — skipping"
else
    log_info "Installing semgrep..."
    pip3 install semgrep --quiet 2>/dev/null && log_ok "semgrep installed via pip3" || {
        # Try pipx as fallback
        if check pipx; then
            pipx install semgrep && log_ok "semgrep installed via pipx"
        else
            log_err "semgrep install failed. Try: pip3 install semgrep"
        fi
    }
fi

# ── 3. gitleaks (secret scanning) ─────────────────────────────
if check gitleaks; then
    log_ok "gitleaks already installed — skipping"
else
    log_info "Installing gitleaks..."
    latest_tag=$(curl -s https://api.github.com/repos/gitleaks/gitleaks/releases/latest \
        | grep '"tag_name"' | cut -d'"' -f4)
    version="${latest_tag#v}"
    url="https://github.com/gitleaks/gitleaks/releases/download/${latest_tag}/gitleaks_${version}_linux_x64.tar.gz"
    curl -sL "$url" -o /tmp/gitleaks.tar.gz 2>/dev/null
    tar -xzf /tmp/gitleaks.tar.gz -C /tmp/ gitleaks 2>/dev/null
    sudo mv /tmp/gitleaks /usr/local/bin/gitleaks
    sudo chmod +x /usr/local/bin/gitleaks
    rm -f /tmp/gitleaks.tar.gz
    check gitleaks && log_ok "gitleaks ${latest_tag} installed" || log_err "gitleaks install failed"
fi

# ── 4. trufflehog (secret scanning in repos/traffic) ──────────
if check trufflehog; then
    log_ok "trufflehog already installed — skipping"
else
    log_info "Installing trufflehog..."
    curl -sSfL https://raw.githubusercontent.com/trufflesecurity/trufflehog/main/scripts/install.sh \
        | sudo sh -s -- -b /usr/local/bin 2>/dev/null \
        && log_ok "trufflehog installed" \
        || {
            # Fallback: pip install
            pip3 install trufflehog 2>/dev/null && log_ok "trufflehog installed via pip3" \
            || log_err "trufflehog install failed. Try: pip3 install trufflehog"
        }
fi

# ── 5. sstimap (SSTI engine detection, tplmap successor) ───────
if check sstimap; then
    log_ok "sstimap already installed — skipping"
else
    log_info "Installing sstimap (maintained tplmap successor)..."
    pip3 install sstimap --quiet 2>/dev/null && log_ok "sstimap installed via pip3" || {
        # Try installing from GitHub directly
        pip3 install git+https://github.com/vladko312/SSTImap.git --quiet 2>/dev/null \
            && log_ok "sstimap installed from GitHub" \
            || log_err "sstimap install failed. Try: pip3 install sstimap"
    }
fi

# ── Final check ─────────────────────────────────────────────────
echo ""
echo -e "${CYAN}${BOLD}=== Final Status ===${NC}"
for t in x8 semgrep gitleaks trufflehog sstimap; do
    if check "$t"; then
        log_ok "$t → $(command -v $t)"
    else
        log_err "$t → NOT FOUND (manual install needed)"
    fi
done

echo ""
log_info "Done. Re-run: ./recon.sh --help to confirm preflight."
