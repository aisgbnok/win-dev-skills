#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Installer for Windows Development Skills toolkit.
.DESCRIPTION
    Installs the complete Windows development toolkit from the extracted bundle:
    - WinApp CLI and Raka CLI (portable executables added to PATH)
    - NuGet packages (registered as a user-level NuGet source)
    - WinUI 3 project templates
    - Copilot CLI plugin

    Run this script from inside the extracted release zip.
    No internet, authentication, or admin privileges required.
.EXAMPLE
    .\install.ps1
#>

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
        Write-Host "  - Unblocked bundle files" -ForegroundColor Gray
    } catch { }
}

# --- Error trap ---
trap {
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Red
    Write-Host "  ERROR OCCURRED" -ForegroundColor Red
    Write-Host "========================================" -ForegroundColor Red
    Write-Host ""
    Write-Host "Error: $_" -ForegroundColor Red
    Write-Host ""

    if ($_.Exception) {
        Write-Host "Details:" -ForegroundColor Yellow
        Write-Host $_.Exception.Message -ForegroundColor Yellow
        Write-Host ""
    }

    exit 1
}

Write-Host ""
Write-Host "================================================" -ForegroundColor Cyan
Write-Host "  Windows Development Skills - Installer" -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "This installer will:" -ForegroundColor White
Write-Host ""
Write-Host "  1. Copy WinApp CLI and Raka CLI to ~/.winui3-agent/tools/" -ForegroundColor Gray
Write-Host "  2. Add tools directory to your user PATH" -ForegroundColor Gray
Write-Host "  3. Copy NuGet packages and register a NuGet source" -ForegroundColor Gray
Write-Host "  4. Install WinUI 3 project templates (if included)" -ForegroundColor Gray
Write-Host "  5. Install Copilot CLI plugin" -ForegroundColor Gray
Write-Host ""
Write-Host "No admin privileges required. All changes are user-scoped." -ForegroundColor DarkGray
Write-Host ""

$response = Read-Host "Proceed with installation? (Y/N)"
if ($response -ne 'Y' -and $response -ne 'y') {
    Write-Host "[CANCELLED]" -ForegroundColor Yellow
    exit 0
}
Write-Host ""

$ScriptDir = Split-Path $PSCommandPath -Parent
$ToolsSrcDir = Join-Path $ScriptDir "tools"
$NugetsDir = Join-Path $ScriptDir "nugets"
$PluginDir = Join-Path $ScriptDir "plugin"

$ToolsTarget = Join-Path $env:USERPROFILE ".winui3-agent\tools"
$NugetsTarget = Join-Path $env:USERPROFILE ".winui3-agent\nugets"

# ============================================================================
# Step 1: Install CLI tools (copy executables + add to PATH)
# ============================================================================
Write-Host "[1/5] Installing CLI tools..." -ForegroundColor Cyan
Write-Host ""

# Detect architecture
$CurrentArch = $env:PROCESSOR_ARCHITECTURE
$ArchDir = switch ($CurrentArch) {
    "AMD64" { "win-x64" }
    "ARM64" { "win-arm64" }
    default { "win-x64" }
}
Write-Host "  Architecture: $CurrentArch -> $ArchDir" -ForegroundColor Gray

# Create tools directory
if (-not (Test-Path $ToolsTarget)) {
    New-Item -ItemType Directory -Path $ToolsTarget -Force | Out-Null
}

# Copy tools for this architecture
$archSrcDir = Join-Path $ToolsSrcDir $ArchDir
$toolsCopied = 0

if (Test-Path $archSrcDir) {
    $exeFiles = Get-ChildItem -Path $archSrcDir -Filter "*.exe"
    foreach ($exe in $exeFiles) {
        Copy-Item $exe.FullName $ToolsTarget -Force
        Write-Host "  - $($exe.Name) -> $ToolsTarget" -ForegroundColor Gray
        $toolsCopied++
    }
} else {
    Write-Warning "No tools found for architecture $ArchDir in bundle"
    Write-Host "  Available: $(Get-ChildItem $ToolsSrcDir -Directory -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Name)" -ForegroundColor Yellow
}

