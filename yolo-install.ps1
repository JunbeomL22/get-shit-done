#Requires -Version 5.1
$ErrorActionPreference = 'Stop'

# Colors via ANSI (Windows Terminal / PS 7+ support)
$Cyan   = "`e[36m"
$Green  = "`e[32m"
$Yellow = "`e[33m"
$Dim    = "`e[2m"
$Reset  = "`e[0m"

# Fallback: strip ANSI if host doesn't support it
if ($PSVersionTable.PSVersion.Major -lt 7 -and $Host.UI.SupportsVirtualTerminal -ne $true) {
    $Cyan = ''; $Green = ''; $Yellow = ''; $Dim = ''; $Reset = ''
}

Write-Host ""
Write-Host "${Cyan}   ██████╗ ███████╗██████╗${Reset}"
Write-Host "${Cyan}  ██╔════╝ ██╔════╝██╔══██╗${Reset}"
Write-Host "${Cyan}  ██║  ███╗███████╗██║  ██║${Reset}"
Write-Host "${Cyan}  ██║   ██║╚════██║██║  ██║${Reset}"
Write-Host "${Cyan}  ╚██████╔╝███████║██████╔╝${Reset}"
Write-Host "${Cyan}   ╚═════╝ ╚══════╝╚═════╝${Reset}"
Write-Host ""
Write-Host "  YOLO Installer"
Write-Host ""

# ── Step 1: Ensure jq is installed ──────────────────────

function Install-JqBinary {
    $JqVersion = 'jq-1.7.1'
    $BaseUrl   = "https://github.com/jqlang/jq/releases/download/$JqVersion"
    $DestDir   = Join-Path $env:LOCALAPPDATA 'Programs\jq'

    $arch = if ([Environment]::Is64BitOperatingSystem) {
        if ($env:PROCESSOR_ARCHITECTURE -eq 'ARM64') { 'arm64' } else { 'amd64' }
    } else {
        Write-Host "  ${Yellow}!${Reset} Unsupported architecture"
        return $false
    }

    $Filename = "jq-windows-$arch.exe"

    if (-not (Test-Path $DestDir)) { New-Item -ItemType Directory -Path $DestDir -Force | Out-Null }

    $DestPath = Join-Path $DestDir 'jq.exe'
    Write-Host "  ${Dim}Downloading ${Filename}...${Reset}"

    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        Invoke-WebRequest -Uri "$BaseUrl/$Filename" -OutFile $DestPath -UseBasicParsing
    } catch {
        Write-Host "  ${Yellow}!${Reset} Download failed: $_"
        return $false
    }

    # Verify
    try {
        $ver = & $DestPath --version 2>&1
        Write-Host "  ${Green}>${Reset} jq installed to $DestPath ($ver)"
    } catch {
        Remove-Item -Force $DestPath -ErrorAction SilentlyContinue
        Write-Host "  ${Yellow}!${Reset} Downloaded binary failed verification"
        return $false
    }

    # Add to user PATH if not already there
    $userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
    if ($userPath -notlike "*$DestDir*") {
        [Environment]::SetEnvironmentVariable('Path', "$DestDir;$userPath", 'User')
        $env:Path = "$DestDir;$env:Path"
        Write-Host "  ${Yellow}i${Reset} Added $DestDir to user PATH (restart your terminal to pick it up)"
    }

    return $true
}

function Install-Jq {
    # Check if already available
    $jqCmd = Get-Command jq -ErrorAction SilentlyContinue
    if ($jqCmd) {
        $ver = & jq --version 2>&1
        Write-Host "  ${Green}>${Reset} jq is available ($ver)"
        return
    }

    Write-Host "  ${Yellow}i${Reset} jq not found - installing..."

    # Try winget first
    $winget = Get-Command winget -ErrorAction SilentlyContinue
    if ($winget) {
        Write-Host "  ${Dim}Trying winget...${Reset}"
        $result = & winget install jqlang.jq --accept-source-agreements --accept-package-agreements 2>&1
        # Refresh PATH
        $env:Path = [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' + [Environment]::GetEnvironmentVariable('Path', 'User')
        $jqCmd = Get-Command jq -ErrorAction SilentlyContinue
        if ($jqCmd) {
            $ver = & jq --version 2>&1
            Write-Host "  ${Green}>${Reset} jq installed via winget ($ver)"
            return
        }
    }

    # Try scoop
    $scoop = Get-Command scoop -ErrorAction SilentlyContinue
    if ($scoop) {
        Write-Host "  ${Dim}Trying scoop...${Reset}"
        & scoop install jq 2>&1 | Out-Null
        $jqCmd = Get-Command jq -ErrorAction SilentlyContinue
        if ($jqCmd) {
            $ver = & jq --version 2>&1
            Write-Host "  ${Green}>${Reset} jq installed via scoop ($ver)"
            return
        }
    }

    # Try choco
    $choco = Get-Command choco -ErrorAction SilentlyContinue
    if ($choco) {
        Write-Host "  ${Dim}Trying chocolatey...${Reset}"
        & choco install jq -y --no-progress 2>&1 | Out-Null
        $env:Path = [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' + [Environment]::GetEnvironmentVariable('Path', 'User')
        $jqCmd = Get-Command jq -ErrorAction SilentlyContinue
        if ($jqCmd) {
            $ver = & jq --version 2>&1
            Write-Host "  ${Green}>${Reset} jq installed via chocolatey ($ver)"
            return
        }
    }

    # Fallback: download static binary
    Write-Host "  ${Yellow}!${Reset} No package manager found. Downloading static binary..."
    $ok = Install-JqBinary
    if (-not $ok) {
        Write-Host "  ${Yellow}!${Reset} jq installation failed"
        exit 1
    }
}

# ── Step 2: Ensure Node.js is available ─────────────────

$nodeCmd = Get-Command node -ErrorAction SilentlyContinue
if (-not $nodeCmd) {
    Write-Host "  ${Yellow}x${Reset} Node.js is required but not found."
    Write-Host "    Install from: ${Cyan}https://nodejs.org${Reset}"
    exit 1
}

$nodeVer = & node --version 2>&1
Write-Host "  ${Green}>${Reset} Node.js $nodeVer"

# ── Step 3: Install jq ─────────────────────────────────

Install-Jq

# ── Step 4: Run GSD installer ──────────────────────────

Write-Host ""
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
& node (Join-Path $ScriptDir 'bin\install.js') --skip-jq @args
