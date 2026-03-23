---
name: identity-and-setup
description: 'Set up Windows app projects for MSIX packaging, package identity, and Windows API access across all frameworks. Covers winapp init for project setup, appxmanifest.xml authoring, image asset generation from a source logo, execution aliases, file type associations, sparse vs packaged identity, running and debugging with identity (winapp run), and framework-specific setup for Electron (.NET addons, debug identity), .NET (NuGet-based, no winapp.yaml needed), C++ (CppWinRT projections), Rust, Flutter, and Tauri. Use when setting up a project for Windows, creating or editing a manifest, generating app icons, adding an execution alias, running with package identity, or choosing the right setup for a framework.'
---

## Quick reference

Install: `winget install Microsoft.WinAppCli` (standalone) or `npm install --save-dev @microsoft/winappcli` (Electron/Node).

| Framework | Run with identity | Guide |
|-----------|-------------------|-------|
| **Electron** | `npx winapp node add-electron-debug-identity` | [Electron guide](https://github.com/microsoft/WinAppCli/blob/main/docs/guides/electron/setup.md) |
| **.NET** | `dotnet run` (NuGet pkg) or `winapp run ./bin/Debug` | [.NET guide](https://github.com/microsoft/WinAppCli/blob/main/docs/guides/dotnet.md) |
| **C++** | `winapp run ./build/Debug` | [C++ guide](https://github.com/microsoft/WinAppCli/blob/main/docs/guides/cpp.md) |
| **Rust** | `winapp run ./target/debug` | [Rust guide](https://github.com/microsoft/WinAppCli/blob/main/docs/guides/rust.md) |
| **Flutter** | `winapp run ./build/windows/x64/runner/Debug` | [Flutter guide](https://github.com/microsoft/WinAppCli/blob/main/docs/guides/flutter.md) |
| **Tauri** | `winapp run ./dist` | [Tauri guide](https://github.com/microsoft/WinAppCli/blob/main/docs/guides/tauri.md) |

All frameworks: `winapp init --use-defaults` to set up. Run `winapp <cmd> --help` for options, or `winapp --cli-schema` for full CLI reference.

## Workflow decision tree

```
Does the project have an appxmanifest.xml?
├─ No → Need full setup (manifest + config + optional SDKs)?
│       ├─ Yes → winapp init (adds Windows platform files to existing project)
│       └─ Just a manifest → winapp manifest generate
└─ Yes
   ├─ Need package identity for debugging?
   │  ├─ Exe is in your build output? (most frameworks)
   │  │  └─ winapp run <build-output-dir>
   │  └─ Exe is separate from app code? (Electron, sparse)
   │     └─ winapp create-debug-identity <exe>
   ├─ Need to update app icons?
   │  └─ winapp manifest update-assets ./logo.png
   └─ Need an execution alias for terminal launch?
      └─ winapp manifest add-alias
```

### Manifest authoring examples

```bash
# Generate manifest + default icon assets for a new project
winapp manifest generate --template packaged --package-name "MyApp" --publisher-name "CN=Dev"

# Generate manifest for a console app with an execution alias
winapp manifest generate --template packaged --executable MyApp.exe
winapp manifest add-alias --alias myapp

# Regenerate all icon sizes from a single source image (PNG/SVG, 400×400+ recommended)
winapp manifest update-assets ./logo.png

# Regenerate with light/dark theme variants
winapp manifest update-assets ./logo-dark.png --light-image ./logo-light.png

# Add a file type association
# (edit appxmanifest.xml directly — add uap:FileTypeAssociation under Extensions)
```

### `winapp run` vs `create-debug-identity`

| | `winapp run` | `create-debug-identity` |
|---|---|---|
| **Registers** | Full loose layout package (entire folder) | Sparse package (single exe) |
| **App launch** | Winapp launches via AUMID or alias | You launch the exe yourself |
| **Simulates MSIX** | Yes — closest to production | No — identity only |
| **Files** | Copied to AppX layout dir | Exe stays in place |
| **Best for** | Most frameworks (.NET, C++, Rust, Flutter, Tauri) | Electron, or F5 startup debugging |

**Default to `winapp run`.** Use `create-debug-identity` when your IDE must launch the exe directly (startup debugging) or the exe is separate from source (Electron). For console apps, add `--with-alias` to preserve stdin/stdout (requires `uap5:ExecutionAlias` — add via `winapp manifest add-alias`).

## Key rules

- **`appxmanifest.xml` is the key prerequisite** for most commands — more important than `winapp.yaml`.
- **`winapp.yaml`** is only for SDK version management (`restore`/`update`). .NET projects with NuGet references don't need it.
- **`winapp init` adds files to an existing project** — does not scaffold new projects.
- **Publisher must match certificate.** Use `winapp cert generate --manifest` to auto-match.
- **Templates:** `packaged` (default, full MSIX) and `sparse` (identity without MSIX containment).
- **Re-run identity registration** after any change to `appxmanifest.xml` or `Assets/`.
- **`--use-defaults`** skips interactive prompts — required for CI/CD.

### .NET vs non-.NET projects

| | .NET Projects | Non-.NET Projects (C++, Rust, Flutter, Electron, Tauri) |
|---|---|---|
| **Dependencies** | Managed in `.csproj` via NuGet `<PackageReference>` | Managed in `winapp.yaml` |
| **`winapp.yaml`** | **Not needed** — winapp auto-detects SDK versions from `.csproj` | **Required** — created by `winapp init`, used by `restore`/`update` |
| **SDK access** | Direct via `Microsoft.Windows.SDK.NET.Ref` NuGet | Via downloaded packages in `.winapp/` |
| **CppWinRT headers** | N/A | Generated at `.winapp/generated/include/` |
| **Run with identity** | `dotnet run` (if NuGet pkg installed) or `winapp run` | `winapp run <build-output>` |
| **Restore after clone** | `dotnet restore` (standard) | `winapp restore` (recreates `.winapp/`) |

**Key rule:** If you see a `.csproj` with `<PackageReference Include="Microsoft.WindowsAppSDK">`, the project is .NET-based and does NOT need `winapp.yaml` or `winapp restore`. Skip SDK setup steps.

## After init

`winapp init` creates: `appxmanifest.xml` (identity/capabilities), `Assets/` (app icons), `winapp.yaml` (SDK versions), `.winapp/` (SDK packages, gitignored).

## Troubleshooting

| Error | Solution |
|-------|----------|
| "appxmanifest.xml not found" | Run `winapp init` or `winapp manifest generate`, or pass `--manifest` |
| "winapp.yaml not found" | Run `winapp init`, or `cd` to its directory |
| "Publisher mismatch" | `winapp cert generate --manifest` or edit manifest `Identity.Publisher` |
| "Failed to add package identity" | `Get-AppxPackage *yourapp* \| Remove-AppxPackage`, then retry |

## Related skills

- **Packaging & signing** → See `packaging-and-signing` for MSIX distribution, certificates, and code signing.
- **Windows APIs** → See `windows-platform-apis` for SDK setup and calling Windows APIs from any framework.

## External resources

- [Debugging Guide](https://github.com/microsoft/WinAppCli/blob/main/docs/debugging.md) — IDE setup, debugging scenarios
- [Full CLI documentation](https://github.com/microsoft/WinAppCli/blob/main/docs/usage.md)
- [Framework-specific guides](https://github.com/microsoft/WinAppCli/tree/main/docs/guides)
