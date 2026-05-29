<#
.SYNOPSIS
    Bootstrap script for Windows GitHub Actions runner registration on VMSS.

.DESCRIPTION
    Two-stage bootstrap:
      Stage 1 (this script under Windows PowerShell 5.1, run by CSE as SYSTEM):
        - Logs early so we have observability if Stage 2 fails.
        - Installs PowerShell 7 (LTS) via the official Microsoft MSI if absent.
        - Re-executes itself under pwsh.exe and exits.

      Stage 2 (this script under PowerShell 7, re-entered with -Stage2):
        - Fetches the registration credential from Key Vault using the
          UAMI attached to the VMSS via IMDS.
        - When AppId + InstallationId + PrivateKeyPath are provided: builds
          an RS256 JWT from the App private key file, exchanges it for an
          installation token, then exchanges that for a repo runner
          registration token.
        - When App args are absent: falls back to PAT registration. PAT can
          be provided directly with -Pat or read from Key Vault.
        - Downloads + unpacks the GitHub Actions runner.
        - Registers as --ephemeral --unattended with --token (NEVER with
          a long-lived PAT/App key on disk).
        - Installs + starts the runner service.
        - Creates a 60s watchdog scheduled task that restarts the service
          if it stops (e.g. after an ephemeral job completes the VMSS
          autoscaler is expected to replace the instance, but the
          watchdog covers the gap).

.PARAMETER KeyVaultName
    Name of the Azure Key Vault holding the registration credential.

.PARAMETER GithubOwner
    GitHub owner (organization or user) that owns the target repos.

.PARAMETER GithubRepoList
    Comma-separated list of repositories for runner registration. The
    runner is registered against the FIRST repo in the list. (Multi-repo
    targeting is achieved via labels + GitHub workflow routing, not by
    registering one runner to many repos.)

.PARAMETER RunnerLabels
    Comma-separated list of runner labels appended to the default set.

.PARAMETER RunnerVersion
    GitHub Actions runner version (e.g., '2.319.1').

.PARAMETER AuthMethod
    'app' (default) | 'pat'.

.PARAMETER AppId
    GitHub App ID (required when -AuthMethod app).

.PARAMETER InstallationId
    GitHub App installation ID for the org/user (required when
    -AuthMethod app).

.PARAMETER PrivateKeyPath
    Path to a local PEM private key file written by the CSE protectedSettings
    command. Preferred App-auth path for v1.3.0.

.PARAMETER AppPrivateKeySecretName
    Name of the KV secret holding the App PEM private key. Used as a
    back-compat fallback when -PrivateKeyPath is not supplied.

.PARAMETER Pat
    Personal access token fallback. Prefer App auth; this direct value is
    accepted for back-compat with older CSE param surfaces.

.PARAMETER PatSecretName
    Name of the KV secret holding the PAT (only when -Pat is absent).
    Defaults to 'github-runner-pat'.

.PARAMETER Stage2
    Internal flag - set by Stage 1 when re-invoking under pwsh. Do not
    set manually.

.NOTES
    Executed by VMSS CustomScriptExtension on instance creation.
    Logs to C:\runner-bootstrap.log.
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$KeyVaultName,

    [Parameter(Mandatory = $true)]
    [string]$GithubOwner,

    [Parameter(Mandatory = $true)]
    [string]$GithubRepoList,

    [Parameter(Mandatory = $true)]
    [string]$RunnerLabels,

    [Parameter(Mandatory = $false)]
    [string]$RunnerVersion = "2.319.1",

    [Parameter(Mandatory = $false)]
    [ValidateSet("app", "pat")]
    [string]$AuthMethod = "app",

    [Parameter(Mandatory = $false)]
    [string]$AppId,

    [Parameter(Mandatory = $false)]
    [string]$InstallationId,

    [Parameter(Mandatory = $false)]
    [string]$PrivateKeyPath,

    [Parameter(Mandatory = $false)]
    [string]$AppPrivateKeySecretName = "github-app-private-key",

    [Parameter(Mandatory = $false)]
    [string]$Pat,

    [Parameter(Mandatory = $false)]
    [string]$PatSecretName = "github-runner-pat",

    [Parameter(Mandatory = $false)]
    [switch]$Stage2
)

$ErrorActionPreference = 'Stop'
$LogFile = "C:\runner-bootstrap.log"

function Write-Log {
    param([string]$Message)
    $ts = Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ"
    $line = "[$ts] $Message"
    Write-Host $line
    Add-Content -Path $LogFile -Value $line -Force
}

