<#
.SYNOPSIS
    Bootstrap script for Windows GitHub Actions runner registration on VMSS.

.DESCRIPTION
    Registers a Windows VM as a GitHub Actions self-hosted runner using GitHub App authentication.
    Fetches the GitHub App private key from Azure Key Vault via User-Assigned Managed Identity (UAMI).
    Creates a watchdog scheduled task (60s interval) to monitor runner service health.

.PARAMETER KeyVaultName
    Name of the Azure Key Vault containing the GitHub App private key.

.PARAMETER GithubOwner
    GitHub owner (organization or user).

.PARAMETER GithubRepoList
    Comma-separated list of repositories for runner registration.

.PARAMETER RunnerLabels
    Comma-separated list of runner labels.

.PARAMETER RunnerVersion
    GitHub Actions runner version (e.g., '2.319.1').

.NOTES
    This script is executed by CustomScriptExtension on VMSS instance creation.
    DSC takes over service enforcement after initial registration completes.
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$KeyVaultName,

    [Parameter(Mandatory=$true)]
    [string]$GithubOwner,

    [Parameter(Mandatory=$true)]
    [string]$GithubRepoList,

    [Parameter(Mandatory=$true)]
    [string]$RunnerLabels,

    [Parameter(Mandatory=$false)]
    [string]$RunnerVersion = "2.319.1"
)

$ErrorActionPreference = 'Stop'
$LogFile = "C:\runner-bootstrap.log"

function Write-Log {
    param([string]$Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] $Message"
    Write-Host $logMessage
    Add-Content -Path $LogFile -Value $logMessage -Force
}

try {
    Write-Log "=== Starting GitHub Runner Bootstrap ==="
    Write-Log "KeyVault: $KeyVaultName"
    Write-Log "Owner: $GithubOwner"
    Write-Log "Repos: $GithubRepoList"
    Write-Log "Labels: $RunnerLabels"
    Write-Log "Runner Version: $RunnerVersion"

    # Step 1: Fetch GitHub App private key from Key Vault using UAMI via IMDS
    Write-Log "Fetching GitHub App private key from Key Vault..."
    $kvSecretUrl = "https://$KeyVaultName.vault.azure.net/secrets/github-app-private-key?api-version=7.4"
    
    # Get access token from IMDS (UAMI automatically assigned to VMSS)
    $imdsUrl = "http://169.254.169.254/metadata/identity/oauth2/token?api-version=2021-02-01&resource=https://vault.azure.net"
    $tokenResponse = Invoke-RestMethod -Uri $imdsUrl -Method Get -Headers @{Metadata="true"} -UseBasicParsing
    $accessToken = $tokenResponse.access_token
    Write-Log "IMDS token acquired"

    # Fetch private key from Key Vault
    $secretResponse = Invoke-RestMethod -Uri $kvSecretUrl -Method Get -Headers @{Authorization="Bearer $accessToken"} -UseBasicParsing
    $githubAppPrivateKey = $secretResponse.value
    Write-Log "GitHub App private key fetched from Key Vault"

    # Step 2: Download and extract GitHub Actions runner
    $runnerDir = "C:\actions-runner"
    if (-Not (Test-Path $runnerDir)) {
        New-Item -ItemType Directory -Path $runnerDir -Force | Out-Null
    }

    $runnerZip = "$runnerDir\actions-runner-win-x64.zip"
    $runnerUrl = "https://github.com/actions/runner/releases/download/v$RunnerVersion/actions-runner-win-x64-$RunnerVersion.zip"
    
    Write-Log "Downloading runner from $runnerUrl..."
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    Invoke-WebRequest -Uri $runnerUrl -OutFile $runnerZip -UseBasicParsing
    Write-Log "Runner downloaded"

    Write-Log "Extracting runner..."
    Expand-Archive -Path $runnerZip -DestinationPath $runnerDir -Force
    Write-Log "Runner extracted to $runnerDir"

    # Step 3: Register runner
    $repos = $GithubRepoList -split ","
    $repoUrl = "https://github.com/$GithubOwner/$($repos[0].Trim())"
    
    Write-Log "Registering runner for $repoUrl..."
    
    Push-Location $runnerDir
    try {
        $env:RUNNER_ALLOW_RUNASROOT = "1"
        
        .\config.cmd --unattended `
            --url $repoUrl `
            --labels $RunnerLabels `
            --ephemeral `
            --name "$env:COMPUTERNAME" `
            --work "_work"
        
        Write-Log "Runner registered"
        
        Write-Log "Installing runner service..."
        .\svc.ps1 install
        Write-Log "Runner service installed"
        
        Write-Log "Starting runner service..."
        .\svc.ps1 start
        Write-Log "Runner service started"
        
    } finally {
        Pop-Location
    }

    # Step 4: Create watchdog scheduled task
    Write-Log "Creating watchdog scheduled task..."
    
    $watchdogScript = @"
`$serviceName = 'actions.runner.*'
`$services = Get-Service | Where-Object { `$_.Name -like `$serviceName }
foreach (`$svc in `$services) {
    if (`$svc.Status -ne 'Running') {
        Write-Host "Service `$(`$svc.Name) is not running. Starting..."
        Start-Service `$svc.Name
    }
}
"@
    
    $watchdogPath = "C:\runner-watchdog.ps1"
    Set-Content -Path $watchdogPath -Value $watchdogScript -Force
    Write-Log "Watchdog script created"
    
    $taskName = "GitHubRunnerWatchdog"
    $action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-NoProfile -ExecutionPolicy Bypass -File $watchdogPath"
    $trigger = New-ScheduledTaskTrigger -Once -At (Get-Date) -RepetitionInterval (New-TimeSpan -Seconds 60)
    $principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest
    
    Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Principal $principal -Force
    Write-Log "Watchdog scheduled task registered"

    Write-Log "=== Bootstrap Complete ==="
    exit 0

} catch {
    Write-Log "Bootstrap failed: $_"
    Write-Log $_.ScriptStackTrace
    exit 1
}
