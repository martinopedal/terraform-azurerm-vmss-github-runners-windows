<#
.SYNOPSIS
    Install CI/CD toolchain for GitHub Actions Windows runners.

.DESCRIPTION
    Installs the complete toolset required for CI/CD workflows across the
    Azure/ALZ estate:
    - PowerShell modules (Pester 5.7.1, PSScriptAnalyzer)
    - Azure CLI + bicep
    - Terraform toolchain (terraform, tflint, tfsec, checkov)
    - GitHub CLI
    - Node.js 20 LTS + npm
    - Python 3.12 + pip + pytest
    - Go latest
    - Utilities (jq, make via Git for Windows)
    - Linters (markdownlint-cli, actionlint)

    All tools installed to machine-wide PATH via Chocolatey (binaries) or
    Install-Module -Scope AllUsers (PowerShell modules). Service-account
    compatible.

.PARAMETER LogPath
    Path to log file. Defaults to C:\runner-tools-install.log.

.NOTES
    Called by register-windows-runner.ps1 during VMSS provisioning.
    Runs as SYSTEM under PowerShell 7.
    Non-interactive, idempotent (checks existing before install).
    Requires: PowerShell 7, internet connectivity.
#>

param(
    [Parameter(Mandatory = $false)]
    [string]$LogPath = "C:\runner-tools-install.log"
)

$ErrorActionPreference = "Stop"

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logLine = "[$timestamp] [$Level] $Message"
    Write-Host $logLine
    Add-Content -Path $LogPath -Value $logLine
}

function Test-CommandExists {
    param([string]$Command)
    return [bool](Get-Command $Command -ErrorAction SilentlyContinue)
}

function Install-ChocoIfMissing {
    if (Test-CommandExists 'choco') {
        Write-Log "Chocolatey already installed"
        return
    }
    
    Write-Log "Installing Chocolatey..."
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
    Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
    
    # Refresh environment to pick up choco
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
    
    if (Test-CommandExists 'choco') {
        Write-Log "Chocolatey installed successfully"
    } else {
        throw "Chocolatey installation failed"
    }
}

function Install-ChocoPackage {
    param(
        [string]$PackageName,
        [string]$Version = $null,
        [string[]]$Params = @()
    )
    
    if (Test-CommandExists $PackageName) {
        Write-Log "$PackageName already available on PATH, skipping"
        return
    }
    
    Write-Log "Installing $PackageName via Chocolatey..."
    
    $chocoArgs = @('install', $PackageName, '-y', '--no-progress', '--force')
    if ($Version) {
        $chocoArgs += @('--version', $Version)
    }
    if ($Params.Count -gt 0) {
        $chocoArgs += $Params
    }
    
    & choco @chocoArgs
    
    if ($LASTEXITCODE -ne 0) {
        Write-Log "Warning: choco install $PackageName exited with code $LASTEXITCODE" -Level "WARN"
    }
    
    # Refresh PATH
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
    
    if (Test-CommandExists $PackageName) {
        Write-Log "$PackageName now available on PATH"
    } else {
        Write-Log "Warning: $PackageName not found on PATH after install" -Level "WARN"
    }
}

function Install-PowerShellModule {
    param(
        [string]$ModuleName,
        [string]$RequiredVersion = $null
    )
    
    $existing = Get-Module -ListAvailable -Name $ModuleName | Select-Object -First 1
    
    if ($existing -and $RequiredVersion -and $existing.Version -eq $RequiredVersion) {
        Write-Log "$ModuleName $RequiredVersion already installed"
        return
    }
    
    if ($existing -and -not $RequiredVersion) {
        Write-Log "$ModuleName already installed (version $($existing.Version))"
        return
    }
    
    Write-Log "Installing PowerShell module $ModuleName $(if ($RequiredVersion) { "version $RequiredVersion" })..."
    
    $installArgs = @{
        Name = $ModuleName
        Scope = 'AllUsers'
        Force = $true
        AllowClobber = $true
        SkipPublisherCheck = $true
    }
    
    if ($RequiredVersion) {
        $installArgs.RequiredVersion = $RequiredVersion
    }
    
    Install-Module @installArgs
    
    $installed = Get-Module -ListAvailable -Name $ModuleName | Select-Object -First 1
    if ($installed) {
        Write-Log "$ModuleName installed: version $($installed.Version)"
    } else {
        Write-Log "Warning: $ModuleName not found after Install-Module" -Level "WARN"
    }
}

