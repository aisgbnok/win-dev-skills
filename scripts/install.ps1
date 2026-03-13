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
.PARAMETER Uninstall
    Remove all installed components (tools, NuGet packages, templates, plugin).
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

# --- Shared paths ---
$ToolsTarget = Join-Path $env:USERPROFILE ".winui3-agent\tools"
$NugetsTarget = Join-Path $env:USERPROFILE ".winui3-agent\nugets"
$AgentDir = Join-Path $env:USERPROFILE ".winui3-agent"
$PluginTarget = Join-Path $env:USERPROFILE ".copilot\agents\win-dev-skills"
$NuGetSourceName = "WinApp-Dev"

# ============================================================================
# Uninstall mode
# ============================================================================
if ($Uninstall) {
    Write-Host ""
    Write-Host "================================================" -ForegroundColor Yellow
    Write-Host "  Windows Development Skills - Uninstall" -ForegroundColor Yellow
    Write-Host "================================================" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "This will remove:" -ForegroundColor White
    Write-Host ""

    $itemsToRemove = @()
    if (Test-Path $ToolsTarget) { $itemsToRemove += "  - CLI tools: $ToolsTarget" }
    if (Test-Path $NugetsTarget) { $itemsToRemove += "  - NuGet packages: $NugetsTarget" }
    if (Test-Path $PluginTarget) { $itemsToRemove += "  - Copilot plugin: $PluginTarget" }
    $itemsToRemove += "  - PATH entry for tools directory"
    $itemsToRemove += "  - NuGet source '$NuGetSourceName' (if registered)"
    $itemsToRemove += "  - WinUI 3 project templates (if installed)"

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

    # Remove NuGet packages
    if (Test-Path $NugetsTarget) {
        Remove-Item $NugetsTarget -Recurse -Force
        Write-Host "[OK] Removed NuGet packages directory" -ForegroundColor Green
    } else {
        Write-Host "[SKIP] NuGet packages directory not found" -ForegroundColor Gray
    }

    # Remove parent .winui3-agent if empty
    if ((Test-Path $AgentDir) -and @(Get-ChildItem $AgentDir -Force -ErrorAction SilentlyContinue).Count -eq 0) {
        Remove-Item $AgentDir -Force
        Write-Host "  - Removed empty $AgentDir" -ForegroundColor Gray
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

    # Remove NuGet source
    $existingSources = dotnet nuget list source 2>$null
    if ($existingSources -match $NuGetSourceName) {
        dotnet nuget remove source $NuGetSourceName 2>$null
        Write-Host "[OK] Removed NuGet source '$NuGetSourceName'" -ForegroundColor Green
    } else {
        Write-Host "[SKIP] NuGet source '$NuGetSourceName' not registered" -ForegroundColor Gray
    }

    # Uninstall WinUI 3 templates
    $templatePkg = "Microsoft.WindowsAppSDK.WinUI.CSharp.Templates"
    $installedTemplates = dotnet new list 2>$null
    if ($installedTemplates -match "winui") {
        dotnet new uninstall $templatePkg 2>$null
        Write-Host "[OK] Uninstalled WinUI 3 templates" -ForegroundColor Green
    } else {
        Write-Host "[SKIP] WinUI 3 templates not installed" -ForegroundColor Gray
    }

    # Remove Copilot plugin
    $copilotAvailable = $false
    try { $null = Get-Command copilot -ErrorAction Stop; $copilotAvailable = $true } catch { }

    if ($copilotAvailable) {
        $pluginList = & copilot plugin list 2>&1
        if ($pluginList -match "win-dev-skills") {
            $uninstallOutput = & copilot plugin uninstall win-dev-skills 2>&1
            Write-Host "  $uninstallOutput" -ForegroundColor Gray
            Write-Host "[OK] Removed Copilot plugin via CLI" -ForegroundColor Green
        } else {
            Write-Host "[SKIP] Copilot plugin 'win-dev-skills' not installed" -ForegroundColor Gray
        }
    } else {
        Write-Host "[SKIP] Copilot CLI not installed - no plugin to remove" -ForegroundColor Gray
    }

    Write-Host ""
    Write-Host "================================================" -ForegroundColor Green
    Write-Host "  Uninstall Complete!" -ForegroundColor Green
    Write-Host "================================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "  Open a NEW terminal for PATH changes to take effect." -ForegroundColor Cyan
    Write-Host ""
    exit 0
}
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

# Data directories (tools, nugets, plugin) can be siblings of the script
# or siblings of the script's parent (when script is in a scripts/ subfolder)
$BundleRoot = $ScriptDir
if (-not (Test-Path (Join-Path $BundleRoot "tools")) -and (Test-Path (Join-Path (Split-Path $BundleRoot -Parent) "tools"))) {
    $BundleRoot = Split-Path $BundleRoot -Parent
}
$ToolsSrcDir = Join-Path $BundleRoot "tools"
$NugetsDir = Join-Path $BundleRoot "nugets"
$PluginDir = Join-Path $BundleRoot "plugin"

# ============================================================================
# Prerequisites
# ============================================================================
Write-Host "[PRE] Checking prerequisites..." -ForegroundColor Cyan
Write-Host ""

$dotnetAvailable = $false
try {
    $null = Get-Command dotnet -ErrorAction Stop
    $dotnetAvailable = $true
    $dotnetVer = dotnet --version 2>$null
    Write-Host "  [OK] .NET SDK ($dotnetVer)" -ForegroundColor Green
} catch {
    Write-Host "  [!] .NET SDK not found" -ForegroundColor Red
    Write-Host "      Required for NuGet package management and WinUI 3 templates." -ForegroundColor Gray
    $installDotnet = Read-Host "      Install .NET SDK via winget? (Y/N)"
    if ($installDotnet -eq 'Y' -or $installDotnet -eq 'y') {
        Write-Host "      Installing .NET SDK..." -ForegroundColor Gray
        winget install --id Microsoft.DotNet.SDK.9 --accept-package-agreements --accept-source-agreements 2>$null
        $env:PATH = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
        try {
            $null = Get-Command dotnet -ErrorAction Stop
            $dotnetAvailable = $true
            Write-Host "  [OK] .NET SDK installed" -ForegroundColor Green
        } catch {
            Write-Host "  [FAIL] .NET SDK installed but not on PATH yet." -ForegroundColor Red
            Write-Host "         Open a new terminal and re-run this script." -ForegroundColor Red
        }
    }

    if (-not $dotnetAvailable) {
        Write-Host ""
        Write-Host "  .NET SDK is required. Install it from https://dotnet.microsoft.com/download" -ForegroundColor Red
        Write-Host "  or run: winget install Microsoft.DotNet.SDK.9" -ForegroundColor Red
        exit 1
    }
}
Write-Host ""

# ============================================================================
# Step 0: Detect conflicting MSIX packages
# ============================================================================
Write-Host "[PRE] Checking for conflicting MSIX packages..." -ForegroundColor Cyan
Write-Host ""

$msixConflicts = @()

# WinApp CLI - check for 'winapp' and 'winapp-dev' MSIX packages
$winappMsix = Get-AppxPackage -Name "winapp" -ErrorAction SilentlyContinue
$winappDevMsix = Get-AppxPackage -Name "winapp-dev" -ErrorAction SilentlyContinue
if ($winappMsix) { $msixConflicts += $winappMsix }
if ($winappDevMsix) { $msixConflicts += $winappDevMsix }

# Raka CLI - check for 'nmetulev.Raka' MSIX package
$rakaMsix = Get-AppxPackage -Name "nmetulev.Raka" -ErrorAction SilentlyContinue
if ($rakaMsix) { $msixConflicts += $rakaMsix }

if ($msixConflicts.Count -gt 0) {
    Write-Host "  Found MSIX-installed packages that will conflict:" -ForegroundColor Yellow
    Write-Host ""
    foreach ($pkg in $msixConflicts) {
        Write-Host "    - $($pkg.Name) v$($pkg.Version)" -ForegroundColor Yellow
    }
    Write-Host ""
    Write-Host "  MSIX packages register an AppExecutionAlias that takes priority" -ForegroundColor Yellow
    Write-Host "  over PATH. The portable tools installed by this script would be" -ForegroundColor Yellow
    Write-Host "  shadowed and never used." -ForegroundColor Yellow
    Write-Host ""

    $uninstallResponse = Read-Host "  Uninstall these MSIX packages? (Y/N)"
    if ($uninstallResponse -eq 'Y' -or $uninstallResponse -eq 'y') {
        foreach ($pkg in $msixConflicts) {
            Write-Host "  Removing $($pkg.Name)..." -ForegroundColor Gray
            try {
                Remove-AppxPackage -Package $pkg.PackageFullName -ErrorAction Stop
                Write-Host "  [OK] Removed $($pkg.Name)" -ForegroundColor Green
            } catch {
                Write-Host "  [WARN] Could not remove $($pkg.Name): $_" -ForegroundColor Yellow
                Write-Host "  You may need to uninstall it manually from Settings > Apps." -ForegroundColor Yellow
            }
        }
    } else {
        Write-Host ""
        Write-Host "  [WARN] Keeping MSIX packages. The portable tools may not work" -ForegroundColor Yellow
        Write-Host "  correctly until the MSIX versions are uninstalled." -ForegroundColor Yellow
    }
    Write-Host ""
} else {
    Write-Host "  No conflicting MSIX packages found" -ForegroundColor Gray
    Write-Host ""
}

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
        $targetPath = Join-Path $ToolsTarget $exe.Name
        if (Test-Path $targetPath) {
            $existing = Get-Item $targetPath
            $existingSize = [math]::Round($existing.Length / 1KB, 1)
            $newSize = [math]::Round($exe.Length / 1KB, 1)
            $existingDate = $existing.LastWriteTime.ToString("yyyy-MM-dd HH:mm")
            Write-Host "  - $($exe.Name): updating (existing: ${existingSize}KB, $existingDate -> new: ${newSize}KB)" -ForegroundColor Gray
        } else {
            Write-Host "  - $($exe.Name): installing (new)" -ForegroundColor Gray
        }
        Copy-Item $exe.FullName $ToolsTarget -Force
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

# Copy uninstall scripts to ~/.winui3-agent/ for easy access
$uninstallPs1Src = Join-Path $ScriptDir "uninstall.ps1"
if (Test-Path $uninstallPs1Src) {
    Copy-Item $uninstallPs1Src $AgentDir -Force
}
# Generate uninstall.cmd in the agent dir
$uninstallCmdContent = @"
@echo off
echo.
echo ================================================
echo  Windows Development Skills - Uninstall
echo ================================================
echo.
powershell.exe -ExecutionPolicy Bypass -File "%~dp0uninstall.ps1"
if %ERRORLEVEL% EQU 0 (
    echo.
    echo Uninstall completed successfully!
    echo Open a NEW terminal for PATH changes to take effect.
) else (
    echo.
    echo Uninstall encountered an error.
    echo Please check the output above for details.
)
echo.
pause
"@
Set-Content -Path (Join-Path $AgentDir "uninstall.cmd") -Value $uninstallCmdContent -NoNewline
Write-Host "[OK] Uninstall scripts placed in $AgentDir" -ForegroundColor Green

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

$templatePkgName = "Microsoft.WindowsAppSDK.WinUI.CSharp.Templates"
$templateNupkg = Get-ChildItem -Path $NugetsTarget -Filter "$templatePkgName.*.nupkg" -ErrorAction SilentlyContinue | Select-Object -First 1
if ($templateNupkg) {
    # Always uninstall existing templates first to avoid version conflicts
    $existingTemplates = dotnet new list 2>$null
    if ($existingTemplates -match "winui") {
        Write-Host "  Removing existing WinUI 3 templates..." -ForegroundColor Gray
        dotnet new uninstall $templatePkgName 2>$null | Out-Null
    }
    Write-Host "  Installing WinUI 3 templates..." -ForegroundColor Blue
    dotnet new install $templateNupkg.FullName 2>$null
    Write-Host "[OK] WinUI 3 templates installed" -ForegroundColor Green
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
    Write-Host "  Copilot CLI not found on PATH." -ForegroundColor Yellow
    $installResponse = Read-Host "  Install Copilot CLI via winget? (Y/N)"
    if ($installResponse -eq 'Y' -or $installResponse -eq 'y') {
        Write-Host "  Installing Copilot CLI..." -ForegroundColor Gray
        try {
            winget install --id GitHub.Copilot --source winget --accept-package-agreements --accept-source-agreements 2>$null
            # Refresh PATH to pick up newly installed binary
            $env:PATH = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
            $null = Get-Command copilot -ErrorAction Stop
            $copilotAvailable = $true
        } catch {
            Write-Host "[WARN] Copilot CLI was installed but not found on PATH yet." -ForegroundColor Yellow
            Write-Host "  Open a new terminal and run: copilot plugin install `"$PluginDir`"" -ForegroundColor Yellow
        }
    } else {
        Write-Host "[SKIP] Copilot CLI not installed - skipping plugin install" -ForegroundColor Yellow
        Write-Host "  After installing Copilot CLI, run: copilot plugin install `"$PluginDir`"" -ForegroundColor Yellow
    }
}

if ($copilotAvailable -and (Test-Path $PluginDir)) {
    Write-Host "  Installing plugin via Copilot CLI..." -ForegroundColor Gray
    try {
        $installOutput = & copilot plugin install $PluginDir 2>&1
        Write-Host "  $installOutput" -ForegroundColor Gray
        Write-Host "[OK] Copilot CLI plugin installed" -ForegroundColor Green
    } catch {
        Write-Host "[WARN] 'copilot plugin install' failed: $_" -ForegroundColor Yellow
        Write-Host "  Try manually: copilot plugin install `"$PluginDir`"" -ForegroundColor Yellow
    }
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