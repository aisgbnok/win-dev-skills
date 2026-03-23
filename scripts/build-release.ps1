#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Build a release bundle from local WinApp CLI artifacts.
.DESCRIPTION
    Bundles WinApp CLI portable executables with the Copilot CLI plugin
    and install scripts into a distributable zip.
.PARAMETER ArtifactsPath
    Path to WinApp CLI artifacts folder (contains cli/win-x64/ and cli/win-arm64/).
.PARAMETER Version
    Release version. If omitted, auto-bumps patch from plugin.json.
.PARAMETER Publish
    Publish the zip to GitHub Releases.
.EXAMPLE
    .\build-release.ps1 -ArtifactsPath E:\winappcli2\artifacts
    .\build-release.ps1 -ArtifactsPath E:\winappcli2\artifacts -Publish
#>
param(
    [Parameter(Mandatory=$true)]
    [string]$ArtifactsPath,

    [Parameter(Mandatory=$false)]
    [string]$Version,

    [Parameter(Mandatory=$false)]
    [switch]$Publish
)

$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path $PSCommandPath -Parent
$RepoRoot = Split-Path $ScriptDir -Parent
$PluginJsonPath = Join-Path $RepoRoot ".github\plugin\plugin.json"
$PluginDir = Join-Path $RepoRoot ".github\plugin"
$ReleaseRepo = "microsoft/win-dev-skills"

# ============================================================================
# Resolve version
# ============================================================================
function Get-CurrentVersion {
    $pluginData = Get-Content $PluginJsonPath -Raw | ConvertFrom-Json
    return $pluginData.version
}

function Get-NextVersion {
    $current = [System.Version]::New((Get-CurrentVersion))
    return "$($current.Major).$($current.Minor).$($current.Build + 1)"
}

if ([string]::IsNullOrEmpty($Version)) {
    if ($Publish) {
        $Version = Get-NextVersion
        Write-Host "[VERSION] Auto-bumped to v$Version" -ForegroundColor Magenta
    } else {
        $Version = Get-CurrentVersion
        Write-Host "[VERSION] Using current v$Version" -ForegroundColor Magenta
    }
} else {
    Write-Host "[VERSION] Using explicit v$Version" -ForegroundColor Magenta
}

Write-Host ""
Write-Host "================================================" -ForegroundColor Cyan
Write-Host "  Win-Dev-Skills Release Builder v$Version" -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan
Write-Host ""

# ============================================================================
# Validate inputs
# ============================================================================
Write-Host "[CHECK] Validating..." -ForegroundColor Blue

# Artifacts
$cliDir = Join-Path $ArtifactsPath "cli"
if (-not (Test-Path $cliDir)) {
    Write-Error "Artifacts path does not contain a cli/ directory: $ArtifactsPath"
    exit 1
}
$x64Exe = Join-Path $cliDir "win-x64\winapp.exe"
$arm64Exe = Join-Path $cliDir "win-arm64\winapp.exe"
if (-not (Test-Path $x64Exe) -and -not (Test-Path $arm64Exe)) {
    Write-Error "No winapp.exe found in $cliDir\win-x64\ or $cliDir\win-arm64\"
    exit 1
}
Write-Host "  [OK] WinApp CLI artifacts found" -ForegroundColor Green

# Plugin
if (-not (Test-Path $PluginDir)) {
    Write-Error "Plugin directory not found: $PluginDir"
    exit 1
}
Write-Host "  [OK] Plugin directory found" -ForegroundColor Green

# gh (only needed for publish)
if ($Publish) {
    if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
        Write-Error "GitHub CLI (gh) required for publishing. Install with: winget install GitHub.cli"
        exit 1
    }
    $null = gh auth status 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Error "GitHub CLI not authenticated. Run: gh auth login"
        exit 1
    }
    Write-Host "  [OK] GitHub CLI authenticated" -ForegroundColor Green
}

Write-Host ""

# ============================================================================
# Stage the bundle
# ============================================================================
$BundleName = "win-dev-skills-v$Version"
$StagingDir = Join-Path $RepoRoot "staging\$BundleName"
$ZipPath = Join-Path $RepoRoot "staging\$BundleName.zip"