if ($toolsCopied -gt 0) {
    Write-Host "[OK] $toolsCopied tool(s) installed to $ToolsTarget" -ForegroundColor Green
}

# Add to user PATH if not already present
$userPath = [Environment]::GetEnvironmentVariable("PATH", [EnvironmentVariableTarget]::User)
if (-not $userPath) { $userPath = "" }

if ($userPath -split ";" | Where-Object { $_ -eq $ToolsTarget }) {
    Write-Host "[OK] Tools directory already on PATH" -ForegroundColor Green
} else {
    $newPath = if ($userPath) { "$userPath;$ToolsTarget" } else { $ToolsTarget }
    [Environment]::SetEnvironmentVariable("PATH", $newPath, [EnvironmentVariableTarget]::User)
    Write-Host "[OK] Added $ToolsTarget to user PATH" -ForegroundColor Green
}

# Update current session PATH too
if ($env:PATH -notlike "*$ToolsTarget*") {
    $env:PATH = "$ToolsTarget;$env:PATH"
}

Write-Host ""

# ============================================================================
# Step 2: Copy NuGet packages
# ============================================================================
Write-Host "[2/5] Installing NuGet packages..." -ForegroundColor Cyan
Write-Host ""

if (-not (Test-Path $NugetsTarget)) {
    New-Item -ItemType Directory -Path $NugetsTarget -Force | Out-Null
}

if (Test-Path $NugetsDir) {
    $nugetFiles = Get-ChildItem -Path $NugetsDir -Filter "*.nupkg"
    if ($nugetFiles.Count -gt 0) {
        foreach ($nupkg in $nugetFiles) {
            Copy-Item $nupkg.FullName $NugetsTarget -Force
            Write-Host "  - $($nupkg.Name)" -ForegroundColor Gray
        }
        Write-Host "[OK] NuGet packages copied to $NugetsTarget" -ForegroundColor Green
    } else {
        Write-Host "[SKIP] No .nupkg files found in bundle" -ForegroundColor Yellow
    }
} else {
    Write-Host "[SKIP] No nugets/ directory in bundle" -ForegroundColor Yellow
}
Write-Host ""

# ============================================================================
# Step 3: Register NuGet source
# ============================================================================
Write-Host "[3/5] Registering NuGet package source..." -ForegroundColor Cyan
Write-Host ""

$sourceName = "WinApp-Dev"
$existingSources = dotnet nuget list source 2>$null
if ($existingSources -match $sourceName) {
    Write-Host "[OK] NuGet source '$sourceName' is already registered" -ForegroundColor Green
} else {
    try {
        dotnet nuget add source $NugetsTarget --name $sourceName 2>$null
        Write-Host "[OK] Registered NuGet source: $sourceName -> $NugetsTarget" -ForegroundColor Green
    } catch {
        Write-Warning "Could not register NuGet source automatically."
        Write-Host "  Run manually: dotnet nuget add source `"$NugetsTarget`" --name `"$sourceName`"" -ForegroundColor Yellow
    }
}
Write-Host ""

# ============================================================================
# Step 4: Install WinUI 3 templates
# ============================================================================
Write-Host "[4/5] Checking WinUI 3 project templates..." -ForegroundColor Cyan
Write-Host ""

$templateNupkg = Get-ChildItem -Path $NugetsTarget -Filter "Microsoft.WindowsAppSDK.WinUI.CSharp.Templates.*.nupkg" -ErrorAction SilentlyContinue | Select-Object -First 1
if ($templateNupkg) {
    $existingTemplates = dotnet new list 2>$null
    if ($existingTemplates -match "winui") {
        Write-Host "[OK] WinUI 3 templates already installed" -ForegroundColor Green
    } else {
        Write-Host "  Installing WinUI 3 templates..." -ForegroundColor Blue
        dotnet new install $templateNupkg.FullName 2>$null
        Write-Host "[OK] WinUI 3 templates installed" -ForegroundColor Green
    }
} else {
    Write-Host "[SKIP] WinUI template package not found in bundle - skipping" -ForegroundColor Yellow
}
Write-Host ""

