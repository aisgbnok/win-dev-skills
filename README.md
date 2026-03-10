# Windows Development Skills

Source of truth for Copilot CLI skills and agents for Windows app development.

## What's in this repo

- **`.github/plugin/`** — Copilot CLI plugin with agents and skills for Windows development
  - **winapp** agent — MSIX packaging, code signing, Windows SDK, package identity (Electron, .NET, C++, Rust, Flutter, Tauri)
  - **winui3-builder** agent — WinUI 3 app development with live UI automation via Raka
  - Skills for setup, packaging, signing, manifest authoring, troubleshooting, and more
- **`install.ps1` / `install.cmd`** — User installer (downloads tools from GitHub and installs everything)
- **`build-release.ps1`** - Maintainer script to download artifacts from source repos and publish releases

## Quick start (users)

1. Download the latest release from [Releases](https://github.com/microsoft/win-dev-skills/releases)
2. Extract the zip
3. Double-click `install.cmd`
4. When prompted, allow elevation to Administrator

The installer will:
- Install **WinApp CLI** and **Raka CLI** via MSIX packages (everything is in the zip — no internet required)
- Copy NuGet packages and register them as a NuGet source (so `dotnet restore` just works)
- Install WinUI 3 project templates (if included)
- Install the **Copilot CLI plugin** with Windows development agents and skills

After installation, open a terminal and run:

```
copilot
```

Then ask something like:

```
Build me a WinUI 3 app called TaskFlow
```

## Building a release (maintainers)

The `build-release.ps1` script downloads artifacts from source repositories, bundles them, and publishes to GitHub Releases.

### Prerequisites

- [GitHub CLI](https://cli.github.com/) (`gh`) installed and authenticated — used to download WinApp CLI artifacts from Actions and publish releases
- [Azure CLI](https://learn.microsoft.com/cli/azure/) (`az`) installed and logged in — used to download WinUI templates from the internal ADO NuGet feed (optional, use `-SkipTemplates` to skip)

### Artifact sources

| Artifact | Source | Auth required |
|---|---|---|
| WinApp CLI (MSIX + NuGet) | GitHub Actions artifacts from [microsoft/winappCli](https://github.com/microsoft/winappCli) PR | Yes (`gh`) |
| Raka CLI (MSIX + NuGet) | Latest release from [nmetulev/raka](https://github.com/nmetulev/raka) | No |
| WinUI Templates | ADO internal NuGet feed | Yes (`az`) |

### Usage

```powershell
# Download artifacts and create zip (default - no publish)
.\build-release.ps1

# Explicit version
.\build-release.ps1 -Version "0.3.0"

# Build and publish to GitHub Releases
.\build-release.ps1 -Publish

# Skip templates if you don't have ADO access
.\build-release.ps1 -SkipTemplates
```

The script will:
1. Download WinApp CLI MSIX + NuGet from the latest successful build on the PR branch
2. Download Raka MSIX + NuGet from the latest GitHub release (no auth)
3. Download WinUI templates from the ADO feed (with interactive login)
4. Bundle everything with the plugin and install script
5. Show bundle contents and ask for confirmation
6. Create a zip and publish to GitHub Releases

## Contributing

This project welcomes contributions and suggestions. Please see [SECURITY.md](SECURITY.md) for security policies.
