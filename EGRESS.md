# Network egress requirements

These egress FQDNs must be opened at the hub Azure Firewall for force-tunneled landing-zone spokes. Runners that egress through a NAT Gateway instead of a hub firewall do not need these openings, but the same dependency list applies; this file records the dependencies for audit and for any future force-tunneled migration.

The list below was derived from observed runner traffic and Azure Firewall deny logs. Validate any addition against your own deny logs before allowing it.

## GitHub Actions runner control plane

| FQDN | Port/proto | Why |
|---|---:|---|
| `github.com`, `*.github.com`, `api.github.com` | 443 HTTPS | GitHub web/API, runner registration, job polling |
| `*.actions.githubusercontent.com` | 443 HTTPS | Actions runtime, OIDC, pipeline orchestration |
| `vstoken.actions.githubusercontent.com`, `codeload.github.com`, `results-receiver.actions.githubusercontent.com` | 443 HTTPS | Token refresh, checkout archives, Actions results |
| `objects.githubusercontent.com`, `release-assets.githubusercontent.com` | 443 HTTPS | GitHub object/release downloads and tool redirects |
| `pkg-containers.githubusercontent.com`, `ghcr.io`, `*.ghcr.io` | 443 HTTPS | GHCR images and layers |
| `*.blob.core.windows.net` | 443 HTTPS | Actions cache, artifacts, logs; private DSC/config blobs when a consumer uses public blob FQDNs |

## Azure control plane, Key Vault, and VM extensions

| FQDN | Port/proto | Why |
|---|---:|---|
| `management.azure.com`, `management.core.windows.net` | 443 HTTPS | ARM control plane and compatibility endpoint |
| `login.microsoftonline.com`, `*.login.microsoftonline.com`, `login.microsoft.com`, `*.login.microsoft.com`, `login.windows.net`, `graph.microsoft.com`, `*.identity.azure.net` | 443 HTTPS | Entra ID, Graph, managed identity |
| `*.vault.azure.net`, `*.vaultcore.azure.net` | 443 HTTPS | GitHub App private key / PAT secret retrieval |
| `*.azure-automation.net`, `*.agentsvc.azure-automation.net`, `*.guestconfiguration.azure.com` | 443 HTTPS | Automation and Guest Configuration / DSC-adjacent services |
| `api.cloud.defender.microsoft.com` | 443 HTTPS | Defender for Cloud API |

## Monitoring

| FQDN | Port/proto | Why |
|---|---:|---|
| `*.monitor.azure.com`, `*.ods.opinsights.azure.com`, `*.oms.opinsights.azure.com`, `*.handler.control.monitor.azure.com`, `*.ingest.monitor.azure.com`, `global.handler.control.monitor.azure.com` | 443 HTTPS | Monitor/Log Analytics/AMA |

## Windows OS update and package bootstrap

| FQDN | Port/proto | Why |
|---|---:|---|
| `*.windowsupdate.com`, `*.update.microsoft.com`, `*.delivery.mp.microsoft.com`, `*.dl.delivery.mp.microsoft.com` | 443 HTTPS | Windows/Microsoft Update and Delivery Optimization |
| `packages.microsoft.com` | 443 HTTPS | Microsoft package feeds when workflows install Azure CLI or dotnet |

## Workflow package and build dependencies

| FQDN | Port/proto | Why |
|---|---:|---|
| `*.azurecr.io`, `*.data.azurecr.io` | 443 HTTPS | ACR used by workflows |
| `mcr.microsoft.com`, `*.data.mcr.microsoft.com`, `*.cdn.mscr.io` | 443 HTTPS | MCR image pulls used by workflows |
| `*.npmjs.org`, `*.npmjs.com`, `registry.npmjs.org`, `registry.yarnpkg.com` | 443 HTTPS | Node/Yarn package restore |
| `pypi.org`, `*.pypi.org`, `files.pythonhosted.org`, `releases.astral.sh` | 443 HTTPS | Python/uv package restore |
| `*.nuget.org`, `api.nuget.org` | 443 HTTPS | .NET package restore |
| `*.hashicorp.com`, `*.terraform.io`, `registry.terraform.io`, `releases.hashicorp.com`, `checkpoint-api.hashicorp.com` | 443 HTTPS | Terraform init/provider downloads/version check |
| `check.trivy.dev` | 443 HTTPS | Trivy vulnerability DB/version check |

## Candidate FQDNs to validate before allowing

Do not allow these until validated through your own firewall deny logs: `raw.githubusercontent.com` (some examples use it for bootstrap scripts), `www.powershellgallery.com` and PowerShell Gallery CDN endpoints, runner self-update hosts such as `objects-origin.githubusercontent.com`, and `*.pkg.github.com`.
