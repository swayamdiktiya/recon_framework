#!/usr/bin/env python3
import sys
import subprocess
import re

def strip_ansi(text):
    text = re.sub(r'\x1b\[[0-9;]*[a-zA-Z]', '', text)
    return text

def get_dns_info(domain):
    try:
        # Get CNAME
        cname_proc = subprocess.run(['dig', '+short', 'CNAME', domain, '@8.8.8.8'], capture_output=True, text=True, timeout=5)
        cname = cname_proc.stdout.strip().rstrip('.')
        
        # Get A records
        ips_proc = subprocess.run(['dig', '+short', 'A', domain, '@8.8.8.8'], capture_output=True, text=True, timeout=5)
        ips = [line.strip() for line in ips_proc.stdout.split('\n') if line.strip()]
        return cname, ips
    except Exception:
        return "", []

def is_cloudflare_ip(ip):
    # Cloudflare IPv4 ranges prefixes
    cf_prefixes = (
        "103.21.244.", "103.22.200.", "103.31.4.", "104.16.", "104.17.", "104.18.", "104.19.", "104.20.", "104.21.", "104.22.",
        "104.23.", "104.24.", "104.25.", "104.26.", "104.27.", "104.28.", "104.29.", "104.30.", "104.31.", "108.162.",
        "131.27.0.", "141.101.", "162.158.", "162.159.", "172.64.", "172.65.", "172.66.", "172.67.", "172.68.", "172.69.",
        "172.70.", "172.71.", "173.245.", "185.220.101.", "188.114.", "190.93.", "197.234.240.", "197.234.241.", "197.234.242.",
        "197.234.243.", "198.41.", "199.27.128.", "199.58.80.", "199.58.81.", "199.58.82.", "199.58.83."
    )
    return ip.startswith(cf_prefixes)

def verify(domain, service):
    cname, ips = get_dns_info(domain)
    
    # 1. Check Cloudflare
    is_cf = False
    if "cloudflare" in cname.lower() or "argotunnel" in cname.lower():
        is_cf = True
    for ip in ips:
        if is_cloudflare_ip(ip):
            is_cf = True
            
    # Cloudflare SaaS false positive check
    if is_cf:
        fp_services = ["cargo", "uptimerobot", "mailgun", "shopify", "heroku", "ghost", "zendesk", "squarespace", "wpengine"]
        for s in fp_services:
            if s in service.lower():
                return False, f"Cloudflare SaaS protection/hijack blocked (resolves to Cloudflare)"
        if not cname:
            return False, "Resolves directly to Cloudflare IPs (protected)"

    # 2. Strict whitelist verification for takeover targets
    # Suffixes of services that are known to be vulnerable to takeovers
    HIGH_CONFIDENCE_CNAMES = [
        ".github.io",
        ".herokuapp.com",
        ".herokudns.com",
        ".s3.amazonaws.com",
        ".s3-website",
        ".s3.website",
        ".cloudfront.net",
        ".azurewebsites.net",
        ".azureedge.net",
        ".wpsho.st",
        ".wpengine.com",
        ".netlify.app",
        ".vercel.app",
        ".pages.dev",
        ".firebaseapp.com",
        ".bitbucket.io",
        ".pantheonsite.io",
        ".myreadspaces.com"
    ]
    
    if not cname:
        return False, "No CNAME record found"
        
    has_valid_cname = False
    for suffix in HIGH_CONFIDENCE_CNAMES:
        if cname.lower().endswith(suffix):
            has_valid_cname = True
            break
            
    if not has_valid_cname:
        return False, f"CNAME '{cname}' does not match any high-confidence vulnerable provider whitelist"
        
    return True, f"CNAME: {cname}, IPs: {', '.join(ips)}"

def main():
    if len(sys.argv) < 3:
        print("Usage: verify_takeovers.py <subzy_results_file> <output_file>")
        sys.exit(1)
        
    results_file = sys.argv[1]
    output_file = sys.argv[2]
    
    with open(results_file, 'r') as f:
        raw_content = f.read()
        
    content = strip_ansi(raw_content)
    
    # Match new subzy format:
    # [ VULNERABLE ]  -  domain  [ Service ]
    matches = re.findall(r'\[\s*VULNERABLE\s*\]\s*-\s*([^\s\[\n]+)\s*\[\s*([^\]\n]+)\s*\]', content, re.IGNORECASE)
    
    # Also fallback to legacy format if no matches:
    # domain [Service]
    if not matches:
        matches = re.findall(r'([^\s\[]+)\s*\[([^\]]+)\]', content)
        
    verified_count = 0
    with open(output_file, 'w') as out:
        for domain, service in matches:
            domain = domain.strip()
            service = service.strip()
            # Basic sanity check to avoid matching noise
            if not domain or domain in ['-', 'VULNERABLE', 'DISCUSSION', 'DOCUMENTATION', '-----------------']:
                continue
            if '.' not in domain:
                continue
                
            ok, reason = verify(domain, service)
            if ok:
                out.write(f"[CONFIRMED TAKEOVER] {domain} -> {service} ({reason})\n")
                verified_count += 1
            else:
                print(f"[SKIP] {domain} ({service}): {reason}")
                
    print(f"Verification complete. Found {verified_count} confirmed takeovers.")

if __name__ == '__main__':
    main()
