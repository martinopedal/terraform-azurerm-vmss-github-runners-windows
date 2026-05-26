<#
.SYNOPSIS
    DSC configuration for GitHub Actions runner service self-heal.

.DESCRIPTION
    PowerShell Desired State Configuration (DSC) that continuously enforces
    GitHub Actions runner service state every 15 minutes.
    
    Enforcement:
    - Service exists (actions.runner.*)
    - Service state: Running
    - Startup type: Automatic
    
    LCM Configuration:
    - ConfigurationMode: ApplyAndAutoCorrect (re-enforce on drift)
    - ConfigurationModeFrequencyMins: 15
    - RebootNodeIfNeeded: $false (Spot-friendly, no spontaneous reboots)

.NOTES
    This script is executed by the DSC VM extension on VMSS instances.
    3-layer self-heal: DSC (15min) → Auto-Repair (30min) → Spot Eviction (1-5min)
#>

Configuration GitHubRunnerDSC
{
    Import-DscResource -ModuleName PSDesiredStateConfiguration

    Node localhost
    {
        # Enforce runner service state
        Service GitHubRunnerService
        {
            Name        = "actions.runner.*"
            State       = "Running"
            StartupType = "Automatic"
            Ensure      = "Present"
        }
    }
}

# Configure Local Configuration Manager (LCM)
[DSCLocalConfigurationManager()]
Configuration LCMConfig
{
    Node localhost
    {
        Settings
        {
            ActionAfterReboot              = 'ContinueConfiguration'
            ConfigurationMode              = 'ApplyAndAutoCorrect'
            ConfigurationModeFrequencyMins = 15
            RebootNodeIfNeeded             = $false
            RefreshMode                    = 'Push'
        }
    }
}

# Apply LCM configuration
LCMConfig -OutputPath "C:\DSC"
Set-DscLocalConfigurationManager -Path "C:\DSC" -Verbose -Force

# Compile and apply DSC configuration
GitHubRunnerDSC -OutputPath "C:\DSC"
Start-DscConfiguration -Path "C:\DSC" -Wait -Verbose -Force

Write-Host "✅ DSC configuration applied successfully"
Write-Host "Runner service will be enforced every 15 minutes"
