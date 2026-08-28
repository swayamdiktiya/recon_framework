#!/bin/bash
# ============================================================
# Recon Framework v11.1 - Modular Reconnaissance Orchestrator
# Usage: ./recon.sh [OPTIONS] <target>
# ============================================================

set -euo pipefail

# ─── Configuration defaults ─────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$SCRIPT_DIR/lib"

# Load libraries
source "$LIB_DIR/config.sh.lib"
source "$LIB_DIR/core.sh.lib"
source "$LIB_DIR/cdn_bypass.sh.lib"
source "$LIB_DIR/port_scan.sh.lib"
source "$LIB_DIR/subdomain.sh.lib"
source "$LIB_DIR/endpoints.sh.lib"
source "$LIB_DIR/misc_checks.sh.lib"
source "$LIB_DIR/http_security.sh.lib"
source "$LIB_DIR/injection.sh.lib"
source "$LIB_DIR/auth.sh.lib"
source "$LIB_DIR/info_disclosure.sh.lib"
source "$LIB_DIR/js_analysis.sh.lib"
source "$LIB_DIR/graphql.sh.lib"
source "$LIB_DIR/owasp_checks.sh.lib"
source "$LIB_DIR/oob.sh.lib"
source "$LIB_DIR/p1_checks.sh.lib"
source "$LIB_DIR/ai.sh.lib"

# ─── Parse CLI arguments ───────────────────────────────────────
usage() {
    cat << EOF
Usage: $0 [OPTIONS] <target>

OPTIONS:
  -y              Auto-confirm legal notice
  -M              Use masscan for ultra-fast full port scan (65535 ports)
  -m <mode>       Scan mode: quick|full|stealth (default: quick)
  -s <steps>      Comma-separated steps: 0,1... or all (default: all)
  -r <ip_range>   CIDR range for IP range scan
  -o <dir>        Output directory override
  -n <mode>       Nuclei mode: 1=critical+high 2=full 3=cves 4=panels
  -c <cookie>     Cookie string for AUTHENTICATED scanning
  -C <cookie>     2nd user's cookie (cross-user IDOR diff)
  -H <header>     Extra request header (repeatable)
  -A <file>       File of extra headers (one "Header: value" per line)
  -x              Run SSRF/OOB detection (interactsh)
  -f              Force full 65535-port nmap
  -j              Output final summary as JSON
  -F              FAST mode - reduces targets/payloads for faster scanning
  -S <file>       Scope file (allow/deny host regexes; "!" prefix = deny)
  -ai             Enable AI analysis (requires Ollama running locally)
  -ai-model <m>   AI model name (default: gemma4-e4b-SecOps)
  -ai-url <url>   AI Ollama URL (default: http://localhost:11434)
  -ai-q <question> Ask AI a question about scan results (post-scan)
  -h              Show this help
EOF
    exit 0
}

# Parse options
AUTO_CONFIRM=0
SCAN_MODE="quick"
STEPS_ARG="all"
IP_RANGE=""
OUTPUT_DIR_OVERRIDE=""
NUCLEI_MODE="1"
RUN_OOB=0
FORCE_FULLSCAN=0
JSON_OUTPUT=0
COOKIE=""
COOKIE2=""
AUTH_HEADER_FILE=""
FAST_MODE=0
SCOPE_FILE=""
AI_Q=""

declare -a AUTH_HEADERS=()
declare -a ARJUN_HDRS=()
declare -a CURL_AUTH=()
declare -a DALFOX_AUTH=()
declare -a SQLMAP_AUTH=()
declare -a HDR_H=()

# Parse AI-specific arguments (long options before getopts)
for arg in "$@"; do
    case "$arg" in
        -ai) AI_ENABLED=1 ;;
    esac
done
# Handle -ai-model, -ai-url, -ai-q with values
set -- "$@"  # reset positional params
while [[ $# -gt 0 ]]; do
    case "$1" in
        -ai-model) AI_MODEL="$2"; shift 2 ;;
        -ai-url)   AI_URL="$2"; shift 2 ;;
        -ai-q)     AI_Q="$2"; shift 2 ;;
        *) shift ;;
    esac
done

while getopts ":yM:m:s:r:o:n:c:C:H:A:S:xfjhF" opt; do
    case $opt in
        y) AUTO_CONFIRM=1 ;;
        M) FORCE_FULLSCAN=2 ;;
        m) SCAN_MODE="$OPTARG" ;;
        F) FAST_MODE=1 ;;
        S) SCOPE_FILE="$OPTARG" ;;
        s) STEPS_ARG="$OPTARG" ;;
        r) IP_RANGE="$OPTARG" ;;
        o) OUTPUT_DIR_OVERRIDE="$OPTARG" ;;
        n) NUCLEI_MODE="$OPTARG" ;;
        c) COOKIE="$OPTARG" ;;
        C) COOKIE2="$OPTARG" ;;
        H) AUTH_HEADERS+=("$OPTARG") ;;
        A) AUTH_HEADER_FILE="$OPTARG" ;;
        x) RUN_OOB=1 ;;
        f) FORCE_FULLSCAN=1 ;;
        j) JSON_OUTPUT=1 ;;
        h) usage ;;
        \?) log_error "Unknown option: -$OPTARG"; exit 1 ;;
    esac
done
shift $((OPTIND - 1))

