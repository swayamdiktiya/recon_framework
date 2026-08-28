# Tool Inventory

This file documents the external executables and system utilities checked by the Recon Framework preflight stage.

## Count

**51 tools/dependencies are currently listed in the `recon.sh` preflight array.**

The count includes both dedicated security tools and general-purpose/system utilities required by some checks.

## Inventory

| # | Tool | Role / category |
|---:|---|---|
| 1 | `naabu` | Fast port scanning |
| 2 | `nmap` | Network/port/service scanning |
| 3 | `subfinder` | Passive subdomain enumeration |
| 4 | `amass` | Attack-surface and DNS enumeration |
| 5 | `dnsx` | DNS resolution/probing |
| 6 | `tlsx` | TLS probing |
| 7 | `ripgen` | Wordlist/permutation generation |
| 8 | `katana` | Web crawling/endpoint discovery |
| 9 | `gau` | Historical URL discovery |
| 10 | `ffuf` | Web fuzzing |
| 11 | `nuclei` | Template-based vulnerability scanning |
| 12 | `dalfox` | XSS scanning |
| 13 | `httpx` | HTTP probing/metadata collection |
| 14 | `feroxbuster` | Content/directory discovery |
| 15 | `wafw00f` | WAF detection |
| 16 | `s3scanner` | S3/cloud-storage discovery |
| 17 | `bbot` | OSINT/recon automation |
| 18 | `asnmap` | ASN/IP mapping |
| 19 | `uncover` | Search-engine-assisted asset discovery |
| 20 | `jaeles` | Security testing/scanning |
| 21 | `theHarvester` | OSINT collection |
| 22 | `gowitness` | Web screenshots |
| 23 | `notify` | Finding/notification delivery |
| 24 | `interactsh-client` | OOB/interaction testing |
| 25 | `arjun` | HTTP parameter discovery |
| 26 | `x8` | Hidden parameter discovery |
| 27 | `gf` | Pattern-based URL filtering |
| 28 | `sqlmap` | SQL injection testing |
| 29 | `wpscan` | WordPress security scanning |
| 30 | `corsy` | CORS testing |
| 31 | `slowhttptest` | HTTP denial-of-service resilience testing |
| 32 | `hydra` | Authentication/password testing |
| 33 | `puredns` | DNS brute-force/resolution |
| 34 | `massdns` | High-volume DNS resolution |
| 35 | `dig` | DNS queries |
| 36 | `curl` | HTTP requests and response inspection |
| 37 | `openssl` | TLS/SSL inspection |
| 38 | `python3` | Supporting scripts and network helpers |
| 39 | `chromium-browser` | Browser-based checks |
| 40 | `chromium` | Browser-based checks |
| 41 | `sstimap` | SSTI testing |
| 42 | `subzy` | Subdomain takeover detection |
| 43 | `jwt_tool` | JWT analysis/testing |
| 44 | `trufflehog` | Secret discovery |
| 45 | `gitleaks` | Secret scanning |
| 46 | `semgrep` | Static analysis |
| 47 | `md5sum` | Hash/file utility |
| 48 | `dirsearch` | Web content discovery |
| 49 | `anew` | Deduplication/append utility |
| 50 | `waybackurls` | Wayback URL discovery |
| 51 | `ollama` | Local AI inference engine (AI analysis) |

## Notes

- This is the **preflight inventory**, not a claim that every tool executes during every scan.
- Availability is checked at runtime; missing tools are reported by the preflight stage.
- Some tools overlap in purpose. This is intentional: the framework combines complementary passive, active, crawling, fuzzing, vulnerability-scanning, OSINT, and analysis capabilities.
- `chromium-browser` and `chromium` are counted separately because the current preflight array checks both executable names.
- `python3`, `curl`, `openssl`, `dig`, and `md5sum` are general utilities rather than dedicated reconnaissance products, but they are part of the current dependency inventory.
- `ollama` is required only when AI features are enabled with the `-ai` flag.

## Source of truth

The inventory above mirrors the `tools=(...)` preflight array in `recon.sh`. Update this document whenever that array changes.