# ============================================================================
# Step 5: Install Copilot CLI plugin
# ============================================================================
Write-Host "[5/5] Installing Copilot CLI plugin..." -ForegroundColor Cyan
Write-Host ""

$copilotAvailable = $false
try {
    $null = Get-Command copilot -ErrorAction Stop
    $copilotAvailable = $true
} catch {
    Write-Host "[WARN] Copilot CLI not found. Installing via winget..." -ForegroundColor Yellow
    try {
        winget install --id GitHub.CopilotCLI --accept-package-agreements --accept-source-agreements 2>$null
        $null = Get-Command copilot -ErrorAction Stop
        $copilotAvailable = $true
    } catch {
        try {
            $env:PATH = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
            $null = Get-Command copilot -ErrorAction Stop
            $copilotAvailable = $true
        } catch {
            Write-Host "[WARN] Copilot CLI installed but not found on PATH yet." -ForegroundColor Yellow
            Write-Host "  Open a new terminal and re-run this script." -ForegroundColor Yellow
        }
    }
}

if ($copilotAvailable -and (Test-Path $PluginDir)) {
    $copilotAgentsDir = Join-Path $env:USERPROFILE ".copilot\agents"
    $pluginTarget = Join-Path $copilotAgentsDir "win-dev-skills"

    if (Test-Path $pluginTarget) {
        Remove-Item $pluginTarget -Recurse -Force -ErrorAction SilentlyContinue
    }

    New-Item -ItemType Directory -Path $copilotAgentsDir -Force | Out-Null
    Copy-Item $PluginDir $pluginTarget -Recurse -Force
    Write-Host "[OK] Copilot CLI plugin installed" -ForegroundColor Green
} elseif (-not (Test-Path $PluginDir)) {
    Write-Host "[SKIP] Plugin directory not found in bundle" -ForegroundColor Yellow
}

Write-Host ""

# ============================================================================
# Summary
# ============================================================================
Write-Host "================================================" -ForegroundColor Green
Write-Host "  Installation Complete!" -ForegroundColor Green
Write-Host "================================================" -ForegroundColor Green
Write-Host ""

# Check what was installed
if (Get-Command winapp -ErrorAction SilentlyContinue) {
    Write-Host "    [x] WinApp CLI - use 'winapp' from any terminal" -ForegroundColor Green
} else {
    Write-Host "    [!] WinApp CLI - open a NEW terminal to use 'winapp'" -ForegroundColor Yellow
}

if (Get-Command raka -ErrorAction SilentlyContinue) {
    Write-Host "    [x] Raka CLI - use 'raka' from any terminal" -ForegroundColor Green
} else {
    Write-Host "    [!] Raka CLI - open a NEW terminal to use 'raka'" -ForegroundColor Yellow
}

Write-Host "    [x] NuGet packages - $NugetsTarget" -ForegroundColor Green

if ($templateNupkg) {
    Write-Host "    [x] WinUI 3 templates - 'dotnet new winui3'" -ForegroundColor Green
} else {
    Write-Host "    [ ] WinUI 3 templates - not included in bundle" -ForegroundColor Yellow
}

if ($copilotAvailable) {
    Write-Host "    [x] Copilot CLI plugin - run 'copilot' to start" -ForegroundColor Green
} else {
    Write-Host "    [ ] Copilot CLI plugin - install Copilot CLI first, then re-run" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "  NOTE: Open a NEW terminal for PATH changes to take effect." -ForegroundColor Cyan
Write-Host ""