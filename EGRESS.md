# Network egress requirements

These egress FQDNs must be opened at the hub Azure Firewall for force-tunneled spokes; see `alz-firewall-ops/FIREWALL-EGRESS-IMPLEMENTED.md` (canonical). Sub-5 personal Windows runners use NAT Gateway egress and are exempt from the hub firewall; this file records the same dependencies for audit and for any future force-tunneled migration.

Source of truth: `alz-avm-tf-demo/alz-firewall-ops` (`policy/fwp-hub-swedencentral/rcg-runners-alz.tf`, `rcg-baseline-app.tf`, `rcg-platform.tf`). Originally missed = discovered reactively from firewall denies / PRs #13, #16, #28, #29.

## GitHub Actions runner control plane

| FQDN | Port/proto | Why | Originally missed? |
|---|---:|---|---|
| `github.com`, `*.github.com`, `api.github.com` | 443 HTTPS | GitHub web/API, runner registration, job polling | No |
| `*.actions.githubusercontent.com` | 443 HTTPS | Actions runtime, OIDC, pipeline orchestration | Yes (#13/#29) |
| `vstoken.actions.githubusercontent.com`, `codeload.github.com`, `results-receiver.actions.githubusercontent.com` | 443 HTTPS | Token refresh, checkout archives, Actions results | Yes (#13) |
| `objects.githubusercontent.com`, `release-assets.githubusercontent.com` | 443 HTTPS | GitHub object/release downloads and tool redirects | `release-assets` yes (#29) |
| `pkg-containers.githubusercontent.com`, `ghcr.io`, `*.ghcr.io` | 443 HTTPS | GHCR images and layers | `pkg-containers` yes (#13) |
| `*.blob.core.windows.net` | 443 HTTPS | Actions cache, artifacts, logs; private DSC/config blobs if a consumer uses public blob FQDNs | Yes (#13) |

## Azure control plane, Key Vault, and VM extensions

| FQDN | Port/proto | Why | Originally missed? |
|---|---:|---|---|
| `management.azure.com`, `management.core.windows.net` | 443 HTTPS | ARM control plane and compatibility endpoint | `management.core` yes (#16) |
| `login.microsoftonline.com`, `*.login.microsoftonline.com`, `login.microsoft.com`, `*.login.microsoft.com`, `login.windows.net`, `graph.microsoft.com`, `*.identity.azure.net` | 443 HTTPS | Entra ID, Graph, managed identity | Regional/fallback/MSI yes (#16) |
| `*.vault.azure.net`, `*.vaultcore.azure.net` | 443 HTTPS | GitHub App private key / PAT secret retrieval | Yes (#16/#29) |
| `*.azure-automation.net`, `*.agentsvc.azure-automation.net`, `*.guestconfiguration.azure.com` | 443 HTTPS | Automation and Guest Configuration / DSC-adjacent services | Yes (#16/#29) |
| `api.cloud.defender.microsoft.com` | 443 HTTPS | Defender for Cloud API | Yes (#29) |

## Monitoring

| FQDN | Port/proto | Why | Originally missed? |
|---|---:|---|---|
| `*.monitor.azure.com`, `*.ods.opinsights.azure.com`, `*.oms.opinsights.azure.com`, `*.handler.control.monitor.azure.com`, `*.ingest.monitor.azure.com`, `global.handler.control.monitor.azure.com` | 443 HTTPS | Monitor/Log Analytics/AMA | Yes (#16/#29) |

## Windows OS update and package bootstrap

| FQDN | Port/proto | Why | Originally missed? |
|---|---:|---|---|
| `*.windowsupdate.com`, `*.update.microsoft.com`, `*.delivery.mp.microsoft.com`, `*.dl.delivery.mp.microsoft.com` | 443 HTTPS | Windows/Microsoft Update and Delivery Optimization | No |
| `packages.microsoft.com` | 443 HTTPS | Microsoft package feeds when workflows install Azure CLI/dotnet | Yes (#28) |

## Workflow package/build dependencies

| FQDN | Port/proto | Why | Originally missed? |
|---|---:|---|---|
| `*.azurecr.io`, `*.data.azurecr.io` | 443 HTTPS | ACR used by workflows | Yes (#16) |
| `mcr.microsoft.com`, `*.data.mcr.microsoft.com`, `*.cdn.mscr.io` | 443 HTTPS | MCR image pulls used by workflows | No |
| `*.npmjs.org`, `*.npmjs.com`, `registry.npmjs.org`, `registry.yarnpkg.com` | 443 HTTPS | Node/Yarn package restore | No |
| `pypi.org`, `*.pypi.org`, `files.pythonhosted.org`, `releases.astral.sh` | 443 HTTPS | Python/uv package restore | No |
| `*.nuget.org`, `api.nuget.org` | 443 HTTPS | .NET package restore | No |
| `*.hashicorp.com`, `*.terraform.io`, `registry.terraform.io`, `releases.hashicorp.com`, `checkpoint-api.hashicorp.com` | 443 HTTPS | Terraform init/provider downloads/version check | `checkpoint-api` yes (#28) |
| `check.trivy.dev` | 443 HTTPS | Trivy vulnerability DB/version check | Yes (#29) |

## Candidate gaps not implemented in alz-firewall-ops

Do not treat these as allowed until validated through firewall deny logs and added to `alz-firewall-ops`: `raw.githubusercontent.com` (some examples use it for bootstrap scripts), `www.powershellgallery.com` / PowerShell Gallery CDN endpoints, runner self-update hosts such as `objects-origin.githubusercontent.com`, and `*.pkg.github.com`.
