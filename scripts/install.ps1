#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Installer for Windows Development Skills toolkit.
.DESCRIPTION
    Installs from the extracted release bundle:
    - WinApp CLI (portable executable added to PATH)
    - Copilot CLI plugin (agents and skills for Windows development)

    Run this script from inside the extracted release zip.
    No internet, authentication, or admin privileges required.
.PARAMETER Uninstall
    Remove all installed components.
.EXAMPLE
    .\install.ps1
.EXAMPLE
    .\install.ps1 -Uninstall
#>
param(
    [switch]$Uninstall
)

$ErrorActionPreference = "Stop"

# --- Unblock downloaded files ---
Write-Host "Checking for blocked files..." -ForegroundColor Gray
$ScriptPath = $PSCommandPath
if ($ScriptPath -and (Test-Path $ScriptPath)) {
    try {
        $ScriptDir = Split-Path $ScriptPath -Parent
        Get-ChildItem -Path $ScriptDir -Recurse -File -ErrorAction SilentlyContinue | ForEach-Object {
            Unblock-File -Path $_.FullName -ErrorAction SilentlyContinue
        }
    } catch { }
}

# --- Error trap ---
trap {
    Write-Host "`nERROR: $_" -ForegroundColor Red
    if ($_.Exception) { Write-Host $_.Exception.Message -ForegroundColor Yellow }
    exit 1
}

# --- Shared paths ---
$ToolsTarget = Join-Path $env:USERPROFILE ".winapp\tools"
$AgentDir = Join-Path $env:USERPROFILE ".winapp"
$PluginTarget = Join-Path $env:USERPROFILE ".copilot\agents\win-dev-skills"

# ============================================================================
# Uninstall mode
# ============================================================================
if ($Uninstall) {
    Write-Host ""
    Write-Host "================================================" -ForegroundColor Yellow
    Write-Host "  Windows Development Skills - Uninstall" -ForegroundColor Yellow
    Write-Host "================================================" -ForegroundColor Yellow
    Write-Host ""

    $itemsToRemove = @()
    if (Test-Path $ToolsTarget) { $itemsToRemove += "  - WinApp CLI: $ToolsTarget" }
    if (Test-Path $PluginTarget) { $itemsToRemove += "  - Copilot plugin: $PluginTarget" }
    $itemsToRemove += "  - PATH entry for tools directory"

    foreach ($item in $itemsToRemove) { Write-Host $item -ForegroundColor Gray }
    Write-Host ""

    $response = Read-Host "Proceed with uninstall? (Y/N)"
    if ($response -ne 'Y' -and $response -ne 'y') {
        Write-Host "[CANCELLED]" -ForegroundColor Yellow
        exit 0
    }
    Write-Host ""

    # Remove tools directory
    if (Test-Path $ToolsTarget) {
        Remove-Item $ToolsTarget -Recurse -Force
        Write-Host "[OK] Removed tools directory" -ForegroundColor Green
    } else {
        Write-Host "[SKIP] Tools directory not found" -ForegroundColor Gray
    }

    # Remove parent .winapp if empty
    if ((Test-Path $AgentDir) -and @(Get-ChildItem $AgentDir -Force -ErrorAction SilentlyContinue).Count -eq 0) {
        Remove-Item $AgentDir -Force
    }

    # Remove tools from user PATH
    $userPath = [Environment]::GetEnvironmentVariable("PATH", [EnvironmentVariableTarget]::User)
    if ($userPath) {
        $parts = $userPath -split ";" | Where-Object { $_ -ne $ToolsTarget -and $_ -ne "" }
        $newPath = $parts -join ";"
        if ($newPath -ne $userPath) {
            [Environment]::SetEnvironmentVariable("PATH", $newPath, [EnvironmentVariableTarget]::User)
            Write-Host "[OK] Removed tools directory from user PATH" -ForegroundColor Green
        } else {
            Write-Host "[SKIP] Tools directory was not on PATH" -ForegroundColor Gray
        }
    }

    # Remove Copilot plugin
    $copilotAvailable = $false
    try { $null = Get-Command copilot -ErrorAction Stop; $copilotAvailable = $true } catch { }

    if ($copilotAvailable) {
        $pluginList = & copilot plugin list 2>&1
        if ($pluginList -match "win-dev-skills") {
            & copilot plugin uninstall win-dev-skills 2>&1 | Out-Null
            Write-Host "[OK] Removed Copilot plugin" -ForegroundColor Green
        } else {
            Write-Host "[SKIP] Copilot plugin not installed" -ForegroundColor Gray
        }
    } else {
        Write-Host "[SKIP] Copilot CLI not installed" -ForegroundColor Gray
    }

    # Also remove legacy .winui3-agent directory if it exists
    $legacyDir = Join-Path $env:USERPROFILE ".winui3-agent"
    if (Test-Path $legacyDir) {
        Remove-Item $legacyDir -Recurse -Force -ErrorAction SilentlyContinue
        Write-Host "[OK] Removed legacy .winui3-agent directory" -ForegroundColor Green
    }

    Write-Host ""
    Write-Host "Uninstall complete. Open a NEW terminal for PATH changes." -ForegroundColor Green
    Write-Host ""
    exit 0
}

