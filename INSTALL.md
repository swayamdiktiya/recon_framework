# Installation & Setup

Recon Framework is a Bash-based orchestrator that relies on a collection of external security tools. The framework performs a preflight check before scanning and reports which dependencies are available or missing.

> **Authorization required:** install and use the framework for systems you own or are explicitly authorized to assess.

## 1. Clone the repository

```bash
git clone https://github.com/swayamdiktiya/recon_framework.git
cd recon_framework
```

## 2. Make the framework executable

```bash
chmod +x recon.sh
```

## 3. Install dependencies

The current preflight inventory contains 50 executable/system dependencies. See [`TOOLS.md`](TOOLS.md) for the complete list.

There is intentionally no single universal package-manager command in this guide because several dependencies are distributed through different ecosystems (for example Go binaries, Python packages, standalone projects, and system packages).

Install the tools you need from their official project documentation, then make sure their executables are available in `$PATH`.

## 4. Verify dependencies

Run the framework against an authorized target. The preflight stage will print each dependency as available or missing.

```bash
./recon.sh -h
```

Then perform a scan only against an authorized target:

```bash
./recon.sh example.com
```

The preflight output includes an `Available` and `Missing` count.

## 5. Wordlists and data

The framework can use configurable wordlist and external-data locations. The current configuration defines cache and wordlist directories and URLs for DNS and web-content wordlists, plus CDN IP-range sources. fileciteturn5file0

Default configuration includes:

- `~/.cache/recon`
- `~/wordlists`
- SecLists DNS wordlist
- SecLists web-content wordlist
- Cloudflare IP ranges
- Fastly IP ranges
- AWS IP ranges

Review `lib/config.sh.lib` before using the framework in an environment with restricted network access.

## 6. Basic scan

```bash
./recon.sh example.com
```

The framework creates a timestamped output directory by default. fileciteturn3file0

## 7. Faster scan

```bash
./recon.sh -F example.com
```

Fast mode reduces the number of targets/payloads used by applicable checks.

## 8. Select specific checks

Run selected steps:

```bash
./recon.sh -s 0,1,3,5 example.com
```

Run a range:

```bash
./recon.sh -s 14-32 example.com
```

The framework supports individual steps, comma-separated steps, and ranges through the `-s` option. fileciteturn3file0

## 9. Authenticated scanning

Use an authorized test account when testing authenticated functionality.

Cookie:

```bash
./recon.sh -c 'session=AUTHORIZED_SESSION' example.com
```

Additional headers:

```bash
./recon.sh -H 'Authorization: Bearer AUTHORIZED_TOKEN' example.com
```

Headers can also be supplied through a file with `-A`. A second cookie can be supplied with `-C` for cross-user comparison checks such as IDOR testing. fileciteturn3file0

Never commit real credentials, session tokens, API keys, or other secrets to the repository.

## 10. OOB / SSRF testing

```bash
./recon.sh -x example.com
```

This enables the framework's out-of-band testing path, including Interactsh integration where configured. Only perform these tests within an authorized assessment scope.

## 11. Scope control

A scope file can be supplied with `-S`:

```bash
./recon.sh -S scope.txt example.com
```

The framework checks the target against the configured scope before continuing with the scan. fileciteturn3file0

## 12. JSON output

```bash
./recon.sh -j example.com
```

Use JSON output when integrating results into another workflow.

## Troubleshooting

### A tool is shown as missing

Confirm that the executable is installed and available through `$PATH`:

```bash
command -v TOOL_NAME
```

Then rerun the preflight stage.

### A target is unreachable

The framework checks HTTPS and then HTTP connectivity before deep scanning. An unreachable target does not necessarily cause an immediate exit; the framework may continue and record the condition. fileciteturn3file0

### Too much traffic

Use `-F`, a narrower step selection with `-s`, or an appropriate scan mode. Always follow the authorization and rate limits of the environment being tested.