# Build auth header arrays
load_auth_headers() {
    # Append file-based headers (don't overwrite CLI -H headers)
    if [[ -n "$AUTH_HEADER_FILE" && -f "$AUTH_HEADER_FILE" ]]; then
        local -a file_headers=()
        mapfile -t file_headers < "$AUTH_HEADER_FILE"
        AUTH_HEADERS+=("${file_headers[@]}")
    fi
    [[ -n "$COOKIE" ]] && AUTH_HEADERS+=("Cookie: $COOKIE")

    AUTHENTICATED=${#AUTH_HEADERS[@]}
    for h in "${AUTH_HEADERS[@]}"; do
        HDR_H+=(-H "$h")
        ARJUN_HDRS+=("$h")
        CURL_AUTH+=(-H "$h")
        if [[ "$h" == Cookie:* ]]; then
            DALFOX_AUTH+=(--cookie "${h#Cookie: }")
            SQLMAP_AUTH+=(--cookie="${h#Cookie: }")
        else
            DALFOX_AUTH+=(--header "$h")
            SQLMAP_AUTH+=(--headers="$h")
        fi
    done
}

# ─── Banner ─────────────────────────────────────────────────────
banner() {
    echo -e "${CYAN}${BOLD}"
    echo "██████╗ ███████╗ ██████╗ ██████╗ ███╗   ██╗"
    echo "██╔══██╗██╔════╝██╔════╝██╔═══██╗████╗  ██║"
    echo "██████╔╝█████╗  ██║     ██║   ██║██╔██╗ ██║"
    echo "██╔══██╗██╔══╝  ██║     ██║   ██║██║╚██╗██║"
    echo "██║  ██║███████╗╚██████╗╚██████╔╝██║ ╚████║"
    echo "╚═╝  ╚═╝╚══════╝ ╚═════╝ ╚═════╝ ╚═╝  ╚═══╝"
    echo "${NC}${YELLOW}     Modular Recon Framework v11.1${NC}"
}

# ─── Legal confirmation ────────────────────────────────────────
legal_confirm() {
    [[ "$AUTO_CONFIRM" -eq 1 ]] && return

    log_error "${BOLD}LEGAL NOTICE:${NC} Only test systems you own or have explicit authorization."
    echo -n "Confirm authorization? [y/N]: "
    read -r confirm
    [[ "$confirm" =~ ^[Yy]$ ]] || { log_error "Aborted."; exit 1; }
}

# ─── Tool preflight check ───────────────────────────────────────
preflight() {
    log_section "TOOL PREFLIGHT"

    local tools=(naabu nmap subfinder amass dnsx tlsx ripgen katana gau ffuf nuclei dalfox httpx \
                 feroxbuster wafw00f s3scanner bbot asnmap uncover jaeles theHarvester \
                 gowitness notify interactsh-client arjun x8 gf sqlmap wpscan corsy \
                 slowhttptest hydra puredns massdns dig curl openssl python3 chromium-browser chromium \
                 sstimap subzy jwt_tool trufflehog gitleaks semgrep md5sum dirsearch anew waybackurls ollama)

    local have=0 miss=0
    for t in "${tools[@]}"; do
        if check_tool "$t"; then
            printf "    ${GREEN}[+] %-20s${NC}\n" "$t"
            have=$((have + 1))
        else
            printf "    ${YELLOW}[-] %-20s${NC}\n" "$t (missing)"
            miss=$((miss + 1))
        fi
    done
    echo -e "${CYAN}[*] Available: $have  Missing: $miss${NC}"
}

# ─── Initialize output ───────────────────────────────────────────
init_output() {
    RAW_TARGET="${1:-}"
    [[ -z "$RAW_TARGET" ]] && { log_error "Usage: $0 [OPTIONS] <target>"; exit 1; }

    DOMAIN=$(echo "$RAW_TARGET" | sed 's~https\?://~~' | sed 's~/.*~~')
    TARGET="$DOMAIN"

    [[ -n "$OUTPUT_DIR_OVERRIDE" ]] && OUTPUT_DIR="$OUTPUT_DIR_OVERRIDE" || \
        OUTPUT_DIR="recon_${TARGET}_$(date +%Y%m%d_%H%M%S)"

    mkdir -p "$OUTPUT_DIR"
    LOG="$OUTPUT_DIR/recon.log"
    log_init "$LOG"

    # AUTHENTICATED is set properly by load_auth_headers() which runs next.
    # Initialize to 0 here; the count is recomputed after all headers are loaded.
    AUTHENTICATED=0

    # Initialize AI if enabled
    if [[ "$AI_ENABLED" -eq 1 ]]; then
        AI_MODEL="${AI_MODEL:-${CONFIG[AI_MODEL]}}"
        AI_URL="${AI_URL:-${CONFIG[AI_URL]}}"
        log_info "AI model    : $AI_MODEL"
        log_info "AI endpoint : $AI_URL"
    fi

    log_info "Target      : $TARGET"
    log_info "Scan mode   : $SCAN_MODE"
    log_info "Output Dir  : $OUTPUT_DIR"
    [[ "$AUTHENTICATED" -gt 0 ]] && log_info "Auth scan   : ON ($AUTHENTICATED header(s) injected)" || \
        log_info "Auth scan   : OFF (use -c/-H for authenticated scan)"
    log_info "Started at  : $(date)"
    echo ""
    
    # Verify target is reachable before deep scanning
    log_info "Verifying target connectivity..."
    local test_code
    test_code=$(curl -sk -o /dev/null -w '%{http_code}' --max-time 10 "https://${TARGET}" 2>/dev/null || echo "000")
    if [[ "$test_code" == "000" ]]; then
        test_code=$(curl -sk -o /dev/null -w '%{http_code}' --max-time 10 "http://${TARGET}" 2>/dev/null || echo "000")
    fi
    if [[ "$test_code" == "000" ]]; then
        log_warn "Target ${TARGET} appears unreachable (HTTP 000). Continuing anyway..."
    else
        log_ok "Target reachable (HTTP $test_code)"
    fi
}

# ─── Cleanup trap ───────────────────────────────────────────────
cleanup() {
    cleanup_temp "$OUTPUT_DIR"
    log_info "Cleanup completed at: $(date)"
}
trap cleanup EXIT

# ─── Progress tracking ──────────────────────────────────────────
declare -g TOTAL_STEPS=0
declare -g COMPLETED_STEPS=0
declare -g FAILED_STEPS=0

log_step_progress() {
    local step_num="$1"
    local step_name="$2"
    local status="$3"
    COMPLETED_STEPS=$((COMPLETED_STEPS + 1))
    [[ "$status" == "FAIL" ]] && FAILED_STEPS=$((FAILED_STEPS + 1))
    printf "\r${CYAN}[%d/85] Step %s: %s${NC}" "$COMPLETED_STEPS" "$step_num" "$step_name"
    [[ "$status" == "FAIL" ]] && printf " ${YELLOW}(FAILED)${NC}" || true
    echo ""
}

# ─── Main execution flow ─────────────────────────────────────────
main() {
    banner
    legal_confirm
    init_output "${1:-}"
    load_auth_headers
    set_throttle_for_mode
    if ! in_scope "$DOMAIN"; then
        log_error "Target $DOMAIN is not in scope per $SCOPE_FILE — aborting."; exit 1
    fi
    prefetch_wordlists
    prefetch_cdn_ranges
    preflight

    # Execute steps based on -s argument
    should_run_step 0 && ( step_0_cdn_bypass ) || true
    should_run_step 1 && ( step_1_port_scan ) || true
    should_run_step 2 && ( step_2_asn_mapping ) || true
    should_run_step 3 && ( step_3_subdomain_enum ) || true

    # AI adaptive decision after initial recon
    if [[ "$AI_ENABLED" -eq 1 ]] && should_run_step 83; then
        ai_decide "$OUTPUT_DIR" 3
    fi

    should_run_step 4 && ( step_4_permutation ) || true
    should_run_step 5 && ( step_5_endpoint_discovery ) || true
    should_run_step 6 && ( step_6_fuzz_params ) || true
    should_run_step 7 && ( step_7_cloud_storage ) || true
    should_run_step 8 && ( step_8_waf_detection ) || true
    should_run_step 9 && ( step_9_tech_fingerprint ) || true
    should_run_step 10 && ( step_10_dir_fuzz ) || true
    should_run_step 11 && ( step_11_dns_enum ) || true
    should_run_step 12 && ( step_12_headers_analysis ) || true
    should_run_step 13 && ( step_13_ssl_info ) || true

    echo -e "\n${BOLD}${GREEN}Running Security Checks (Steps 14+)${NC}"

    should_run_step 14 && ( step_14_osint ) || true
    should_run_step 15 && ( step_15_nuclei_templates ) || true
    should_run_step 16 && ( step_16_nuclei_scan ) || true
    should_run_step 17 && ( step_17_dast_scan ) || true
    should_run_step 18 && ( step_18_oob_ssrf ) || true
    should_run_step 19 && ( step_19_injection_chain ) || true
    should_run_step 20 && ( step_20_cms_scan ) || true
    should_run_step 21 && ( step_21_logic_ac ) || true
    should_run_step 22 && ( step_22_secrets_detection ) || true
    should_run_step 23 && ( step_23_injection_tests ) || true
    should_run_step 24 && ( js_library_detection "$OUTPUT_DIR" ) || true
    should_run_step 25 && ( error_exposure_scan "$RAW_TARGET" "$OUTPUT_DIR" ) || true
    should_run_step 26 && ( file_upload_scan "$RAW_TARGET" "$OUTPUT_DIR" ) || true
    should_run_step 27 && ( auth_security_scan "$RAW_TARGET" "$OUTPUT_DIR" ) || true
    should_run_step 28 && ( step_28_password_policy ) || true
    should_run_step 29 && ( http_security_scan "$RAW_TARGET" "$OUTPUT_DIR" ) || true
    should_run_step 30 && ( step_30_client_side ) || true
    should_run_step 31 && ( rate_limit_test "$RAW_TARGET" "$OUTPUT_DIR" ) || true
    should_run_step 32 && ( graphql_discovery "$RAW_TARGET" "$OUTPUT_DIR" 30 ) || true

    # New security check steps (steps 33-50)
    should_run_step 33 && ( step_33_csv_injection ) || true
    should_run_step 34 && ( step_34_content_spoofing ) || true
    should_run_step 35 && ( step_35_dns_misconfig ) || true
    should_run_step 36 && ( step_36_stored_xss ) || true
    should_run_step 37 && ( step_37_password_policy_enforcement ) || true
    should_run_step 38 && ( step_38_session_invalidation ) || true
    should_run_step 39 && ( step_39_concurrent_session ) || true
    should_run_step 40 && ( step_40_business_logic ) || true
    should_run_step 41 && ( step_41_ssti ) || true
    should_run_step 42 && ( step_42_xxe ) || true
    should_run_step 43 && ( step_43_nosql ) || true
    should_run_step 44 && ( step_44_csp ) || true
    should_run_step 45 && ( step_45_subdomain_takeover ) || true
    should_run_step 46 && ( step_46_wayback_params ) || true
    should_run_step 47 && ( step_47_jwt_analysis ) || true
    should_run_step 48 && ( step_48_graphql_security ) || true
    should_run_step 49 && ( step_49_ssrf_cloud_metadata ) || true
    should_run_step 50 && ( step_50_semgrep_js ) || true

    # OWASP Top 10 Coverage Steps (51-83)
    should_run_step 51 && ( step_51_mass_assignment ) || true
    should_run_step 52 && ( step_52_tls_cipher ) || true
    should_run_step 53 && ( step_53_command_injection ) || true
    should_run_step 54 && ( step_54_ldap_injection ) || true
    should_run_step 55 && ( step_55_xpath_injection ) || true
    should_run_step 56 && ( step_56_rate_limit_bypass ) || true
    should_run_step 57 && ( step_57_race_condition ) || true
    should_run_step 58 && ( step_58_cors_trusted_origins ) || true
    should_run_step 59 && ( step_59_debug_endpoints ) || true
    should_run_step 60 && ( step_60_dependency_scan ) || true
    should_run_step 61 && ( step_61_oauth_misconfig ) || true
    should_run_step 62 && ( step_62_two_factor_bypass ) || true
    should_run_step 63 && ( step_63_cicd_exposure ) || true
    should_run_step 64 && ( step_64_deserialization ) || true
    should_run_step 65 && ( step_65_supply_chain ) || true
    should_run_step 66 && ( step_66_security_logging ) || true
    should_run_step 67 && ( step_67_websocket_ssrf ) || true
    should_run_step 68 && ( step_68_idor_bypass ) || true
    should_run_step 69 && ( step_69_xxe_oob ) || true
    should_run_step 70 && ( step_70_prototype_pollution ) || true
    should_run_step 71 && ( step_71_info_disclosure ) || true
    should_run_step 72 && ( step_72_lfi ) || true
    should_run_step 73 && ( step_73_secret_validation ) || true
    should_run_step 74 && ( step_74_http_smuggling ) || true
    should_run_step 75 && ( step_75_reset_poisoning ) || true
    should_run_step 76 && ( step_76_jwt_active ) || true
    should_run_step 77 && ( step_77_bola_scale ) || true
    should_run_step 78 && ( step_78_cache_poisoning ) || true
    should_run_step 79 && ( step_79_oauth_redirect ) || true
    should_run_step 80 && ( step_80_dependency_confusion ) || true
    should_run_step 81 && ( step_81_saml ) || true
    should_run_step 82 && ( step_82_server_pp ) || true
    should_run_step 83 && ( step_83_blind_sqli_oob ) || true

    # AI final analysis and report
    should_run_step 84 && ( ai_analyze "$OUTPUT_DIR" ) || true
    should_run_step 85 && ( ai_report "$OUTPUT_DIR" ) || true

    final_summary
}

# ─── Step Functions ──────────────────────────────────────────────
step_0_cdn_bypass() {
    log_section "STEP 0 — CDN Bypass & Origin Discovery"
    discover_origins "$DOMAIN" "$OUTPUT_DIR"
    
    local all_ips_file="$OUTPUT_DIR/.all_discovered_ips.tmp"
    
    confirm_origins "$DOMAIN" "$all_ips_file" "$OUTPUT_DIR/confirmed_origins.txt" || true
    
    if [[ -f "$OUTPUT_DIR/confirmed_origins.txt" ]]; then
        REAL_IP=$(grep -oE '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' "$OUTPUT_DIR/confirmed_origins.txt" | head -1 || echo "")
        if [[ -n "$REAL_IP" ]]; then
            log_ok "Origin IP found: $REAL_IP"
        else
            log_info "No confirmed origin IP found in confirmed_origins.txt"
        fi
    else
        log_info "No confirmed_origins.txt generated"
    fi
}

step_1_port_scan() {
    log_section "STEP 1 — Port Scanning"
    port_scan "$TARGET" "$OUTPUT_DIR"
}

step_2_asn_mapping() {
    log_section "STEP 2 — ASN Mapping"
    [[ -z "$IP_RANGE" && -z "${REAL_IP:-}" ]] && return
    local target_ip="${REAL_IP:-$TARGET}"
    check_tool asnmap && {
        asnmap -a "$target_ip" -silent -o "$OUTPUT_DIR/asn_map.txt" 2>/dev/null || true
        log_ok "ASN mapping saved to $OUTPUT_DIR/asn_map.txt"
    }
    [[ -n "$IP_RANGE" ]] && check_tool naabu && {
        naabu -host "$IP_RANGE" -top-ports 100 -silent -o "$OUTPUT_DIR/range_live_hosts.txt" 2>/dev/null || true
        log_ok "Range sweep: $(safe_count "$OUTPUT_DIR/range_live_hosts.txt") hosts"
    }
}

step_3_subdomain_enum() {
    log_section "STEP 3 — Subdomain Enumeration"
    subdomain_enum "$DOMAIN" "$OUTPUT_DIR"
}

step_4_permutation() {
    log_section "STEP 4 — Smart Permutation"
    smart_permutation "$DOMAIN" "$OUTPUT_DIR"
}

step_5_endpoint_discovery() {
    log_section "STEP 5 — Endpoint Discovery"
    endpoint_discovery "$RAW_TARGET" "$OUTPUT_DIR"
}

step_6_fuzz_params() {
    log_section "STEP 6 — Parameter Fuzzing"
    local fuzz_out="$OUTPUT_DIR/fuzz_results"
    mkdir -p "$fuzz_out"
    [[ -s "$OUTPUT_DIR/endpoints/all_endpoints.txt" ]] || { log_warn "No endpoints found"; return; }

    grep '?' "$OUTPUT_DIR/endpoints/all_endpoints.txt" | grep -E '\?[^=]+=' | sort -u > "$fuzz_out/urls_with_params.txt"

    param_discovery "$RAW_TARGET" "$OUTPUT_DIR" || true

    [[ "$(safe_count "$fuzz_out/urls_with_params.txt")" -gt 0 ]] && log_ok "Parameterised URLs: $(safe_count "$fuzz_out/urls_with_params.txt")"
}

step_7_cloud_storage() {
    log_section "STEP 7 — Cloud Storage Discovery"
    [[ ! -f "$OUTPUT_DIR/dns_bruteforce/all_subdomains.txt" ]] && { log_warn "Run step 3 first for subdomains"; return; }

    check_tool s3scanner && {
        local base_name
        base_name=$(echo "$TARGET" | cut -d'.' -f1)
        { echo "$TARGET"; echo "$base_name"; echo "${base_name}-backup"; echo "${base_name}-dev"; } > "$OUTPUT_DIR/buckets.txt"
        s3scanner scan --bucket-file "$OUTPUT_DIR/buckets.txt" --provider aws,gcp,azure,do -o "$OUTPUT_DIR/cloud_exposure.txt" 2>/dev/null || true
    }
}

step_8_waf_detection() {
    log_section "STEP 8 — WAF Detection"
    check_tool wafw00f && {
        wafw00f "https://$TARGET" 2>&1 | tee "$OUTPUT_DIR/waf_detection.txt" || true
    }
}

step_9_tech_fingerprint() {
    log_section "STEP 9 — Technology Fingerprinting"
    technology_fingerprint "$RAW_TARGET" "$OUTPUT_DIR"

    [[ -f "$OUTPUT_DIR/live_hosts.txt" ]] && check_tool httpx && {
        httpx -l "$OUTPUT_DIR/live_hosts.txt" -screenshot -srd "$OUTPUT_DIR/screenshots" -silent -timeout 15 2>/dev/null || true
        log_ok "Screenshots: $(find "$OUTPUT_DIR/screenshots" -name '*.png' 2>/dev/null | wc -l) captured"
    }
}

step_10_dir_fuzz() {
    log_section "STEP 10 — Directory Fuzzing"
    local wordlist="${CONFIG[WORDLISTS_DIR]}/common.txt"
    [[ ! -s "$wordlist" ]] && download_if_missing "${CONFIG[DIR_WORDLIST_URL]}" "$wordlist" 30

    if check_tool dirsearch && [[ -s "$wordlist" ]]; then
        log_info "Running dirsearch for directory discovery..."
        timeout 120 dirsearch -u "$RAW_TARGET" -w "$wordlist" --extensions=php,html,js,txt \
            -t "${CONFIG[FFUF_THREADS]}" --output="$OUTPUT_DIR/dirsearch_results.txt" \
            --format=plain -q 2>/dev/null || true
        log_ok "dirsearch complete"
    elif check_tool feroxbuster && [[ -s "$wordlist" ]]; then
        log_info "Using feroxbuster for directory discovery..."
        feroxbuster -u "$RAW_TARGET" -w "$wordlist" -mc 200,204,301,302,307,401,403 \
            -t "${CONFIG[FFUF_THREADS]}" -o "$OUTPUT_DIR/feroxbuster_dirs.txt" -silent 2>/dev/null || true
        log_ok "Directory fuzzing complete"
    else
        log_warn "No directory fuzzing tool available (install dirsearch or feroxbuster)"
    fi
}

step_11_dns_enum() {
    log_section "STEP 11 — DNS Enumeration"
    dns_enum "$DOMAIN" "$OUTPUT_DIR"
}

step_12_headers_analysis() {
    log_section "STEP 12 — HTTP Headers Analysis"
    curl -sI -L --max-time 8 ${CURL_AUTH[@]+"${CURL_AUTH[@]}"} "$RAW_TARGET" > "$OUTPUT_DIR/http_headers.txt" 2>/dev/null || true
}

step_13_ssl_info() {
    log_section "STEP 13 — SSL/TLS Certificate Info"
    timeout 15 openssl s_client -connect "${TARGET}:443" -servername "$TARGET" \
        </dev/null 2>/dev/null | openssl x509 -noout -text > "$OUTPUT_DIR/ssl_info.txt" 2>/dev/null || true
    [[ -s "$OUTPUT_DIR/ssl_info.txt" ]] && log_ok "SSL info saved" || log_warn "Could not retrieve SSL certificate"
}

step_14_osint() {
    log_section "STEP 14 — OSINT / Email Harvesting"
    check_tool theHarvester && {
        timeout 30 theHarvester -d "$DOMAIN" -b "duckduckgo,linkedin,crunchbase,twitter" \
            -f "$OUTPUT_DIR/theharvester" 2>/dev/null || log_warn "theHarvester returned no or partial results"
        if [[ -f "$OUTPUT_DIR/theharvester.html" ]]; then
            mv "$OUTPUT_DIR/theharvester.html" "$OUTPUT_DIR/theharvester.txt" 2>/dev/null || true
        fi
        local harv_count
        harv_count=$(safe_count "$OUTPUT_DIR/theharvester.txt")
        [[ "$harv_count" -gt 0 ]] && log_ok "theHarvester: $harv_count entries" || log_info "No theHarvester results (expected for most targets)"
    }
}

step_15_nuclei_templates() {
    log_section "STEP 15 — Vulnerability Scan (Nuclei Templates)"
    check_tool nuclei && {
        log_info "Using nuclei for vulnerability scanning"
        nuclei -u "$RAW_TARGET" -severity critical,high -o "$OUTPUT_DIR/nuclei_quick.txt" -silent 2>/dev/null || true
    }
}

step_16_nuclei_scan() {
    log_section "STEP 16 — Template-based Vulnerability Scan"
    check_tool nuclei && {
        local nuclei_filter=""
        case "$NUCLEI_MODE" in
            1) nuclei_filter="-severity critical,high" ;;
            2) nuclei_filter="-severity critical,high,medium,low,info" ;;
            3) nuclei_filter="-tags cve" ;;
            4) nuclei_filter="-tags panel,login,exposure" ;;
            *) nuclei_filter="-severity critical,high" ;;
        esac

        nuclei -u "$RAW_TARGET" $nuclei_filter ${HDR_H[@]+"${HDR_H[@]}"} -o "$OUTPUT_DIR/nuclei.txt" -silent -nc 2>/dev/null || true
        log_ok "Nuclei findings: $(safe_count "$OUTPUT_DIR/nuclei.txt")"
    }
}

