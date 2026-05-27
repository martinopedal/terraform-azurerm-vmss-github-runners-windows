# Firewall requirements

This module hosts personal Windows GitHub Actions runners on sub-5. Sub-5 is the ALZ public runner carve-out: NAT Gateway egress, no firewall. These destinations are still listed for audit and for any future migration to centralized egress. Firewall implementation tracking, if required later, belongs in `alz-avm-tf-demo/alz-firewall-ops`.

## Required destinations for audit

| Destination | Port | Protocol | Purpose |
|---|---:|---|---|
| `github.com` | 443 | HTTPS | GitHub web, Git operations, and runner registration |
| `api.github.com` | 443 | HTTPS | Registration token and runner API calls |
| `*.actions.githubusercontent.com` | 443 | HTTPS | Actions service, OIDC, artifacts, and logs |
| `codeload.github.com` | 443 | HTTPS | Repository archive downloads |
| `results-receiver.actions.githubusercontent.com` | 443 | HTTPS | Actions result upload |
| `pipelines.actions.githubusercontent.com` | 443 | HTTPS | Actions pipeline orchestration |
| `objects.githubusercontent.com` | 443 | HTTPS | Release asset downloads |
| `objects-origin.githubusercontent.com` | 443 | HTTPS | Runner update downloads |
| `github-releases.githubusercontent.com` | 443 | HTTPS | Runner update downloads |
| `github-registry-files.githubusercontent.com` | 443 | HTTPS | Runner update downloads |
| `raw.githubusercontent.com` | 443 | HTTPS | Bootstrap script and raw file downloads |
| `release-assets.githubusercontent.com` | 443 | HTTPS | Release asset downloads |
| `*.pkg.github.com` | 443 | HTTPS | Optional GitHub Packages downloads |
| `pkg-containers.githubusercontent.com` | 443 | HTTPS | Optional GitHub Packages container layers |
| `ghcr.io` | 443 | HTTPS | Optional GitHub Container Registry pulls |
| `*.blob.core.windows.net` | 443 | HTTPS | Actions logs, artifacts, summaries, and caches |
| `login.microsoftonline.com` | 443 | HTTPS | Entra ID token issuance for managed identity and Azure login steps |
| `management.azure.com` | 443 | HTTPS | Azure Resource Manager for workflow Azure operations |
| `*.vault.azure.net` | 443 | HTTPS | Key Vault private key retrieval when public DNS resolves to vault endpoint |
| `169.254.169.254` | 80 | HTTP | Azure instance metadata service for managed identity tokens |

## Notes

- The module does not create firewall policy or UDR resources.
- NAT Gateway provides outbound internet for sub-5 runner instances.
- If central egress is introduced later, mirror these audit requirements into `alz-firewall-ops` and update this document with the PR link.
