# Architecture

Recon Framework is structured as a modular Bash orchestration layer around external security and reconnaissance utilities.

## High-level flow

```text
                         ┌─────────────────────┐
                         │      recon.sh       │
                         │   CLI / orchestrator│
                         └──────────┬──────────┘
                                    │
                 ┌──────────────────┼──────────────────┐
                 │                  │                  │
                 ▼                  ▼                  ▼
          Configuration        Core utilities      Scope/Auth
          & defaults           & logging            controls
                 │                  │                  │
                 └──────────────────┼──────────────────┘
                                    │
                                    ▼
                           Tool preflight
                                    │
                                    ▼
                         Selected scan steps
                                    │
          ┌─────────────┬───────────┼────────────┬─────────────┐
          ▼             ▼           ▼            ▼             ▼
       Recon       Discovery     Web/App      Injection      OWASP
                                  Security                    checks
          │             │           │            │             │
          └─────────────┴───────────┴────────────┴─────────────┘
                                    │
                                    ▼
                         Findings / logs / JSON
```

## Entry point

`recon.sh` handles command-line parsing, legal authorization confirmation, target initialization, authentication-header loading, scope enforcement, tool preflight, and execution of the numbered scan steps. fileciteturn3file0

## Library modules

The main script sources dedicated libraries for:

- configuration
- core functionality
- CDN bypass
- port scanning
- subdomain enumeration
- endpoint discovery
- miscellaneous checks
- HTTP security
- injection testing
- authentication
- information disclosure
- JavaScript analysis
- GraphQL
- OWASP checks
- OOB testing
- P1 checks

This keeps the orchestrator separate from the implementation of individual security domains. fileciteturn3file0

## Core layer

The core library provides reusable primitives for logging, retry/timeout handling, parallel execution, DNS resolution, CIDR/IP handling, cleanup, filename sanitization, step selection, and other shared functionality. fileciteturn4file0

It also contains application-security helpers for parameter manipulation, secret redaction, structured findings, and false-positive reduction.

## False-positive reduction

One of the framework's design goals is to avoid treating weak signals as confirmed vulnerabilities.

For example, the core library can establish a soft-404 baseline and compare status codes and response sizes before accepting a real HTTP 200 result. It can also require a content signature for exposure checks. fileciteturn4file0

This allows checks to distinguish between:

```text
HTTP 200
   │
   ├── Generic/soft-404 response → ignore
   │
   └── Meaningfully different response
              │
              ▼
        Content validation
              │
              ▼
          Finding candidate
```

## Findings

The framework is designed around structured findings with confidence levels rather than treating every suspicious response as a confirmed vulnerability. The core finding helper supports confidence categories such as `CONFIRMED`, `LIKELY`, `REVIEW`, and `INFO`, along with evidence and secret redaction. fileciteturn4file0

## External tooling

The framework performs a preflight check against its current dependency inventory before executing the scan workflow. Missing tools are reported instead of silently assuming every dependency exists. fileciteturn3file0

See [`TOOLS.md`](TOOLS.md) for the current inventory.

## Configuration

`lib/config.sh.lib` contains defaults for cache directories, wordlists, timeouts, thread counts, external wordlist URLs, CDN ranges, security headers, and sensitive parameter names. fileciteturn5file0

## Extending the framework

A new check should ideally:

1. Live in the appropriate library module.
2. Have a dedicated numbered step in the orchestrator when it needs independent selection.
3. Respect the existing scope and authentication mechanisms.
4. Use the shared timeout/retry and HTTP helpers where appropriate.
5. Avoid writing secrets into logs or findings.
6. Prefer evidence-based confirmation over status-code-only detection.
7. Produce structured findings where practical.
8. Update `CHECKS.md` and `TOOLS.md` when coverage or dependencies change.