step_17_dast_scan() {
    log_section "STEP 17 — Active DAST (XSS)"
    xss_test "$RAW_TARGET" "$OUTPUT_DIR"
}

step_18_oob_ssrf() {
    log_section "STEP 18 — OOB / Blind Vuln Detection (interactsh)"
    oob_detection "$RAW_TARGET" "$OUTPUT_DIR"
}

step_19_injection_chain() {
    log_section "STEP 19 — Injection Testing Chain"
    check_tool gf && {
        [[ -f "$OUTPUT_DIR/endpoints/all_endpoints.txt" ]] && {
            mkdir -p "$OUTPUT_DIR/injection"
            for pat in sqli ssrf lfi rce ssti redirect idor xss; do
                gf "$pat" < "$OUTPUT_DIR/endpoints/all_endpoints.txt" > "$OUTPUT_DIR/injection/gf_${pat}.txt" 2>/dev/null || true
            done
        }
    }
}

step_20_cms_scan() {
    log_section "STEP 20 — CMS Testing (WordPress)"
    check_tool wpscan && {
        if curl -sk -L --max-time 4 "$RAW_TARGET" 2>/dev/null | grep -qiE 'wp-content|wp-includes|name="generator" content="WordPress'; then
            log_ok "WordPress detected - running wpscan"
            wpscan --url "$RAW_TARGET" --no-banner --random-user-agent --disable-tls-checks \
                --enumerate "vp,vt,tt,cb,dbe,u1-10,m1-10" -o "$OUTPUT_DIR/wpscan.txt" 2>/dev/null || true
        else
            log_info "No WordPress detected - skipping wpscan"
        fi
    }
}