# ============================================================================
# Install mode
# ============================================================================
Write-Host ""
Write-Host "================================================" -ForegroundColor Cyan
Write-Host "  Windows Development Skills - Installer" -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "  1. Copy WinApp CLI to ~/.winapp/tools/" -ForegroundColor Gray
Write-Host "  2. Add tools directory to your user PATH" -ForegroundColor Gray
Write-Host "  3. Install Copilot CLI plugin" -ForegroundColor Gray
Write-Host ""

$response = Read-Host "Proceed with installation? (Y/N)"
if ($response -ne 'Y' -and $response -ne 'y') {
    Write-Host "[CANCELLED]" -ForegroundColor Yellow
    exit 0
}
Write-Host ""

$ScriptDir = Split-Path $PSCommandPath -Parent

# Find bundle root (tools/ can be sibling of script or sibling of parent)
$BundleRoot = $ScriptDir
if (-not (Test-Path (Join-Path $BundleRoot "tools")) -and (Test-Path (Join-Path (Split-Path $BundleRoot -Parent) "tools"))) {
    $BundleRoot = Split-Path $BundleRoot -Parent
}
$ToolsSrcDir = Join-Path $BundleRoot "tools"
$PluginDir = Join-Path $BundleRoot "plugin"

# ============================================================================
# Step 0: Check for conflicting MSIX-installed winapp
# ============================================================================
$winappMsix = Get-AppxPackage -Name "winapp" -ErrorAction SilentlyContinue
$winappDevMsix = Get-AppxPackage -Name "winapp-dev" -ErrorAction SilentlyContinue
$conflicts = @()
if ($winappMsix) { $conflicts += $winappMsix }
if ($winappDevMsix) { $conflicts += $winappDevMsix }

if ($conflicts.Count -gt 0) {
    Write-Host "  Found MSIX-installed WinApp that will conflict:" -ForegroundColor Yellow
    foreach ($pkg in $conflicts) { Write-Host "    - $($pkg.Name) v$($pkg.Version)" -ForegroundColor Yellow }
    Write-Host ""
    $uninstallResponse = Read-Host "  Uninstall these MSIX packages? (Y/N)"
    if ($uninstallResponse -eq 'Y' -or $uninstallResponse -eq 'y') {
        foreach ($pkg in $conflicts) {
            try {
                Remove-AppxPackage -Package $pkg.PackageFullName -ErrorAction Stop
                Write-Host "  [OK] Removed $($pkg.Name)" -ForegroundColor Green
            } catch {
                Write-Host "  [WARN] Could not remove $($pkg.Name): $_" -ForegroundColor Yellow
            }
        }
    }
    Write-Host ""
}

# ============================================================================
# Step 1: Install WinApp CLI
# ============================================================================
Write-Host "[1/3] Installing WinApp CLI..." -ForegroundColor Cyan

# Detect architecture
$ArchDir = switch ($env:PROCESSOR_ARCHITECTURE) {
    "AMD64" { "win-x64" }
    "ARM64" { "win-arm64" }
    default { "win-x64" }
}
Write-Host "  Architecture: $env:PROCESSOR_ARCHITECTURE -> $ArchDir" -ForegroundColor Gray

if (-not (Test-Path $ToolsTarget)) {
    New-Item -ItemType Directory -Path $ToolsTarget -Force | Out-Null
}

$archSrcDir = Join-Path $ToolsSrcDir $ArchDir
if (Test-Path $archSrcDir) {
    # Copy all files (exe + dlls like libSkiaSharp.dll)
    $files = Get-ChildItem -Path $archSrcDir -File
    foreach ($f in $files) {
        Copy-Item $f.FullName $ToolsTarget -Force
        Write-Host "  - $($f.Name) ($([math]::Round($f.Length / 1MB, 1)) MB)" -ForegroundColor Gray
    }
    Write-Host "[OK] WinApp CLI installed to $ToolsTarget" -ForegroundColor Green
} else {
    Write-Warning "No tools found for $ArchDir in bundle"
}