# ---------------------------------------------------------------------------
# Stage 1 - Windows PowerShell 5.1, install pwsh 7 and re-exec
# ---------------------------------------------------------------------------
if (-not $Stage2) {
    try {
        Write-Log "=== Stage 1: bootstrap start (PSVersion=$($PSVersionTable.PSVersion)) ==="

        $pwshExe = "C:\Program Files\PowerShell\7\pwsh.exe"
        if (-not (Test-Path $pwshExe)) {
            Write-Log "PowerShell 7 not found - installing via Microsoft MSI..."
            $msiUrl = "https://github.com/PowerShell/PowerShell/releases/download/v7.4.6/PowerShell-7.4.6-win-x64.msi"
            $msiPath = "$env:TEMP\PowerShell-7.4.6-win-x64.msi"

            [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
            Invoke-WebRequest -Uri $msiUrl -OutFile $msiPath -UseBasicParsing
            Write-Log "Downloaded $msiUrl"

            $p = Start-Process msiexec.exe -ArgumentList "/i `"$msiPath`" /quiet /norestart ADD_PATH=1" -Wait -PassThru
            if ($p.ExitCode -ne 0) {
                throw "PowerShell 7 MSI install failed with exit code $($p.ExitCode)"
            }
            Write-Log "PowerShell 7 installed"
        }
        else {
            Write-Log "PowerShell 7 already present"
        }

        Write-Log "Re-invoking under PowerShell 7..."
        $scriptPath = $PSCommandPath
        $argsList = @(
            "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "`"$scriptPath`"",
            "-Stage2",
            "-KeyVaultName", $KeyVaultName,
            "-GithubOwner", $GithubOwner,
            "-GithubRepoList", "`"$GithubRepoList`"",
            "-RunnerLabels", "`"$RunnerLabels`"",
            "-RunnerVersion", $RunnerVersion,
            "-AuthMethod", $AuthMethod,
            "-AppPrivateKeySecretName", $AppPrivateKeySecretName,
            "-PatSecretName", $PatSecretName
        )
        if ($AppId) { $argsList += @("-AppId", $AppId) }
        if ($InstallationId) { $argsList += @("-InstallationId", $InstallationId) }
        if ($PrivateKeyPath) { $argsList += @("-PrivateKeyPath", $PrivateKeyPath) }
        if ($Pat) { $argsList += @("-Pat", $Pat) }

        $p = Start-Process -FilePath $pwshExe -ArgumentList $argsList -Wait -PassThru -NoNewWindow
        Write-Log "Stage 2 exit code: $($p.ExitCode)"
        exit $p.ExitCode
    }
    catch {
        Write-Log "Stage 1 failed: $_"
        Write-Log $_.ScriptStackTrace
        exit 1
    }
}

# ---------------------------------------------------------------------------
# Stage 2 - PowerShell 7, full bootstrap
# ---------------------------------------------------------------------------

function Get-ImdsAccessToken {
    param([string]$Resource = "https://vault.azure.net")
    $base = "http://169.254.169.254/metadata/identity/oauth2/token"
    $body = @{
        'api-version' = '2018-02-01'
        'resource'    = $Resource
    }
    Write-Log "IMDS request: $base resource=$Resource"
    try {
        $resp = Invoke-RestMethod -Uri $base -Method Get -Body $body -Headers @{Metadata = "true" } -UseBasicParsing -TimeoutSec 30
    } catch {
        $bodyText = if ($_.ErrorDetails -and $_.ErrorDetails.Message) { $_.ErrorDetails.Message } else { $_.Exception.Message }
        throw "IMDS token acquisition failed for resource '$Resource': $bodyText"
    }
    if (-not $resp.access_token) {
        throw "IMDS response had no access_token. Raw: $($resp | ConvertTo-Json -Compress -Depth 5)"
    }
    return $resp.access_token
}

function Get-KeyVaultSecret {
    param(
        [string]$VaultName,
        [string]$SecretName,
        [string]$AccessToken
    )
    if (-not $VaultName) { throw "Get-KeyVaultSecret: VaultName empty" }
    if (-not $AccessToken) { throw "Get-KeyVaultSecret: AccessToken empty" }
    $base = "https://$VaultName.vault.azure.net/secrets/$SecretName"
    Write-Log "KV request: $base?api-version=7.4 (token length=$($AccessToken.Length))"
    try {
        $resp = Invoke-RestMethod -Uri $base -Method Get -Body @{ 'api-version' = '7.4' } -Headers @{Authorization = "Bearer $AccessToken" } -UseBasicParsing -TimeoutSec 30
    } catch {
        $bodyText = if ($_.ErrorDetails -and $_.ErrorDetails.Message) { $_.ErrorDetails.Message } else { $_.Exception.Message }
        throw "KV GET '$base' failed: $bodyText"
    }
    if (-not $resp.value) {
        throw "KV response had no value for secret '$SecretName'. Raw: $($resp | ConvertTo-Json -Compress -Depth 3)"
    }
    return $resp.value
}

function ConvertTo-Base64Url {
    param([byte[]]$Bytes)
    $b64 = [Convert]::ToBase64String($Bytes)
    return $b64.TrimEnd('=').Replace('+', '-').Replace('/', '_')
}

function New-GitHubAppJwt {
    param(
        [string]$AppIdValue,
        [string]$PemPrivateKey
    )

    $header = @{ alg = "RS256"; typ = "JWT" } | ConvertTo-Json -Compress
    $now = [int][double]::Parse((Get-Date -UFormat %s))
    $payload = @{
        iat = $now - 60
        exp = $now + (9 * 60)
        iss = $AppIdValue
    } | ConvertTo-Json -Compress

    $headerB64 = ConvertTo-Base64Url -Bytes ([Text.Encoding]::UTF8.GetBytes($header))
    $payloadB64 = ConvertTo-Base64Url -Bytes ([Text.Encoding]::UTF8.GetBytes($payload))
    $signingInput = "$headerB64.$payloadB64"

    $rsa = [System.Security.Cryptography.RSA]::Create()
    $rsa.ImportFromPem($PemPrivateKey)
    try {
        $signature = $rsa.SignData(
            [Text.Encoding]::UTF8.GetBytes($signingInput),
            [System.Security.Cryptography.HashAlgorithmName]::SHA256,
            [System.Security.Cryptography.RSASignaturePadding]::Pkcs1
        )
    }
    finally {
        $rsa.Dispose()
    }

    $sigB64 = ConvertTo-Base64Url -Bytes $signature
    return "$signingInput.$sigB64"
}

function Get-GitHubInstallationToken {
    param(
        [string]$Jwt,
        [string]$InstallationIdValue
    )
    $url = "https://api.github.com/app/installations/$InstallationIdValue/access_tokens"
    $headers = @{
        Authorization = "Bearer $Jwt"
        Accept        = "application/vnd.github+json"
        "User-Agent"  = "terraform-azurerm-vmss-github-runners-windows"
    }
    $resp = Invoke-RestMethod -Uri $url -Method Post -Headers $headers -UseBasicParsing
    return $resp.token
}

function Get-RunnerRegistrationToken {
    param(
        [string]$BearerToken,
        [string]$Owner,
        [string]$Repo
    )
    $url = "https://api.github.com/repos/$Owner/$Repo/actions/runners/registration-token"
    $headers = @{
        Authorization = "Bearer $BearerToken"
        Accept        = "application/vnd.github+json"
        "User-Agent"  = "terraform-azurerm-vmss-github-runners-windows"
    }
    $resp = Invoke-RestMethod -Uri $url -Method Post -Headers $headers -UseBasicParsing
    return $resp.token
}

try {
    Write-Log "=== Stage 2: bootstrap start (PSVersion=$($PSVersionTable.PSVersion)) ==="
    Write-Log "KeyVault=$KeyVaultName Owner=$GithubOwner Repos=$GithubRepoList Labels=$RunnerLabels RunnerVersion=$RunnerVersion AuthMethod=$AuthMethod"

    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

    # 1. KV access token via IMDS
    Write-Log "Acquiring Key Vault IMDS access token..."
    $kvToken = Get-ImdsAccessToken -Resource "https://vault.azure.net"

    # 2. Mint registration token per auth method. App auth wins only when all
    # App arguments are present; otherwise use the PAT path for back-compat.
    $repos = $GithubRepoList -split "," | ForEach-Object { $_.Trim() } | Where-Object { $_ }
    if ($repos.Count -lt 1) { throw "GithubRepoList is empty after parsing." }
    $targetRepo = $repos[0]
    Write-Log "Target repo for registration: $GithubOwner/$targetRepo"

    $useAppAuth = $AppId -and $InstallationId -and ($PrivateKeyPath -or $AppPrivateKeySecretName)
    if ($useAppAuth) {
        if ($PrivateKeyPath) {
            Write-Log "Reading App private key from protectedSettings file path..."
            $pem = Get-Content -Path $PrivateKeyPath -Raw
        }
        else {
            Write-Log "Fetching App private key from KV secret '$AppPrivateKeySecretName'..."
            $pem = Get-KeyVaultSecret -VaultName $KeyVaultName -SecretName $AppPrivateKeySecretName -AccessToken $kvToken
        }
        Write-Log "Building RS256 JWT for App $AppId..."
        $jwt = New-GitHubAppJwt -AppIdValue $AppId -PemPrivateKey $pem
        Write-Log "Exchanging JWT for installation token (installation $InstallationId)..."
        $instToken = Get-GitHubInstallationToken -Jwt $jwt -InstallationIdValue $InstallationId
        Write-Log "Minting runner registration token..."
        $regToken = Get-RunnerRegistrationToken -BearerToken $instToken -Owner $GithubOwner -Repo $targetRepo
    }
    else {
        if ($Pat) {
            Write-Log "Using PAT supplied by protected CSE settings..."
            $patValue = $Pat
        }
        else {
            Write-Log "Fetching PAT from KV secret '$PatSecretName'..."
            $patValue = Get-KeyVaultSecret -VaultName $KeyVaultName -SecretName $PatSecretName -AccessToken $kvToken
        }
        Write-Log "Minting runner registration token via PAT..."
        $regToken = Get-RunnerRegistrationToken -BearerToken $patValue -Owner $GithubOwner -Repo $targetRepo
    }

    if (-not $regToken) { throw "Failed to mint runner registration token." }
    Write-Log "Registration token acquired"

    # 3. Download + extract runner
    $runnerDir = "C:\actions-runner"
    if (-Not (Test-Path $runnerDir)) {
        New-Item -ItemType Directory -Path $runnerDir -Force | Out-Null
    }
    $runnerZip = "$runnerDir\actions-runner-win-x64.zip"
    $runnerUrl = "https://github.com/actions/runner/releases/download/v$RunnerVersion/actions-runner-win-x64-$RunnerVersion.zip"
    Write-Log "Downloading $runnerUrl..."
    Invoke-WebRequest -Uri $runnerUrl -OutFile $runnerZip -UseBasicParsing
    Write-Log "Extracting..."
    Expand-Archive -Path $runnerZip -DestinationPath $runnerDir -Force

    # 4. Register
    $repoUrl = "https://github.com/$GithubOwner/$targetRepo"
    Write-Log "Registering ephemeral runner against $repoUrl..."
    Push-Location $runnerDir
    try {
        $env:RUNNER_ALLOW_RUNASROOT = "1"
        & .\config.cmd --unattended `
            --url $repoUrl `
            --token $regToken `
            --labels $RunnerLabels `
            --ephemeral `
            --name "$env:COMPUTERNAME" `
            --work "_work"
        if ($LASTEXITCODE -ne 0) { throw "config.cmd exited with code $LASTEXITCODE" }
        Write-Log "Runner registered"

        # Ephemeral runner: invoke run.cmd via scheduled task so VMSS auto-instance-repair
        # re-images the VM after the runner exits (one job per VM lifetime).
        $taskName = "GHActionsRunner"
        $action = New-ScheduledTaskAction -Execute "$runnerDir\run.cmd"
        $trigger = New-ScheduledTaskTrigger -AtStartup
        $principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -RunLevel Highest
        $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable
        Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Principal $principal -Settings $settings -Force | Out-Null
        Start-ScheduledTask -TaskName $taskName
        Write-Log "Runner scheduled task '$taskName' installed and started"
        }
        finally {
            Pop-Location
        }

        # DSC (Layer 4) is owned by the DSC VM extension, NOT by this script.
        # The extension pulls the canonical config from alz-avm-tf-demo/dsc-configs
        # release-asset zip. See module main.vmss.tf dsc_* inputs.

        # 5. Watchdog
    Write-Log "Installing watchdog scheduled task..."
    $watchdog = @'
$svcs = Get-Service | Where-Object { $_.Name -like "actions.runner.*" }
foreach ($s in $svcs) {
    if ($s.Status -ne "Running") {
        Write-Host "Restarting $($s.Name)"
        Start-Service $s.Name
    }
}
'@
    $wdPath = "C:\runner-watchdog.ps1"
    Set-Content -Path $wdPath -Value $watchdog -Force -Encoding UTF8

    $action = New-ScheduledTaskAction -Execute "powershell.exe" `
        -Argument "-NoProfile -ExecutionPolicy Bypass -File $wdPath"
    $trigger = New-ScheduledTaskTrigger -Once -At (Get-Date) `
        -RepetitionInterval (New-TimeSpan -Seconds 60)
    $principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" `
        -LogonType ServiceAccount -RunLevel Highest
    Register-ScheduledTask -TaskName "GitHubRunnerWatchdog" `
        -Action $action -Trigger $trigger -Principal $principal -Force | Out-Null
    Write-Log "Watchdog installed"

    Write-Log "=== Stage 2: bootstrap complete ==="
    exit 0
}
catch {
    Write-Log "Stage 2 failed: $_"
    Write-Log $_.ScriptStackTrace
    exit 1
}
