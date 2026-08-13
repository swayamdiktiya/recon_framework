# Recon Framework

A modular Bash-based reconnaissance and web security assessment orchestrator designed to bring a large collection of security tools and repeatable checks into one workflow.

> **⚠️ Legal & ethical use**
>
> Use this framework only against systems you own or have explicit permission to test. The framework includes active scanning, fuzzing, authentication testing, injection checks, and other security assessment capabilities. You are responsible for complying with applicable laws, contracts, and program rules.

## What it does

Recon Framework automates reconnaissance and security checks from a single command while keeping the individual checks organized into reusable library modules.

The current `recon.sh` entry point provides **83 numbered scan steps (0–82)** and supports quick, full, stealth, fast, scoped, authenticated, OOB/SSRF, and JSON-output workflows. fileciteturn3file0

### Main capabilities

- CDN/origin discovery and bypass checks
- Port scanning and ASN/IP mapping
- Subdomain enumeration and permutation discovery
- Endpoint, parameter, directory, and content discovery
- DNS and TLS/SSL analysis
- WAF and technology fingerprinting
- Nuclei and DAST-based vulnerability scanning
- OSINT and historical URL/parameter discovery
- Authentication and session-security checks
- Injection testing, including XSS, SQLi, SSTI, XXE, NoSQL, LDAP, XPath, and command-injection checks
- GraphQL discovery and security checks
- SSRF/OOB detection with Interactsh support
- Cloud-storage and cloud-metadata checks
- Secrets and dependency scanning
- JWT analysis
- CORS, CSP, security-header, and TLS-cipher checks
- Race-condition, rate-limit, business-logic, mass-assignment, and session-control checks
- Structured findings with confidence levels and redaction support

## Scan flow

The framework starts with legal authorization confirmation, initializes the output directory, loads authentication headers, applies scope controls, performs tool preflight checks, and then executes the selected scan steps. fileciteturn3file0

By default, the framework runs all available steps. Individual steps or ranges can be selected with `-s`.

## Usage

```bash
chmod +x recon.sh
./recon.sh [OPTIONS] <target>
```

### Common options

| Option | Description |
|---|---|
| `-y` | Auto-confirm the legal notice |
| `-M` | Use masscan for a full 65535-port scan |
| `-m <mode>` | Scan mode: `quick`, `full`, or `stealth` |
| `-s <steps>` | Run selected steps, e.g. `0,1,5` or `14-32` |
| `-r <ip_range>` | Scan an IP/CIDR range |
| `-o <dir>` | Override the output directory |
| `-n <mode>` | Select Nuclei mode |
| `-c <cookie>` | Add a cookie for authenticated scanning |
| `-C <cookie>` | Add a second user's cookie for cross-user IDOR comparison |
| `-H <header>` | Add an HTTP header; repeatable |
| `-A <file>` | Load extra headers from a file |
| `-x` | Enable SSRF/OOB detection |
| `-f` | Force a full 65535-port Nmap scan |
| `-j` | Produce the final summary as JSON |
| `-F` | Fast mode with reduced targets/payloads |
| `-S <file>` | Apply allow/deny scope rules |
| `-h` | Show help |

These options are defined by the current `recon.sh` interface. fileciteturn3file0

### Examples

Quick scan:

```bash
./recon.sh example.com
```

Fast scan:

```bash
./recon.sh -F example.com
```

Run selected steps:

```bash
./recon.sh -s 0,1,3,5,15-23 example.com
```

Authenticated assessment:

```bash
./recon.sh -c 'session=YOUR_AUTHORIZED_SESSION' example.com
```

JSON summary:

```bash
./recon.sh -j example.com
```

For authenticated testing, only use credentials/session material belonging to an authorized test account.

## Architecture

The main script is intentionally modular. It sources dedicated libraries for configuration, core utilities, CDN bypass, port scanning, subdomains, endpoints, miscellaneous checks, HTTP security, injection, authentication, information disclosure, JavaScript analysis, GraphQL, OWASP checks, OOB testing, and P1 checks. fileciteturn3file0

The core library also provides common logging, retry/timeout handling, parallel execution, DNS helpers, step selection, temporary-file cleanup, parameter helpers, secret redaction, and structured finding support. fileciteturn4file0

## Tooling

The current preflight section checks **50 executable/system dependencies**. The complete inventory is documented in [`TOOLS.md`](TOOLS.md).

The framework also uses configurable wordlists, DNS/HTTP resources, CDN IP ranges, and security-header definitions. fileciteturn5file0

## Output

Each run creates a timestamped output directory unless `-o` is supplied. The framework records a run log and can produce structured findings/JSON output. fileciteturn3file0

## False-positive reduction

The framework includes helpers for learning soft-404 behavior and validating real HTTP responses using status, response size, and required content signatures instead of treating every HTTP 200 response as a finding. This is intended to reduce noisy endpoint/file exposure results. fileciteturn4file0

## Security and scope controls

The framework supports a scope file with allow/deny host regular expressions and checks the target against that scope before scanning. Authentication headers can also be supplied through command-line options or a header file. fileciteturn3file0

## Project status

Recon Framework is an actively developed personal security-testing project. Tool availability, scan steps, payloads, and checks may change between versions.

## Disclaimer

This project is provided for authorized security research, defensive testing, education, and assessment of systems where you have permission. It is not intended to encourage unauthorized scanning or exploitation.

## License

No license is currently specified in this repository. Until a license is added, the default copyright rules apply and reuse/redistribution should not be assumed to be permitted.