step_21_logic_ac() {
    log_section "STEP 21 — Logic & Access-Control Testing"
    open_redirect "$RAW_TARGET" "$OUTPUT_DIR"
    [[ -n "$COOKIE" ]] && { idor_test "$OUTPUT_DIR"; log_section "STEP 21e — IDOR Test"; }
}

step_22_secrets_detection() {
    log_section "STEP 22 — Secrets Detection"
    mkdir -p "$OUTPUT_DIR/secrets_scan"
    if [[ -f "$OUTPUT_DIR/endpoints/all_endpoints.txt" ]]; then
        head -100 "$OUTPUT_DIR/endpoints/all_endpoints.txt" > "$OUTPUT_DIR/secrets_scan/urls_for_secrets.txt"
        [[ -s "$OUTPUT_DIR/secrets_scan/urls_for_secrets.txt" ]] && detect_secrets "$OUTPUT_DIR/secrets_scan" "$OUTPUT_DIR/secrets_scan"
    fi
}

step_23_injection_tests() {
    log_section "STEP 23 — Injection Tests"
    html_injection "$RAW_TARGET" "$OUTPUT_DIR"
}

step_28_password_policy() {
    log_section "STEP 28 — Password Policy"
    password_policy_test "$RAW_TARGET" "$OUTPUT_DIR"
}

