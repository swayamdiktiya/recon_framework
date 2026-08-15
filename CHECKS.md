# Scan Coverage Reference

Recon Framework currently exposes **83 numbered execution steps (0–82)** from the main orchestrator. The step runner is designed so individual steps, comma-separated selections, or ranges can be enabled with `-s`. fileciteturn3file0

## Coverage overview

| Step range | Area | Coverage examples |
|---|---|---|
| 0–13 | Recon & discovery | CDN bypass, ports, ASN mapping, subdomains, permutations, endpoints, parameter fuzzing, cloud storage, WAF, technology fingerprinting, directories, DNS, headers, TLS |
| 14–23 | Security assessment | OSINT, Nuclei templates/scanning, DAST, OOB/SSRF, injection chains, CMS checks, access-control/logic checks, secrets, injection testing |
| 24–32 | Application security | JavaScript library analysis, error exposure, file uploads, authentication, password policy, HTTP security, client-side checks, rate limiting, GraphQL discovery |
| 33–50 | Extended checks | CSV injection, content spoofing, DNS misconfiguration, stored XSS, password-policy enforcement, session invalidation, concurrent sessions, business logic, SSTI, XXE, NoSQL, CSP, subdomain takeover, historical parameters, JWT, GraphQL security, SSRF/cloud metadata, Semgrep JavaScript analysis |
| 51–82 | OWASP-oriented coverage | Mass assignment, TLS ciphers, command injection, LDAP/XPath injection, rate-limit bypass, race conditions, CORS, debug endpoints, dependency scanning, and additional application/security checks |

The first 51 steps are visible directly in the current main execution flow; the framework labels the later group as OWASP Top 10 coverage. fileciteturn3file0

## Detailed named checks currently visible in the orchestrator

### Reconnaissance

- CDN bypass
- Port scanning
- ASN mapping
- Subdomain enumeration
- Subdomain permutation
- Endpoint discovery
- Parameter fuzzing
- Cloud-storage discovery
- WAF detection
- Technology fingerprinting
- Directory fuzzing
- DNS enumeration
- HTTP-header analysis
- SSL/TLS information

### Web and application security

- OSINT
- Nuclei template processing
- Nuclei scanning
- DAST scanning
- OOB/SSRF detection
- Injection chains
- CMS scanning
- Access-control/business-logic checks
- Secrets detection
- Injection testing
- JavaScript library detection
- Error exposure
- File-upload testing
- Authentication security
- Password-policy checks
- HTTP security checks
- Client-side checks
- Rate-limit testing
- GraphQL discovery

### Extended application checks

- CSV injection
- Content spoofing
- DNS misconfiguration
- Stored XSS
- Password-policy enforcement
- Session invalidation
- Concurrent-session controls
- Business logic
- SSTI
- XXE
- NoSQL injection
- CSP
- Subdomain takeover
- Wayback parameter discovery
- JWT analysis
- GraphQL security
- SSRF/cloud metadata
- Semgrep JavaScript analysis

### OWASP-oriented checks

The later execution group is intended to expand OWASP-oriented coverage and includes checks such as:

- Mass assignment
- TLS cipher analysis
- Command injection
- LDAP injection
- XPath injection
- Rate-limit bypass
- Race conditions
- CORS trusted-origin checks
- Debug endpoints
- Dependency scanning

The exact implementation and enabled behavior can change as the project evolves, so this document should be updated when the step runner changes.

## Important distinction

A scan step is a **check or workflow**, not necessarily a single vulnerability. A single step may invoke one or more external tools, custom Bash logic, HTTP requests, payloads, or library functions.

Likewise, the presence of a check does not mean a vulnerability will be found. Findings depend on the target, configuration, authentication state, network conditions, tool availability, and scan mode.