# Add to user PATH
$userPath = [Environment]::GetEnvironmentVariable("PATH", [EnvironmentVariableTarget]::User)
if (-not $userPath) { $userPath = "" }
if ($userPath -split ";" | Where-Object { $_ -eq $ToolsTarget }) {
    Write-Host "[OK] Tools directory already on PATH" -ForegroundColor Green
} else {
    $newPath = if ($userPath) { "$userPath;$ToolsTarget" } else { $ToolsTarget }
    [Environment]::SetEnvironmentVariable("PATH", $newPath, [EnvironmentVariableTarget]::User)
    Write-Host "[OK] Added to user PATH" -ForegroundColor Green
}
if ($env:PATH -notlike "*$ToolsTarget*") { $env:PATH = "$ToolsTarget;$env:PATH" }
Write-Host ""

# ============================================================================
# Step 2: Install WinUI 3 templates (from public NuGet.org)
# ============================================================================
Write-Host "[2/3] Checking WinUI 3 project templates..." -ForegroundColor Cyan

$dotnetAvailable = $false
try { $null = Get-Command dotnet -ErrorAction Stop; $dotnetAvailable = $true } catch { }

if ($dotnetAvailable) {
    $templatePkg = "Microsoft.WindowsAppSDK.WinUI.CSharp.Templates"
    $existingTemplates = dotnet new list winui 2>$null
    if ($existingTemplates -match "winui") {
        Write-Host "[OK] WinUI 3 templates already installed" -ForegroundColor Green
    } else {
        Write-Host "  Installing WinUI 3 templates from NuGet.org..." -ForegroundColor Gray
        dotnet new install $templatePkg 2>$null | Out-Null
        Write-Host "[OK] WinUI 3 templates installed (dotnet new winui)" -ForegroundColor Green
    }
} else {
    Write-Host "[SKIP] .NET SDK not found — install it, then run: dotnet new install Microsoft.WindowsAppSDK.WinUI.CSharp.Templates" -ForegroundColor Yellow
}
Write-Host ""

# ============================================================================
# Step 3: Install Copilot CLI plugin
# ============================================================================
Write-Host "[3/3] Installing Copilot CLI plugin..." -ForegroundColor Cyan

$copilotAvailable = $false
try { $null = Get-Command copilot -ErrorAction Stop; $copilotAvailable = $true } catch { }

if (-not $copilotAvailable) {
    $installResponse = Read-Host "  Copilot CLI not found. Install via winget? (Y/N)"
    if ($installResponse -eq 'Y' -or $installResponse -eq 'y') {
        winget install --id GitHub.Copilot --source winget --accept-package-agreements --accept-source-agreements 2>$null
        $env:PATH = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
        try { $null = Get-Command copilot -ErrorAction Stop; $copilotAvailable = $true } catch { }
    }
}

if ($copilotAvailable -and (Test-Path $PluginDir)) {
    $installOutput = & copilot plugin install $PluginDir 2>&1
    Write-Host "  $installOutput" -ForegroundColor Gray
    Write-Host "[OK] Copilot CLI plugin installed" -ForegroundColor Green
} elseif (-not (Test-Path $PluginDir)) {
    Write-Host "[SKIP] Plugin directory not found" -ForegroundColor Yellow
} else {
    Write-Host "[SKIP] Install Copilot CLI first, then run: copilot plugin install `"$PluginDir`"" -ForegroundColor Yellow
}
Write-Host ""

# ============================================================================
# Summary
# ============================================================================
Write-Host "================================================" -ForegroundColor Green
Write-Host "  Installation Complete!" -ForegroundColor Green
Write-Host "================================================" -ForegroundColor Green
Write-Host ""
if (Get-Command winapp -ErrorAction SilentlyContinue) {
    Write-Host "    [x] WinApp CLI" -ForegroundColor Green
} else {
    Write-Host "    [!] WinApp CLI — open a NEW terminal" -ForegroundColor Yellow
}
if ($copilotAvailable) {
    Write-Host "    [x] Copilot CLI plugin — run 'copilot' to start" -ForegroundColor Green
} else {
    Write-Host "    [ ] Copilot CLI — install it, then re-run" -ForegroundColor Yellow
}
Write-Host ""
Write-Host "  Open a NEW terminal, then: copilot" -ForegroundColor Cyan
Write-Host ""