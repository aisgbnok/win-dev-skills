#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Uninstaller for Windows Development Skills toolkit.
.DESCRIPTION
    Removes CLI tools, NuGet packages, templates, and the Copilot plugin.
    No admin privileges required.
.EXAMPLE
    .\uninstall.ps1
#>

$ScriptDir = Split-Path $PSCommandPath -Parent
$installScript = Join-Path $ScriptDir "install.ps1"

if (Test-Path $installScript) {
    & $installScript -Uninstall
} else {
    Write-Host "Error: install.ps1 not found at $installScript" -ForegroundColor Red
    exit 1
}