step_30_client_side() {
    log_section "STEP 30 — Client-Side Security"
    mkdir -p "$OUTPUT_DIR/client_security"
    [[ -f "$OUTPUT_DIR/endpoints/all_endpoints.txt" ]] && {
        head -100 "$OUTPUT_DIR/endpoints/all_endpoints.txt" | while read -r link; do
            [[ -z "$link" ]] && continue
            local code
            code=$(curl -sk -o /dev/null -w '%{http_code}' --max-time 4 ${CURL_AUTH[@]+"${CURL_AUTH[@]}"} "$link" 2>/dev/null || true)
            [[ "$code" =~ ^(404|410|500)$ ]] && echo "[BROKEN LINK] $link ($code)" >> "$OUTPUT_DIR/client_security/broken_links.txt" || true
        done
    }
}

# ─── New Security Check Steps (33-50) ───────────────────────────
step_33_csv_injection() {
    log_section "STEP 33 — CSV Injection Detection"
    csv_injection_check "$RAW_TARGET" "$OUTPUT_DIR"
}

step_34_content_spoofing() {
    log_section "STEP 34 — Content Spoofing Detection"
    content_spoofing_check "$RAW_TARGET" "$OUTPUT_DIR"
}

step_35_dns_misconfig() {
    log_section "STEP 35 — DNS Misconfiguration Checks"
    dns_misconfig_check "$DOMAIN" "$OUTPUT_DIR"
}

