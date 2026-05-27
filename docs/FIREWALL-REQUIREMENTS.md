# Firewall requirements

Implementation tracker if centralized egress is introduced later: [`alz-firewall-ops/docs/FIREWALL-EGRESS-IMPLEMENTED.md`](https://github.com/alz-avm-tf-demo/alz-firewall-ops/blob/main/docs/FIREWALL-EGRESS-IMPLEMENTED.md).

Personal Windows VMSS runners run in sub-5. Sub-5 uses NAT Gateway egress and is not in the AVNM/central firewall governance plane. These requirements are listed for audit and future firewall migration only.

## github.com

| Source identity | Destination service | FQDN | Port | Protocol |
|---|---|---|---:|---|
| VMSS runner service | GitHub web/API | `github.com` | 443 | HTTPS |
| VMSS runner service | GitHub API | `api.github.com` | 443 | HTTPS |
| VMSS runner service | Actions service and OIDC | `*.actions.githubusercontent.com` | 443 | HTTPS |
| VMSS runner service | Checkout archives | `codeload.github.com` | 443 | HTTPS |
| VMSS runner service | Actions results | `results-receiver.actions.githubusercontent.com` | 443 | HTTPS |
| VMSS runner service | Actions pipeline orchestration | `pipelines.actions.githubusercontent.com` | 443 | HTTPS |
| VMSS runner service | Raw content and bootstrap scripts | `raw.githubusercontent.com` | 443 | HTTPS |
| VMSS runner service | Release assets | `release-assets.githubusercontent.com` | 443 | HTTPS |
| VMSS runner service | Runner updates | `objects.githubusercontent.com` | 443 | HTTPS |
| VMSS runner service | Runner updates | `objects-origin.githubusercontent.com` | 443 | HTTPS |
| VMSS runner service | Runner updates | `github-releases.githubusercontent.com` | 443 | HTTPS |
| VMSS runner service | Runner updates | `github-registry-files.githubusercontent.com` | 443 | HTTPS |

## ghcr.io and packages

| Source identity | Destination service | FQDN | Port | Protocol |
|---|---|---|---:|---|
| VMSS runner service | GitHub Container Registry | `ghcr.io` | 443 | HTTPS |
| VMSS runner service | GHCR layers | `pkg-containers.githubusercontent.com` | 443 | HTTPS |
| VMSS runner service | GitHub Packages | `*.pkg.github.com` | 443 | HTTPS |

## GHA cache, artifacts, and logs

| Source identity | Destination service | FQDN | Port | Protocol |
|---|---|---|---:|---|
| VMSS runner service | Actions cache/artifacts/logs | `*.blob.core.windows.net` | 443 | HTTPS |

## Azure management and identity

| Source identity | Destination service | FQDN | Port | Protocol |
|---|---|---|---:|---|
| VMSS managed identity | Entra ID | `login.microsoftonline.com` | 443 | HTTPS |
| VMSS managed identity | Azure Resource Manager | `management.azure.com` | 443 | HTTPS |
| VMSS managed identity | Instance metadata service | `169.254.169.254` | 80 | HTTP |

## Key Vault

| Source identity | Destination service | FQDN | Port | Protocol |
|---|---|---|---:|---|
| VMSS managed identity | GitHub App private key secret | `*.vault.azure.net` | 443 | HTTPS |

## ACR

| Source identity | Destination service | FQDN | Port | Protocol |
|---|---|---|---:|---|
| VMSS runner service | Azure Container Registry used by workflows | `*.azurecr.io` | 443 | HTTPS |
| VMSS runner service | ACR backing storage | `*.blob.core.windows.net` | 443 | HTTPS |

## Monitoring

| Source identity | Destination service | FQDN | Port | Protocol |
|---|---|---|---:|---|
| VMSS diagnostics | Log Analytics ingestion | `*.ods.opinsights.azure.com` | 443 | HTTPS |
| VMSS diagnostics | Operations management | `*.oms.opinsights.azure.com` | 443 | HTTPS |
| VMSS diagnostics | Azure Monitor ingestion | `*.ingest.monitor.azure.com` | 443 | HTTPS |
| VMSS diagnostics | Azure Monitor API | `*.monitor.azure.com` | 443 | HTTPS |

## Windows update

| Source identity | Destination service | FQDN | Port | Protocol |
|---|---|---|---:|---|
| Windows VMSS instance | Windows Update | `*.windowsupdate.com` | 443 | HTTPS |
| Windows VMSS instance | Microsoft Update | `*.update.microsoft.com` | 443 | HTTPS |
| Windows VMSS instance | Delivery Optimization | `*.delivery.mp.microsoft.com` | 443 | HTTPS |
| Windows VMSS instance | Microsoft download CDN | `download.windowsupdate.com` | 80, 443 | HTTP, HTTPS |
