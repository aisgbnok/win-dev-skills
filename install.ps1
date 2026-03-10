#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Unified installer for Windows Development Skills toolkit.
.DESCRIPTION
    Installs the complete Windows development toolkit from the extracted bundle:
    - WinApp CLI (MSIX package)
    - Raka CLI (MSIX package)
    - NuGet packages (registered as a user-level NuGet source)
    - WinUI 3 project templates
    - Copilot CLI plugin

    Run this script from inside the extracted release zip. No internet or authentication required.
.PARAMETER Elevated
    Internal flag - set automatically when the script re-launches itself with admin privileges.
.EXAMPLE
    .\install.ps1
#>

param(
    [Parameter(Mandatory=$false)]
    [switch]$Elevated
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

    if ($Elevated) {
        Write-Host "Press Enter to close this window..." -ForegroundColor Cyan
        Read-Host
    }

    exit 1
}

Write-Host ""
Write-Host "================================================" -ForegroundColor Cyan
Write-Host "  Windows Development Skills - Unified Installer" -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan
Write-Host ""

# --- Check admin ---
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
$isAdmin = $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-Host "This installer will set up the Windows Development Skills toolkit." -ForegroundColor White
    Write-Host ""
    Write-Host "Here is what will be installed:" -ForegroundColor White
    Write-Host ""
    Write-Host "  1. WinApp CLI (MSIX package) - Prerelease with support for running packaged apps" -ForegroundColor Gray
    Write-Host "     CLI tool for MSIX packaging, code signing, and Windows SDK management." -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "  2. Raka CLI (MSIX package) - POC" -ForegroundColor Gray
    Write-Host "     CLI tool for UI automation of WinUI 3 apps (inspect, screenshot, hot-reload)." -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "  3. NuGet packages" -ForegroundColor Gray
    Write-Host "     Copies pre-release nuget packages to ~/.winui3-agent/nugets" -ForegroundColor DarkGray
    Write-Host "     and registers a user-level NuGet source so dotnet restore finds them." -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "  4. WinUI 3 project templates" -ForegroundColor Gray
    Write-Host "     Installs 'dotnet new' templates for WinUI 3 projects." -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "  5. GitHub Copilot CLI plugin" -ForegroundColor Gray
    Write-Host "     Installs agents and skills to Github Copilot for Windows development." -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "  - MSIX packages are signed with a development certificate." -ForegroundColor DarkGray
    Write-Host "    The certificate must be added to the Trusted People store" -ForegroundColor DarkGray
    Write-Host "    so Windows allows installation. This requires admin access." -ForegroundColor DarkGray
    Write-Host ""

    $response = Read-Host "Proceed with installation? (Y/N)"

    if ($response -eq 'Y' -or $response -eq 'y') {
        Write-Host ""
        Write-Host "Restarting with administrator privileges..." -ForegroundColor Blue
        Write-Host ""

        $ScriptDir = Split-Path $PSCommandPath -Parent
        $arguments = "-NoProfile -ExecutionPolicy Bypass -Command `"Set-Location '$ScriptDir'; & '$PSCommandPath' -Elevated`""

        try {
            Start-Process PowerShell -Verb RunAs -ArgumentList $arguments
            Write-Host "Installation is running in the elevated window." -ForegroundColor Cyan
            exit 2
        } catch {
            Write-Error "Failed to elevate: $_"
            exit 1
        }
    } else {
        Write-Host ""
        Write-Host "[CANCELLED] Installation requires administrator privileges." -ForegroundColor Yellow
        Write-Host ""
        exit 1
    }
}

Write-Host "[INFO] Running with administrator privileges" -ForegroundColor Green
Write-Host ""

$ScriptDir = Split-Path $PSCommandPath -Parent
$MsixDir = Join-Path $ScriptDir "msix"
$NugetsDir = Join-Path $ScriptDir "nugets"
$PluginDir = Join-Path $ScriptDir "plugin"

# ============================================================================
# Helper: Install an MSIX package (cert + package)
# ============================================================================
function Install-MsixPackage {
    param(
        [string]$DisplayName,
        [string]$PackageName,
        [string]$SearchDir
    )

    Write-Host "--------------------------------------------" -ForegroundColor DarkGray
    Write-Host "  Installing $DisplayName" -ForegroundColor White
    Write-Host "--------------------------------------------" -ForegroundColor DarkGray
    Write-Host ""

    # Detect architecture and find package
    $CurrentArch = $env:PROCESSOR_ARCHITECTURE
    $ArchPattern = switch ($CurrentArch) {
        "AMD64" { "*$PackageName*_x64*.msix" }
        "ARM64" { "*$PackageName*_arm64*.msix" }
        default { "*$PackageName*.msix" }
    }

    Write-Host "[SEARCH] Looking for $DisplayName MSIX ($CurrentArch)..." -ForegroundColor Blue
    $package = Get-ChildItem -Path $SearchDir -Filter $ArchPattern -ErrorAction SilentlyContinue | Select-Object -First 1

    if ($null -eq $package) {
        # Fallback: match by name only (any architecture)
        $package = Get-ChildItem -Path $SearchDir -Filter "*$PackageName*.msix" -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($null -eq $package) {
            Write-Warning "No .msix files found for $DisplayName in: $SearchDir"
            return $false
        }
    }

    $PackagePath = $package.FullName
    Write-Host "[FOUND] $($package.Name)" -ForegroundColor Green

    # Extract and install certificate
    Write-Host "[CERT] Extracting certificate..." -ForegroundColor Blue
    $TempDir = Join-Path $env:TEMP "msix-install-$(Get-Random)"
    New-Item -ItemType Directory -Path $TempDir -Force | Out-Null

    try {
        $MsixAsZip = Join-Path $TempDir "package.zip"
        $MsixExtractPath = Join-Path $TempDir "msix"
        Copy-Item $PackagePath $MsixAsZip -Force
        Expand-Archive -Path $MsixAsZip -DestinationPath $MsixExtractPath -Force

        $signature = Get-AuthenticodeSignature -FilePath $PackagePath
        $cert = $null

        if ($signature -and $signature.SignerCertificate) {
            $cert = $signature.SignerCertificate
        } else {
            $signatureFile = Get-ChildItem -Path $MsixExtractPath -Filter "AppxSignature.p7x" -Recurse | Select-Object -First 1
            if ($signatureFile) {
                try {
                    $p7xBytes = [System.IO.File]::ReadAllBytes($signatureFile.FullName)
                    $signedCms = New-Object System.Security.Cryptography.Pkcs.SignedCms
                    $signedCms.Decode($p7xBytes)
                    $cert = $signedCms.Certificates[0]
                } catch {
                    Write-Error "Failed to extract certificate: $_"
                    return $false
                }
            }
        }

        if ($null -eq $cert) {
            Write-Error "Could not extract certificate from $DisplayName package"
            return $false
        }

        Write-Host "  Subject:    $($cert.Subject)" -ForegroundColor Gray
        Write-Host "  Thumbprint: $($cert.Thumbprint)" -ForegroundColor Gray

        # Read package identity from manifest
        $manifestPath = Join-Path $MsixExtractPath "AppxManifest.xml"
        $packageIdentityName = $null
        if (Test-Path $manifestPath) {
            [xml]$manifest = Get-Content $manifestPath
            $packageIdentityName = $manifest.Package.Identity.Name
            Write-Host "  Identity:   $packageIdentityName" -ForegroundColor Gray
        }

        $existingCert = Get-ChildItem -Path Cert:\LocalMachine\TrustedPeople | Where-Object { $_.Thumbprint -eq $cert.Thumbprint }
        if ($existingCert) {
            Write-Host "[INFO] Certificate already trusted" -ForegroundColor Green
        } else {
            $store = New-Object System.Security.Cryptography.X509Certificates.X509Store("TrustedPeople", "LocalMachine")
            $store.Open("ReadWrite")
            $store.Add($cert)
            $store.Close()
            Write-Host "[OK] Certificate installed to Trusted People" -ForegroundColor Green
        }

        # Check for existing packages using the exact identity from the manifest
        if ($packageIdentityName) {
            $existingPackages = Get-AppxPackage -Name $packageIdentityName -ErrorAction SilentlyContinue
        } else {
            $existingPackages = $null
        }
        if ($existingPackages) {
            Write-Host "[CHECK] Found existing $DisplayName package(s):" -ForegroundColor Yellow
            foreach ($pkg in $existingPackages) {
                Write-Host "  - $($pkg.Name) v$($pkg.Version)" -ForegroundColor Yellow
            }
            $response = Read-Host "Uninstall existing package(s) before installing? (Y/N)"
            if ($response -eq 'Y' -or $response -eq 'y') {
                foreach ($pkg in $existingPackages) {
                    Write-Host "  Removing $($pkg.Name) v$($pkg.Version)..." -ForegroundColor Blue
                    Remove-AppxPackage -Package $pkg.PackageFullName -ErrorAction SilentlyContinue
                }
            }
        }

        # Install
        Write-Host "[INSTALL] Installing $DisplayName MSIX..." -ForegroundColor Blue
        try {
            Add-AppxPackage -Path $PackagePath -ErrorAction Stop
            Write-Host "[OK] $DisplayName installed successfully!" -ForegroundColor Green
            Write-Host ""
            return $true
        } catch {
            Write-Warning "Failed to install $DisplayName MSIX: $_"
            Write-Host "  Try: Double-click the .msix file or run Add-AppxPackage manually." -ForegroundColor Yellow
            Write-Host ""
            return $false
        }
    } finally {
        if (Test-Path $TempDir) {
            Remove-Item $TempDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

# ============================================================================
# Step 1: Install WinApp MSIX
# ============================================================================
Write-Host "[1/6] Installing WinApp CLI..." -ForegroundColor Cyan
Write-Host ""
$winapResult = Install-MsixPackage -DisplayName "WinApp CLI" -PackageName "winapp" -SearchDir $MsixDir

# ============================================================================
# Step 2: Install Raka MSIX
# ============================================================================
Write-Host "[2/6] Installing Raka CLI..." -ForegroundColor Cyan
Write-Host ""
$rakaResult = Install-MsixPackage -DisplayName "Raka CLI" -PackageName "Raka" -SearchDir $MsixDir

# ============================================================================
# Step 3: Copy NuGet packages
# ============================================================================
Write-Host "[3/6] Installing NuGet packages..." -ForegroundColor Cyan
Write-Host ""

$NugetsTarget = Join-Path $env:USERPROFILE ".winui3-agent\nugets"
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
# Step 4: Register NuGet source
# ============================================================================
Write-Host "[4/6] Registering NuGet package source..." -ForegroundColor Cyan
Write-Host ""

$sourceName = "WinApp-Dev"
$existingSources = dotnet nuget list source 2>$null
if ($existingSources -match $sourceName) {
    Write-Host "[INFO] NuGet source '$sourceName' is already registered" -ForegroundColor Green
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
# Step 5: Install WinUI 3 templates
# ============================================================================
Write-Host "[5/6] Checking WinUI 3 project templates..." -ForegroundColor Cyan
Write-Host ""

$templateNupkg = Get-ChildItem -Path $NugetsTarget -Filter "Microsoft.WindowsAppSDK.WinUI.CSharp.Templates.*.nupkg" -ErrorAction SilentlyContinue | Select-Object -First 1
if ($templateNupkg) {
    $existingTemplates = dotnet new list 2>$null
    if ($existingTemplates -match "winui") {
        Write-Host "[INFO] WinUI 3 templates already installed" -ForegroundColor Green
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
# Step 6: Install Copilot CLI plugin
# ============================================================================
Write-Host "[6/6] Installing Copilot CLI plugin..." -ForegroundColor Cyan
Write-Host ""

# Check if Copilot CLI is available
$copilotAvailable = $false
try {
    $null = Get-Command copilot -ErrorAction Stop
    $copilotAvailable = $true
} catch {
    Write-Host "[INFO] Copilot CLI not found. Installing via winget..." -ForegroundColor Yellow
    try {
        winget install GitHub.Copilot --accept-source-agreements --accept-package-agreements 2>$null
        # Refresh PATH
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
        try {
            $null = Get-Command copilot -ErrorAction Stop
            $copilotAvailable = $true
        } catch {
            Write-Host "[WARN] Copilot CLI installed but not found on PATH yet." -ForegroundColor Yellow
            Write-Host "  Close and reopen your terminal, then run: copilot plugin install `"$PluginDir`"" -ForegroundColor Yellow
        }
    } catch {
        Write-Host "[WARN] Could not install Copilot CLI automatically." -ForegroundColor Yellow
        Write-Host "  Install manually: winget install GitHub.Copilot" -ForegroundColor Yellow
    }
}