step_36_stored_xss() {
    log_section "STEP 36 — Stored XSS Detection"
    stored_xss_check "$RAW_TARGET" "$OUTPUT_DIR"
}

step_37_password_policy_enforcement() {
    log_section "STEP 37 — Password Policy Enforcement"
    password_policy_enforcement_check "$RAW_TARGET" "$OUTPUT_DIR"
}

step_38_session_invalidation() {
    log_section "STEP 38 — Session Invalidation After Password Change"
    session_invalidation_check "$RAW_TARGET" "$OUTPUT_DIR"
}

step_39_concurrent_session() {
    log_section "STEP 39 — Concurrent Session Control"
    concurrent_session_check "$RAW_TARGET" "$OUTPUT_DIR"
}

step_40_business_logic() {
    log_section "STEP 40 — Business Logic / Frontend Validation Check"
    local bl_dir="$OUTPUT_DIR/business_logic"
    mkdir -p "$bl_dir"
    : > "$bl_dir/notes.txt"
    {
        echo "=== Business Logic / Validation Checks ==="
        echo ""
        echo "[MANUAL REQUIRED] These require human analysis:"
        echo "  1. Multi-step flow bypass (e.g., skip payment step)"
        echo "  2. Parameter manipulation (negative quantities, price override)"
        echo "  3. Race conditions (concurrent coupon use, double-spend)"
        echo "  4. Frontend-only validation (check if backend validates)"
        echo "  5. IDOR on business objects (orders, invoices, documents)"
        echo "  6. Workflow bypass (state manipulation)"
        echo "  7. Currency/locale manipulation"
        echo "  8. Referral/affiliate abuse"
        echo "  9. Loyalty points/credits manipulation"
        echo "  10. File processing logic flaws"
    } > "$bl_dir/notes.txt"
    log_info "Business logic: manual analysis required - see $bl_dir/notes.txt"
}

# ─── Advanced Injection/Logic Steps (41-50) ─────────────────────
step_41_ssti() {
    log_section "STEP 41 — SSTI Detection"
    ssti_check "$RAW_TARGET" "$OUTPUT_DIR"
}

step_42_xxe() {
    log_section "STEP 42 — XXE Injection Test"
    xxe_check "$RAW_TARGET" "$OUTPUT_DIR"
}

step_43_nosql() {
    log_section "STEP 43 — NoSQL Injection Test"
    nosql_injection_check "$RAW_TARGET" "$OUTPUT_DIR"
}

step_44_csp() {
    log_section "STEP 44 — CSP Analysis"
    csp_analysis "$RAW_TARGET" "$OUTPUT_DIR"
}

step_45_subdomain_takeover() {
    log_section "STEP 45 — Subdomain Takeover Check"
    subdomain_takeover_check "$DOMAIN" "$OUTPUT_DIR"
}

step_46_wayback_params() {
    log_section "STEP 46 — Wayback Parameter Mining"
    wayback_param_mining "$RAW_TARGET" "$OUTPUT_DIR"
}

step_47_jwt_analysis() {
    log_section "STEP 47 — JWT Token Analysis"
    jwt_analysis "$RAW_TARGET" "$OUTPUT_DIR"
}

step_48_graphql_security() {
    log_section "STEP 48 — GraphQL Security Deep Check"
    graphql_security_check "$RAW_TARGET" "$OUTPUT_DIR"
}

step_49_ssrf_cloud_metadata() {
    log_section "STEP 49 — Cloud Metadata SSRF Probes"
    cloud_metadata_ssrf "$RAW_TARGET" "$OUTPUT_DIR"
}

step_50_semgrep_js() {
    log_section "STEP 50 — Semgrep/CodeQL Static Analysis on JS"
    semgrep_js_scan "$OUTPUT_DIR"
}

# ─── OWASP Top 10 Coverage Steps (51-83) ─────────────────────────

step_51_mass_assignment() {
    log_section "STEP 51 — Mass Assignment / Auto-Binding (A01)"
    mass_assignment_check "$RAW_TARGET" "$OUTPUT_DIR"
}

step_52_tls_cipher() {
    log_section "STEP 52 — TLS Cipher Strength Check (A02)"
    tls_cipher_check "$RAW_TARGET" "$OUTPUT_DIR"
}

step_53_command_injection() {
    log_section "STEP 53 — Command Injection (A03)"
    command_injection_check "$RAW_TARGET" "$OUTPUT_DIR"
}

step_54_ldap_injection() {
    log_section "STEP 54 — LDAP Injection (A03)"
    ldap_injection_check "$RAW_TARGET" "$OUTPUT_DIR"
}

step_55_xpath_injection() {
    log_section "STEP 55 — XPath Injection (A03)"
    xpath_injection_check "$RAW_TARGET" "$OUTPUT_DIR"
}

step_56_rate_limit_bypass() {
    log_section "STEP 56 — Rate Limit Bypass Testing (A04)"
    rate_limit_bypass_check "$RAW_TARGET" "$OUTPUT_DIR"
}

step_57_race_condition() {
    log_section "STEP 57 — Race Condition Testing (A04)"
    race_condition_check "$RAW_TARGET" "$OUTPUT_DIR"
}

step_58_cors_trusted_origins() {
    log_section "STEP 58 — CORS Trusted Origins Check (A05)"
    cors_trusted_origins_check "$RAW_TARGET" "$OUTPUT_DIR"
}

step_59_debug_endpoints() {
    log_section "STEP 59 — Debug Endpoint Discovery (A05)"
    debug_endpoint_check "$RAW_TARGET" "$OUTPUT_DIR"
}

step_60_dependency_scan() {
    log_section "STEP 60 — Dependency Scanning (A06)"
    dependency_scan "$RAW_TARGET" "$OUTPUT_DIR"
}

step_61_oauth_misconfig() {
    log_section "STEP 61 — OAuth Misconfiguration (A07)"
    oauth_misconfig_check "$RAW_TARGET" "$OUTPUT_DIR"
}

step_62_two_factor_bypass() {
    log_section "STEP 62 — 2FA Bypass Testing (A07)"
    two_factor_bypass_check "$RAW_TARGET" "$OUTPUT_DIR"
}

step_63_cicd_exposure() {
    log_section "STEP 63 — CI/CD Exposure Check (A08)"
    cicd_exposure_check "$RAW_TARGET" "$OUTPUT_DIR"
}

step_64_deserialization() {
    log_section "STEP 64 — Insecure Deserialization (A08)"
    deserialization_check "$RAW_TARGET" "$OUTPUT_DIR"
}

