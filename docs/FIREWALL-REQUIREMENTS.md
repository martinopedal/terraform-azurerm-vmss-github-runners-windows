# Firewall requirements

This document lists the egress required by the Windows VMSS GitHub runner module. The current ALZ use is personal sub-5, which uses NAT Gateway egress. If the module is ever used inside an AVNM-peered corp spoke, `alz-firewall-ops` must implement these requirements before the VMSS is routed through the hub firewall.

## Source identity

| Item | Value |
|---|---|
| Owning repo | `martinopedal/terraform-azurerm-vmss-github-runners-windows` |
| Consumer source | VMSS subnet supplied by the consuming repo |
| Current ALZ consumer | `martinopedal/personal-runners-infra` |
| Current source group | `ipg-vmss-personal-sub5`, informational only |
| Current egress | sub-5 NAT Gateway, not central firewall |
| Future firewall source | TODO when a corp Windows runner is reintroduced |

## Destination requirements

| Purpose | FQDNs | Ports and protocol | Why | Implemented in alz-firewall-ops |
|---|---|---|---|---|
| GitHub runner control | `github.com`, `api.github.com`, `*.github.com`, `*.actions.githubusercontent.com`, `vstoken.actions.githubusercontent.com` | TCP 443 | Runner registration, job polling, token exchange, and workflow control. | TODO for any future corp Windows source |
| GitHub content and packages | `codeload.github.com`, `objects.githubusercontent.com`, `objects-origin.githubusercontent.com`, `github-releases.githubusercontent.com`, `github-registry-files.githubusercontent.com`, `raw.githubusercontent.com`, `release-assets.githubusercontent.com`, `*.githubusercontent.com`, `*.blob.core.windows.net`, `ghcr.io`, `pkg-containers.githubusercontent.com`, `*.pkg.github.com` | TCP 443 | Runner binary updates, checkout, release assets, artifacts/cache, GHCR images, and GitHub Packages. | TODO for any future corp Windows source |
| Azure identity and ARM | `login.microsoftonline.com`, `login.windows.net`, `graph.microsoft.com`, `management.azure.com`, `*.management.azure.com` | TCP 443 | Managed identity, Key Vault auth, VMSS extensions, and Terraform/control-plane operations. | TODO for any future corp Windows source |
| Key Vault | `*.vault.azure.net`, `*.vaultcore.azure.net` | TCP 443 | Reads GitHub App private key and runner registration secrets. Private Endpoint is preferred where available. | TODO for any future corp Windows source |
| Monitoring and Automation | `*.monitor.azure.com`, `*.ingest.monitor.azure.com`, `*.handler.control.monitor.azure.com`, `*.ods.opinsights.azure.com`, `*.oms.opinsights.azure.com`, `*.azure-automation.net`, `*.agentsvc.azure-automation.net`, `*.guestconfiguration.azure.com` | TCP 443, optional TCP 5986 | Azure Monitor Agent, DSC/guest configuration, Automation hybrid worker, and WinRM HTTPS if used. | TODO for any future corp Windows source |
| Windows Update | `*.windowsupdate.com`, `*.update.microsoft.com`, `download.windowsupdate.com`, `*.dl.delivery.mp.microsoft.com` | TCP 80, TCP 443 | Windows Server patching and component downloads. | TODO for any future corp Windows source |
| Windows identity and activation | `*.windows.net`, `kms.core.windows.net`, `time.windows.com` | TCP 443, TCP 1688, UDP 123 | Azure AD device join where used, KMS activation, and clock sync. | TODO for any future corp Windows source |
| Windows package managers | `chocolatey.org`, `*.chocolatey.org`, `*.nuget.org`, `api.nuget.org`, `packages.microsoft.com`, `go.microsoft.com`, `aka.ms` | TCP 80, TCP 443 | Chocolatey, NuGet, Microsoft installers, and redirector chains used during bootstrap. | TODO for any future corp Windows source |
| DNS | Azure Firewall DNS proxy or Private DNS Resolver | UDP 53, TCP 53 | Name resolution when the VMSS subnet is hub-routed. | TODO for any future corp Windows source |

## Current personal deployment note

The current personal deployment does not require central firewall implementation because sub-5 is intentionally outside AVNM and hub routing. The destination list stays here for audit and future migration.