if ($copilotAvailable -and (Test-Path $PluginDir)) {
    try {
        copilot plugin install $PluginDir 2>$null
        Write-Host "[OK] Copilot CLI plugin installed" -ForegroundColor Green
    } catch {
        Write-Warning "Could not install plugin. Run manually: copilot plugin install `"$PluginDir`""
    }
} elseif (-not (Test-Path $PluginDir)) {
    Write-Host "[SKIP] Plugin directory not found in bundle" -ForegroundColor Yellow
}
Write-Host ""

# ============================================================================
# Summary
# ============================================================================
Write-Host ""
Write-Host "================================================" -ForegroundColor Cyan
Write-Host "  Installation Complete!" -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "  What was installed:" -ForegroundColor White
Write-Host ""

if ($winapResult) {
    Write-Host "    [x] WinApp CLI (MSIX) - use 'winapp' from any terminal" -ForegroundColor Green
} else {
    Write-Host "    [ ] WinApp CLI - installation had issues (see above)" -ForegroundColor Yellow
}

if ($rakaResult) {
    Write-Host "    [x] Raka CLI (MSIX) - use 'raka' from any terminal" -ForegroundColor Green
} else {
    Write-Host "    [ ] Raka CLI - installation had issues (see above)" -ForegroundColor Yellow
}

Write-Host "    [x] NuGet packages - $NugetsTarget" -ForegroundColor Green
Write-Host "    [x] NuGet source '$sourceName' registered (dotnet restore just works)" -ForegroundColor Green

if ($templateNupkg) {
    Write-Host "    [x] WinUI 3 project templates (dotnet new winui)" -ForegroundColor Green
} else {
    Write-Host "    [ ] WinUI 3 templates - not included in bundle" -ForegroundColor Yellow
}

if ($copilotAvailable) {
    Write-Host "    [x] Copilot CLI plugin (winapp agents + skills)" -ForegroundColor Green
} else {
    Write-Host "    [ ] Copilot CLI plugin - install Copilot CLI first, then re-run" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "  Quick start:" -ForegroundColor White
Write-Host ""
Write-Host "    Open a terminal and run:" -ForegroundColor Gray
Write-Host "      copilot" -ForegroundColor Cyan
Write-Host ""
Write-Host "    Then ask:" -ForegroundColor Gray
Write-Host "      `"Build me a WinUI 3 app called TaskFlow`"" -ForegroundColor Cyan
Write-Host ""
Write-Host "================================================" -ForegroundColor Cyan
Write-Host ""

if ($Elevated) {
    Read-Host "Press Enter to exit"
}