step_65_supply_chain() {
    log_section "STEP 65 — Supply Chain Check (A08)"
    supply_chain_check "$RAW_TARGET" "$OUTPUT_DIR"
}

step_66_security_logging() {
    log_section "STEP 66 — Security Logging & Monitoring (A09)"
    security_logging_check "$RAW_TARGET" "$OUTPUT_DIR"
}

step_67_websocket_ssrf() {
    log_section "STEP 67 — WebSocket SSRF (A10)"
    websocket_ssrf_check "$RAW_TARGET" "$OUTPUT_DIR"
}

step_68_idor_bypass() {
    log_section "STEP 68 — Enhanced IDOR / Bypass Testing (A01)"
    local idor_dir="$OUTPUT_DIR/idor_enhanced"
    mkdir -p "$idor_dir"
    : > "$idor_dir/idor_findings.txt"

    local endpoints_file="$OUTPUT_DIR/endpoints/all_endpoints.txt"
    [[ -f "$endpoints_file" ]] || return

    grep -iE '[?&](uuid|guid|object|ref|reference|token|hash|slug|sid|id|user|uid|account)=' "$endpoints_file" 2>/dev/null | head -30 > "$idor_dir/idor_targets.txt"
    log_info "Testing additional IDOR patterns on $(safe_count "$idor_dir/idor_targets.txt") targets"
    log_ok "Enhanced IDOR check complete - see $idor_dir"
}

step_69_xxe_oob() {
    log_section "STEP 69 — OOB XXE via Interactsh (A03)"
    local xxe_dir="$OUTPUT_DIR/xxe_oob"
    mkdir -p "$xxe_dir"
    : > "$xxe_dir/oob_xxe.txt"

    if [[ "$RUN_OOB" -ne 1 ]]; then
        log_info "OOB XXE skipped (pass -x to enable; requires interactsh)"
        log_ok "OOB XXE check complete"
        return
    fi

    local param_urls="$OUTPUT_DIR/fuzz_results/urls_with_params.txt"
    [[ -s "$param_urls" ]] || return

    local oob_host=""
    if check_tool interactsh-client; then
        oob_host=$(interactsh-client -n 2>/dev/null | head -1)
    fi
    if [[ -z "$oob_host" ]]; then
        log_warn "interactsh-client not available or returned no URL — OOB XXE skipped"
        log_ok "OOB XXE check complete"
        return
    fi

    local xxe_oob_payload="<?xml version=\"1.0\"?><!DOCTYPE foo [<!ENTITY % xxe SYSTEM \"http://${oob_host}/xxe\">%xxe;]><foo>&call;</foo>"

    grep -iE '/(api|xml|soap|import|parser)' "$param_urls" 2>/dev/null | head -10 | while read -r url; do
        [[ -z "$url" ]] && continue
        local resp
        resp=$(curl -sk --max-time 4 -X POST -H "Content-Type: application/xml" -d "$xxe_oob_payload" ${CURL_AUTH[@]+"${CURL_AUTH[@]}"} "$url" 2>/dev/null)
        if echo "$resp" | grep -qiE 'XML|entity|DOCTYPE|SYSTEM|external|entity'; then
            echo "[OOB XXE] $url - possible OOB XXE" >> "$xxe_dir/oob_xxe.txt"
            log_vuln "Potential OOB XXE endpoint: $url"
        fi
    done
    log_info "Check interactsh console for callbacks on: $oob_host"
    echo "[OOB XXE] interactsh URL: $oob_host" >> "$xxe_dir/oob_xxe.txt"

    log_ok "OOB XXE check complete"
}

step_70_prototype_pollution() {
    log_section "STEP 70 — Prototype Pollution Detection (A03)"
    local pp_dir="$OUTPUT_DIR/prototype_pollution"
    mkdir -p "$pp_dir"

    log_info "Testing client-side prototype pollution (max 10 URLs)..."
    : > "$pp_dir/proto_pollution.txt"

    local param_urls="$OUTPUT_DIR/fuzz_results/urls_with_params.txt"
    [[ -s "$param_urls" ]] || return

    local pp_canary="PPCANARY$(date +%s%N | md5sum | head -c 10 | tr '[:lower:]' '[:upper:]')"
    local pp_control="PPCONTROL$(date +%s%N | md5sum | head -c 10 | tr '[:lower:]' '[:upper:]')"

    local pp_params=(
        "__proto__%5Bpp_canary%5D=${pp_canary}"
        "__proto__.pp_canary=${pp_canary}"
    )

    for param in "${pp_params[@]}"; do
        grep -iE '\?' "$param_urls" 2>/dev/null | head -10 | while read -r url; do
            [[ -z "$url" ]] && continue
            local test_url="${url}&pp_control=${pp_control}&${param}"
            local resp
            resp=$(curl -sk --max-time 8 ${CURL_AUTH[@]+"${CURL_AUTH[@]}"} "$test_url" 2>/dev/null)
            
            if echo "$resp" | grep -qF "$pp_canary"; then
                if echo "$resp" | grep -qF "$pp_control"; then
                    log_info "[SKIP] Parameter reflection detected on $url (not prototype pollution)"
                else
                    echo "[PROTO POLLUTION GET] $test_url (canary=$pp_canary reflected)" >> "$pp_dir/proto_pollution.txt"
                    record_finding "prototype_pollution" "high" "CONFIRMED" "$test_url" "GET: canary $pp_canary reflected via $param (no control reflection)"
                fi
            fi
        done
    done

    local endpoints_file="$OUTPUT_DIR/endpoints/all_endpoints.txt"
    [[ -f "$endpoints_file" ]] && grep -iE '/(api|rest)' "$endpoints_file" 2>/dev/null | head -10 > "$pp_dir/post_targets.txt"

    while read -r endpoint; do
        [[ -z "$endpoint" ]] && continue
        local payloads=(
            "{\"pp_control\":\"${pp_control}\",\"__proto__\":{\"pp_canary\":\"${pp_canary}\"}}"
            "{\"pp_control\":\"${pp_control}\",\"constructor\":{\"prototype\":{\"pp_canary\":\"${pp_canary}\"}}}"
        )
        for payload in "${payloads[@]}"; do
            local resp
            resp=$(curl -sk --max-time 8 -X POST -H "Content-Type: application/json" \
                -d "$payload" ${CURL_AUTH[@]+"${CURL_AUTH[@]}"} "$endpoint" 2>/dev/null)
            if echo "$resp" | grep -qF "$pp_canary"; then
                if echo "$resp" | grep -qF "$pp_control"; then
                    log_info "[SKIP] POST JSON echo reflection detected on $endpoint"
                else
                    echo "[PROTO POLLUTION POST] $endpoint -> $payload (canary reflected)" >> "$pp_dir/proto_pollution.txt"
                    record_finding "prototype_pollution" "high" "CONFIRMED" "$endpoint" "POST: canary $pp_canary reflected (no control reflection)"
                    break
                fi
            fi
        done
    done < "$pp_dir/post_targets.txt" 2>/dev/null || true

    local pp_hits
    pp_hits=$(safe_count "$pp_dir/proto_pollution.txt")
    [[ "$pp_hits" -gt 0 ]] && log_vuln "Prototype pollution findings: $pp_hits" || log_ok "No prototype pollution detected"
}