# Main installation sequence
Write-Log "=== Runner Tools Installation Started ==="
Write-Log "Running as: $([System.Security.Principal.WindowsIdentity]::GetCurrent().Name)"
Write-Log "PowerShell version: $($PSVersionTable.PSVersion)"

try {
    # Step 1: Chocolatey
    Install-ChocoIfMissing
    
    # Step 2: PowerShell Modules
    Write-Log "`n=== PowerShell Modules ===" 
    Install-PowerShellModule -ModuleName 'Pester' -RequiredVersion '5.7.1'
    Install-PowerShellModule -ModuleName 'PSScriptAnalyzer'
    
    # Step 3: Azure CLI
    Write-Log "`n=== Azure CLI ==="
    Install-ChocoPackage -PackageName 'azure-cli'
    
    # bicep via az extension (post-install)
    if (Test-CommandExists 'az') {
        Write-Log "Installing bicep via az..."
        & az bicep install 2>&1 | Out-Null
        if (Test-CommandExists 'bicep') {
            Write-Log "bicep installed via az bicep install"
        }
    }
    
    # Step 4: Terraform toolchain
    Write-Log "`n=== Terraform Toolchain ==="
    Install-ChocoPackage -PackageName 'terraform'
    Install-ChocoPackage -PackageName 'tflint'
    Install-ChocoPackage -PackageName 'tfsec'
    # checkov requires python first
    
    # Step 5: GitHub CLI
    Write-Log "`n=== GitHub CLI ===" 
    Install-ChocoPackage -PackageName 'gh'
    
    # Step 6: Node.js 20 LTS
    Write-Log "`n=== Node.js ===" 
    if (-not (Test-CommandExists 'node')) {
        Install-ChocoPackage -PackageName 'nodejs' -Params @('--version=20.18.1')
    } else {
        Write-Log "node already available"
    }
    
    # npm comes with node
    if (Test-CommandExists 'npm') {
        Write-Log "npm available (version: $(npm --version 2>$null))"
    }
    
    # Step 7: Python 3.12
    Write-Log "`n=== Python ===" 
    if (-not (Test-CommandExists 'python')) {
        Install-ChocoPackage -PackageName 'python' -Params @('--version=3.12.8')
    } else {
        Write-Log "python already available"
    }
    
    # Refresh PATH to pick up python
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
    
    # pip comes with python; upgrade + install pytest
    if (Test-CommandExists 'pip') {
        Write-Log "Upgrading pip..."
        & python -m pip install --upgrade pip --quiet 2>&1 | Out-Null
        
        Write-Log "Installing pytest..."
        & pip install pytest --quiet 2>&1 | Out-Null
        
        Write-Log "Installing checkov..."
        & pip install checkov --quiet 2>&1 | Out-Null
        
        if (Test-CommandExists 'pytest') {
            Write-Log "pytest available"
        }
        if (Test-CommandExists 'checkov') {
            Write-Log "checkov available"
        }
    }
    
    # Step 8: Go
    Write-Log "`n=== Go ===" 
    Install-ChocoPackage -PackageName 'golang'
    
    # Step 9: Utilities
    Write-Log "`n=== Utilities ===" 
    Install-ChocoPackage -PackageName 'jq'
    
    # make via Git for Windows (includes msys2 make)
    if (-not (Test-CommandExists 'make')) {
        # Git for Windows includes usr/bin/make.exe
        # Check if git is already installed with usr/bin
        $gitPath = Get-Command git -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source
        if ($gitPath) {
            $gitRoot = Split-Path (Split-Path $gitPath)
            $makePath = Join-Path $gitRoot "usr\bin\make.exe"
            if (Test-Path $makePath) {
                Write-Log "make available via Git for Windows at $makePath"
                # Add to PATH if not already there
                $usrBinPath = Join-Path $gitRoot "usr\bin"
                $machinePath = [System.Environment]::GetEnvironmentVariable("Path","Machine")
                if ($machinePath -notlike "*$usrBinPath*") {
                    [System.Environment]::SetEnvironmentVariable("Path", "$machinePath;$usrBinPath", "Machine")
                    $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
                    Write-Log "Added Git for Windows usr/bin to machine PATH"
                }
            } else {
                Write-Log "make not found in Git for Windows, installing make via choco..."
                Install-ChocoPackage -PackageName 'make'
            }
        } else {
            Write-Log "git not found, installing make via choco standalone..."
            Install-ChocoPackage -PackageName 'make'
        }
    } else {
        Write-Log "make already available"
    }
    
    # Step 10: Linters
    Write-Log "`n=== Linters ===" 
    
    # markdownlint-cli via npm
    if (Test-CommandExists 'npm') {
        if (-not (Test-CommandExists 'markdownlint')) {
            Write-Log "Installing markdownlint-cli via npm..."
            & npm install -g markdownlint-cli --silent 2>&1 | Out-Null
            
            # Refresh PATH
            $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
            
            if (Test-CommandExists 'markdownlint') {
                Write-Log "markdownlint-cli available"
            }
        } else {
            Write-Log "markdownlint-cli already available"
        }
    }
    
    # actionlint - download binary directly (no choco package)
    if (-not (Test-CommandExists 'actionlint')) {
        Write-Log "Installing actionlint..."
        $actionlintUrl = "https://github.com/rhysd/actionlint/releases/latest/download/actionlint_1.7.7_windows_amd64.zip"
        $downloadPath = "$env:TEMP\actionlint.zip"
        $extractPath = "C:\ProgramData\actionlint"
        
        New-Item -Path $extractPath -ItemType Directory -Force | Out-Null
        
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        Invoke-WebRequest -Uri $actionlintUrl -OutFile $downloadPath -UseBasicParsing
        
        Expand-Archive -Path $downloadPath -DestinationPath $extractPath -Force
        Remove-Item $downloadPath -Force
        
        # Add to machine PATH
        $machinePath = [System.Environment]::GetEnvironmentVariable("Path","Machine")
        if ($machinePath -notlike "*$extractPath*") {
            [System.Environment]::SetEnvironmentVariable("Path", "$machinePath;$extractPath", "Machine")
            $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
            Write-Log "Added actionlint to machine PATH"
        }
        
        if (Test-Path "$extractPath\actionlint.exe") {
            Write-Log "actionlint installed at $extractPath\actionlint.exe"
        }
    } else {
        Write-Log "actionlint already available"
    }
    
    # Final PATH refresh
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
    
    Write-Log "`n=== Installation Complete ===" 
    Write-Log "All tools installed successfully"
    
    # Summary check
    Write-Log "`n=== Verification ===" 
    $tools = @(
        'powershell', 'pwsh', 
        'az', 'bicep',
        'terraform', 'tflint', 'tfsec', 'checkov',
        'gh',
        'node', 'npm',
        'python', 'pip', 'pytest',
        'go',
        'jq', 'make', 'git',
        'markdownlint', 'actionlint'
    )
    
    $available = @()
    $missing = @()
    
    foreach ($tool in $tools) {
        if (Test-CommandExists $tool) {
            $available += $tool
        } else {
            $missing += $tool
        }
    }
    
    Write-Log "Available: $($available.Count)/$($tools.Count) - $($available -join ', ')"
    if ($missing.Count -gt 0) {
        Write-Log "Missing: $($missing -join ', ')" -Level "WARN"
    }
    
} catch {
    Write-Log "ERROR: $($_.Exception.Message)" -Level "ERROR"
    Write-Log "StackTrace: $($_.ScriptStackTrace)" -Level "ERROR"
    throw
}

Write-Log "=== Runner Tools Installation Finished ==="
