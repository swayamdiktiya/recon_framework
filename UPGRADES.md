# Recon Framework v11.5 — Upgrade Notes

84 steps (0..83). Replace whole folder / copy recon.sh + lib/.
Optional tools auto-detected; missing tool => that step skips cleanly.

## P1 checks added this version (steps 73-83) — lib/p1_checks.sh.lib
Tier 1:
  73 Live secret validation   — validates found AWS/Google/GitHub/Slack/Stripe/SendGrid
                                keys against provider APIs => CONFIRMED critical.
  74 HTTP request smuggling    — via `smuggler` (CL.TE/TE.CL/h2c); LIKELY (manual confirm).
  75 Password reset poisoning  — Host/X-Forwarded-Host -> poisoned reset link (ATO).
                                CONFIRMED via OOB callback when run with -x, else REVIEW.
Tier 2:
  76 JWT active attacks        — jwt_tool: none-alg + HMAC secret brute => CONFIRMED on crack.
  77 BOLA/IDOR at scale        — two-session (-c/-C) 3-way diff; LIKELY on cross-user match.
  78 Web cache poisoning       — unkeyed-header canary served from cache => CONFIRMED.
                                (uses a private cache-buster; never poisons real users' cache)
  79 OAuth redirect_uri hijack — unvalidated redirect_uri -> token theft => CONFIRMED.
Tier 3:
  80 Dependency confusion      — exposed package.json dep not on public npm => REVIEW.
  81 SAML/SSO discovery        — endpoints flagged for manual XSW testing.
  82 Server-side prototype pollution — Node "json spaces" gadget => LIKELY.
  83 Blind SQLi via OOB        — MSSQL/Oracle/MySQL DNS-exfil, correlated by interactsh (-x).

## Also in v11.x
  72 LFI / Path traversal (CONFIRMED, signature+baseline).
  18 OOB engine (interactsh, per-injection correlation): SSRF/XXE/RCE/JNDI (-x).
  6  Parameter discovery wired: arjun + x8.
  JS secret scanning: trufflehog/gitleaks.
  Structured findings (confidence) + report w/ repro curl + notify + scope (-S) + throttle.
  Step-41 crash fix, per-step subshell isolation, bounded curls, FP-hardened detections.

## Confidence levels in findings.jsonl / report
  CONFIRMED  strong signal (OOB callback, valid live key, file read, cache hit, redirect).
  LIKELY     good signal, verify (smuggling, BOLA, server-side PP).
  REVIEW     manual only (reset reflection, dependency confusion, SAML, weak-pw).
  INFO       context.

## Recommended installs (optional)
  interactsh-client, x8, sstimap, jwt_tool, smuggler, trufflehog, gitleaks, arjun, notify.

## CLI flags
  -x   OOB / blind-vuln detection (interactsh)   [enables steps 18, 75(OOB), 83]
  -S <file>   Scope allow/deny (regex per line; "!" = deny)
  -c / -C     user A / user B cookies (enables BOLA-at-scale)