# Clean staging
$stagingRoot = Join-Path $RepoRoot "staging"
if (Test-Path $stagingRoot) { Remove-Item $stagingRoot -Recurse -Force -ErrorAction SilentlyContinue }
New-Item -ItemType Directory -Path (Join-Path $StagingDir "tools") -Force | Out-Null

Write-Host "[1/3] Copying WinApp CLI..." -ForegroundColor Cyan
foreach ($arch in @("win-arm64", "win-x64")) {
    $srcDir = Join-Path $cliDir $arch
    if (Test-Path $srcDir) {
        $targetDir = Join-Path $StagingDir "tools\$arch"
        New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
        # Copy exe + all required dlls (e.g., libSkiaSharp.dll)
        Get-ChildItem $srcDir -File | Where-Object { $_.Extension -in '.exe', '.dll' -and $_.Name -ne '*.pdb' } | ForEach-Object {
            Copy-Item $_.FullName $targetDir -Force
            Write-Host "    - tools/$arch/$($_.Name) ($([math]::Round($_.Length / 1MB, 1)) MB)" -ForegroundColor Gray
        }
    }
}
Write-Host ""

Write-Host "[2/3] Copying plugin..." -ForegroundColor Cyan
# Update plugin.json version
$pluginData = Get-Content $PluginJsonPath -Raw | ConvertFrom-Json
if ($pluginData.version -ne $Version) {
    $pluginData.version = $Version
    $pluginData | ConvertTo-Json -Depth 10 | Set-Content -Path $PluginJsonPath -Encoding UTF8
    Write-Host "  Updated plugin.json version to $Version" -ForegroundColor Gray
}
Copy-Item $PluginDir (Join-Path $StagingDir "plugin") -Recurse -Force
Write-Host ""

# Copy install scripts
$bundleScriptsDir = Join-Path $StagingDir "scripts"
New-Item -ItemType Directory -Path $bundleScriptsDir -Force | Out-Null
Copy-Item (Join-Path $ScriptDir "install.ps1") (Join-Path $bundleScriptsDir "install.ps1") -Force

# Generate root install.cmd
$installCmdContent = @"
@echo off
echo.
echo ================================================
echo  Windows Development Skills - Installation
echo ================================================
echo.
powershell.exe -ExecutionPolicy Bypass -File "%~dp0scripts\install.ps1"
if %ERRORLEVEL% EQU 0 (
    echo.
    echo Installation completed successfully!
    echo Open a NEW terminal for PATH changes to take effect.
) else (
    echo.
    echo Installation encountered an error.
)
echo.
pause
"@
Set-Content -Path (Join-Path $StagingDir "install.cmd") -Value $installCmdContent -NoNewline

Write-Host "[3/3] Creating zip..." -ForegroundColor Cyan
Compress-Archive -Path "$StagingDir\*" -DestinationPath $ZipPath -Force
$zipSize = [math]::Round((Get-Item $ZipPath).Length / 1MB, 1)
Write-Host "  $ZipPath ($zipSize MB)" -ForegroundColor Gray
Write-Host ""

# ============================================================================
# Publish (optional)
# ============================================================================
if ($Publish) {
    Write-Host "[PUBLISH] Publishing v$Version to GitHub Releases..." -ForegroundColor Cyan

    # Commit version bump
    git -C $RepoRoot add $PluginJsonPath
    git -C $RepoRoot commit -m "Bump version to $Version" --allow-empty 2>$null
    git -C $RepoRoot push 2>$null

    # Create release
    gh release create "v$Version" $ZipPath --repo $ReleaseRepo --title "v$Version" --generate-notes
    Write-Host "[OK] Published v$Version" -ForegroundColor Green
} else {
    Write-Host "Zip created at: $ZipPath" -ForegroundColor Green
    Write-Host "To publish: .\build-release.ps1 -ArtifactsPath `"$ArtifactsPath`" -Version `"$Version`" -Publish" -ForegroundColor Gray
}
Write-Host ""