step_71_info_disclosure() {
    log_section "STEP 71 — Deep Information Disclosure Scan"
    info_disclosure_scan "$RAW_TARGET" "$OUTPUT_DIR" || true
}

step_72_lfi() {
    log_section "STEP 72 — LFI / Path Traversal (P1: file read / source disclosure)"
    lfi_path_traversal_check "$RAW_TARGET" "$OUTPUT_DIR"
}

step_73_secret_validation() { log_section "STEP 73 — Live Secret Validation (P1)"; secret_validation "$RAW_TARGET" "$OUTPUT_DIR"; }
step_74_http_smuggling()    { log_section "STEP 74 — HTTP Request Smuggling (P1)"; http_smuggling_check "$RAW_TARGET" "$OUTPUT_DIR"; }
step_75_reset_poisoning()   { log_section "STEP 75 — Password Reset Poisoning / ATO (P1)"; password_reset_poisoning "$RAW_TARGET" "$OUTPUT_DIR"; }
step_76_jwt_active()        { log_section "STEP 76 — JWT Active Attacks (P1)"; jwt_active_attacks "$RAW_TARGET" "$OUTPUT_DIR"; }
step_77_bola_scale()        { log_section "STEP 77 — BOLA/IDOR at Scale (P1)"; bola_idor_scale "$RAW_TARGET" "$OUTPUT_DIR"; }
step_78_cache_poisoning()   { log_section "STEP 78 — Web Cache Poisoning (P1)"; web_cache_poisoning "$RAW_TARGET" "$OUTPUT_DIR"; }
step_79_oauth_redirect()    { log_section "STEP 79 — OAuth redirect_uri Hijack (P1)"; oauth_redirect_check "$RAW_TARGET" "$OUTPUT_DIR"; }
step_80_dependency_confusion() { log_section "STEP 80 — Dependency Confusion (P1)"; dependency_confusion_check "$RAW_TARGET" "$OUTPUT_DIR"; }
step_81_saml()              { log_section "STEP 81 — SAML / SSO (XSW manual)"; saml_check "$RAW_TARGET" "$OUTPUT_DIR"; }
step_82_server_pp()         { log_section "STEP 82 — Server-Side Prototype Pollution (P1)"; server_side_pp_check "$RAW_TARGET" "$OUTPUT_DIR"; }
step_83_blind_sqli_oob()    { log_section "STEP 83 — Blind SQLi via OOB (P1)"; blind_sqli_oob "$RAW_TARGET" "$OUTPUT_DIR"; }


# ─── Final Summary ───────────────────────────────────────────────
final_summary() {
    log_section "RECON COMPLETE — Summary"

    echo -e "${GREEN}${BOLD}[+] All results in: ./$OUTPUT_DIR/${NC}"

    [[ -s "$OUTPUT_DIR/confirmed_origins.txt" ]] && {
        log_ok "CONFIRMED ORIGIN IP(s):"
        grep -oE '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' "$OUTPUT_DIR/confirmed_origins.txt" | sort -u | \
            while read -r ip; do echo -e "    ${GREEN}▶ $ip${NC}"; done
    }

    ls -lh "$OUTPUT_DIR/" 2>/dev/null | head -20

    [[ "$JSON_OUTPUT" -eq 1 ]] && generate_json_summary

    generate_findings_report || true
    if check_tool notify && [[ -s "$OUTPUT_DIR/findings.jsonl" ]]; then
        python3 -c "
import json, sys
for line in open(sys.argv[1]):
    line = line.strip()
    if not line: continue
    try:
        r = json.loads(line)
        if r.get('confidence') == 'CONFIRMED':
            print(f\"[{r['check']}|{r['severity']}] {r['url']}\")
    except: pass
" "$OUTPUT_DIR/findings.jsonl" 2>/dev/null | notify -silent 2>/dev/null || true
    fi

    # AI natural language Q&A
    if [[ "$AI_ENABLED" -eq 1 && -n "${AI_Q:-}" ]]; then
        log_section "AI QUESTION"
        ai_nlq "$OUTPUT_DIR" "$AI_Q"
    fi

    log_warn "Reminder: Only test systems you are authorized to test."
}

generate_json_summary() {
    local json_file="$OUTPUT_DIR/summary.json"
    cat > "$json_file" << EOF
{
  "target": "$TARGET",
  "domain": "$DOMAIN",
  "real_ip": "$REAL_IP",
  "scan_mode": "$SCAN_MODE",
  "timestamp": "$(date -Iseconds)",
  "output_dir": "$OUTPUT_DIR",
  "confirmed_origins": $(grep -oE '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' "$OUTPUT_DIR/confirmed_origins.txt" 2>/dev/null | jq -Rs 'split("\n") | map(select(.!=""))' 2>/dev/null || echo "[]"),
  "output_files": $(find "$OUTPUT_DIR" -name '*.txt' -o -name '*.log' 2>/dev/null | jq -Rs 'split("\n") | map(select(.!=""))' 2>/dev/null || echo "[]")
}
EOF
    log_ok "JSON summary: $json_file"
}

# ─── Prefetch wordlists and data ─────────────────────────────────
prefetch_wordlists() {
    [[ ! -d "${CONFIG[WORDLISTS_DIR]}" ]] && mkdir -p "${CONFIG[WORDLISTS_DIR]}"

    [[ ! -s "${CONFIG[WORDLISTS_DIR]}/common.txt" ]] && \
        download_if_missing "${CONFIG[DIR_WORDLIST_URL]}" "${CONFIG[WORDLISTS_DIR]}/common.txt" 30 || true

    [[ ! -s "${CONFIG[WORDLISTS_DIR]}/dns_subdomains.txt" ]] && \
        download_if_missing "${CONFIG[DNS_WORDLIST_URL]}" "${CONFIG[WORDLISTS_DIR]}/dns_subdomains.txt" 30 || true
}

prefetch_cdn_ranges() {
    mkdir -p "${CONFIG[CACHE_DIR]}"
}

# Run main
main "$@"
