# Builder Knowledge Bundle

Reference material for the Builder specialist agent. Contains the operational knowledge needed to create, build, run, and verify WinUI 3 applications.

---

## 1. Prerequisites

Before writing any code, verify the development environment:

```powershell
# Check Developer Mode (required for sideloading MSIX packages)
Get-WindowsDeveloperLicense
# Must return IsValid: True. If not: Settings → System → For developers → Developer Mode → On

# Check .NET SDK (10.0+ required)
dotnet --version

# Check winapp CLI
winapp --version
```

If missing, install:
```powershell
winget install Microsoft.DotNet.SDK.10 --source winget
winget install Microsoft.WinAppCLI --source winget
```

---

## 2. Project Creation

```powershell
# Template name is "winui", NOT "winui3"
dotnet new winui -n <AppName>
```

- The `-n` flag creates the subfolder — do NOT `mkdir` first
- After creation, PRESERVE the template-generated `MainWindow.xaml` structure (TitleBar, SystemBackdrop, layout Grid). Insert your content into the existing structure — do NOT rewrite the file from scratch
- The template also generates `App.xaml`, `App.xaml.cs`, `.csproj`, and `Package.appxmanifest` — preserve these

---

## 3. Build Commands

WinUI 3 does NOT support AnyCPU. Always specify the platform:

```powershell
# Detect platform
$Platform = if ($env:PROCESSOR_ARCHITECTURE -eq 'ARM64') { 'Arm64' } else { 'x64' }

# Build
dotnet build <AppName>.csproj -c Debug -p:Platform=$Platform
```

### Common Build Errors

| Error | Cause | Fix |
|-------|-------|-----|
| `NETSDK1005` or AnyCPU errors | Missing `-p:Platform=x64` | Always specify platform |
| `CS0246` unknown type | Wrong namespace or missing NuGet | Check imports, verify package is installed |
| `XLS0504` / XAML parse error | Typo in XAML namespace, missing `x:DataType` | Check XAML syntax carefully |
| `NU1101` package not found | NuGet source misconfigured | Check NuGet sources with `dotnet nuget list source` |
| `NETSDK1004` assets file missing | Need to restore | Run `dotnet restore` first |

---

## 4. Running the App

```powershell
# Find build output path — check .csproj for TFM
# Typical: bin\x64\Debug\net10.0-windows10.0.26100.0\win-x64\
$buildOutput = "bin\$Platform\Debug\<TFM>\win-$($Platform.ToLower())\"

# Run with package identity + debug output (always use --debug-output)
winapp run $buildOutput --debug-output
```

- **Always use `--debug-output`** — captures debug messages, exceptions, and first-chance errors in the console. Invaluable for diagnosing runtime issues.
- Note: `--debug-output` prevents other debuggers (like Visual Studio) from attaching.
- If `winapp run` itself fails (before the app launches), add `--verbose` for detailed diagnostic output about the registration/launch process.

### Common Runtime Errors

| Error | Cause | Fix |
|-------|-------|-----|
| Wrong path / exe not found | Build output path wrong | List the build output directory to find correct folder |
| `HRESULT 0x80070005` | Access denied | Check permissions, ensure Developer Mode is on |
| `HRESULT 0x80070002` | File not found | Check manifest references match actual files |
| `RPC_E_WRONG_THREAD` | WinRT API called from wrong thread | Marshal to UI thread with `DispatcherQueue.TryEnqueue()` |
| App crashes on launch | Unhandled exception in init | Use `--debug-output` to see the exception |

---

## 5. UI Verification

```powershell
# Take a screenshot to verify layout
winapp ui screenshot -a <appname>

# Inspect interactive elements (buttons, text boxes, etc.)
winapp ui inspect -a <appname> --interactive

# Navigate to a page and screenshot
winapp ui invoke <nav-item-automation-id> -a <appname>
winapp ui screenshot -a <appname>

# Click buttons, fill inputs
winapp ui invoke <button-id> -a <appname>
winapp ui set-text <textbox-id> -a <appname> --value "test input"

# Read element properties
winapp ui get-property <element-id> -a <appname> --property Value
winapp ui get-property <toggle-id> -a <appname> --property ToggleState

# Scroll before invoking off-screen elements
winapp ui scroll <container-id> -a <appname> --direction down --amount 3
```

### Verification Checklist
- [ ] Content fills the window (no centered floating cards)
- [ ] All pages from design spec are present and navigable
- [ ] Controls match specified types
- [ ] No clipped text or overlapping elements
- [ ] Window size fits content — resize with `AppWindow.Resize` if needed

---

## 6. MVVM Rules for ViewModels

### Banned Imports — NEVER use these in ViewModel files:
- ❌ `using Microsoft.UI.Xaml;`
- ❌ `using Microsoft.UI.Xaml.Controls;`
- ❌ `using Microsoft.UI.Xaml.Media;`
- ❌ `using Microsoft.UI.Dispatching;`
- ❌ `using Windows.ApplicationModel.DataTransfer;`
- ❌ `using Microsoft.UI.Windowing;`

Use service interfaces from the blueprint instead (IThemeService, IDispatcherService, IClipboardService, IDialogService, INavigationService).

### CommunityToolkit.Mvvm — Partial Properties (NOT Fields)
```csharp
// ✅ CORRECT (Toolkit 8.4+):
[ObservableProperty]
public partial bool IsOnline { get; set; } = true;

// ❌ WRONG (deprecated, generates warnings):
[ObservableProperty] private bool _isOnline = true;
```

### Async Error Handling
```csharp
// ❌ WRONG — fire-and-forget silently swallows exceptions:
_ = ConnectToDeviceAsync(value);

// ✅ CORRECT — wrap in try-catch:
private async void OnSelectedDeviceChanged(DeviceInfo? value)
{
    try { await ConnectToDeviceAsync(value); }
    catch (Exception ex) { AddLogEntry($"Error: {ex.Message}"); }
}
```

---

## 7. Key Rules

1. **Build complete UI before first launch** — write ALL XAML elements first, then launch once. Don't launch with partial UI and iterate. Use `winapp ui inspect` to verify element presence and clipping BEFORE taking screenshots. Reserve screenshots for visual polish, not discovering missing elements.
2. **Scaffold first, features second** — for new apps, get a blank app building and running before adding features. Add features one at a time.
3. **One fix at a time** — when fixing errors, change one thing, rebuild, verify. Don't stack multiple changes.
4. **Preserve template files** — don't rewrite MainWindow.xaml from scratch. Insert content into the existing template structure.
5. **Ensure window size fits content** — verify with screenshots that nothing is cut off. Resize with `AppWindow.Resize` if needed.
6. **Use `scroll-into-view` or `scroll`** before invoking off-screen elements in UI automation.
7. **Screenshot and functional validation after every major change and before completion** — visual and functional verification is the only reliable check.
8. **Token efficiency** — batch related XAML changes (e.g., all controls for one page) and verify once. Use `winapp ui inspect` for structural checks (faster, no image tokens) and reserve screenshots for final confirmation.

---

## 7. Completion Validation

Before reporting completion, you MUST:

1. **Re-read the design spec** — list every page and feature specified
2. **Check each requirement** — navigate to the relevant page, interact with the feature, and screenshot to confirm it works
3. **Test core functionality end-to-end** — if the app processes data, actually trigger the operation and verify the output (click the action button, wait for completion, verify results)
4. **If anything is missing or broken** — fix it before reporting completion
5. **If something couldn't be done** — explain clearly what wasn't possible and why
6. **Never say "done" if you skipped something** — either implement it or explicitly call out that it was not completed

---

## 8. Pre-Code Workflow

Before writing any code for a feature:

1. **Check existing code** — search for related implementations to avoid duplication (DRY)
2. **Find the right API** — if the task involves a platform capability (notifications, windowing, sensors, etc.), look up the correct API in the [WinUI 3 API Reference](https://learn.microsoft.com/en-us/windows/windows-app-sdk/api/winrt/) before writing code
3. **Plan the approach** — consider SOLID principles and identify which classes/interfaces are involved
4. **Read the relevant skill files** — check the skills directory for guidance based on what you're about to do:

### Skill Routing — Which Skill to Read When

The skills directory is at `{SKILLS_PATH}/` (provided by the orchestrator). Read the relevant skill BEFORE writing code in its area:

| What you're doing | Read this skill |
|-------------------|----------------|
| Creating a new project, building, running | `dev-workflow/SKILL.md` |
| Adding/changing UI controls or XAML | `quality/SKILL.md` (accessibility, performance) + `visual-design/SKILL.md` (typography, spacing, colors) |
| Choosing which control to use | `templates/SKILL.md` (decision trees) + `templates/references/code-templates.md` (patterns) |
| Adding data binding, collections, async I/O | `data-layer/SKILL.md` + `data-layer/references/binding-patterns.md` |
| Working with windows, title bars, multi-window | `windowing/SKILL.md` + `windowing/references/windowing-patterns.md` |
| Adding notifications, background tasks, sensors | `platform-apis/SKILL.md` + relevant `references/` file |
| Using file pickers, media playback | `media-files/SKILL.md` + `media-files/references/file-patterns.md` |
| P/Invoke, HWND interop, WebView2 | `interop-webview/SKILL.md` + relevant reference |
| Custom controls, context menus, drag-and-drop | `ui-controls/SKILL.md` + `ui-controls/references/control-patterns.md` |
| Migrating from WPF | `wpf-migration/SKILL.md` + `wpf-migration/references/` |
| Adding user-facing strings, globalization | `quality/SKILL.md` (globalization section) |
| Handling secrets, user input, permissions | `quality/SKILL.md` (security section) |
| Writing tests | `testing/SKILL.md` |
| AOT, trimming, source generators | `aot-sourcegen/SKILL.md` |
| Looking up APIs, finding samples | `search-docs/SKILL.md` |

If you're unsure which skill applies, list the skills directory and read the SKILL.md files' frontmatter descriptions.

---

## 9. Error Recovery Workflow

When a build or runtime error occurs:

1. **Read the error message carefully** — identify the exact error code or exception type
2. **Check the common error tables** above first
3. **Common runtime error categories:**
   - `XAML parse error` → Check for typos in XAML namespaces, missing `x:DataType`, or unsupported markup
   - `HRESULT 0x...` → Search the error code online or in the dev-workflow skill
   - `NullReferenceException` → Check that bindings have correct `Mode` and DataContext is set
   - `Build error CS...` → Usually a namespace or type mismatch — check imports
   - `RPC_E_WRONG_THREAD` → Marshal to UI thread with `DispatcherQueue.TryEnqueue()`
4. **Escalation order for unknown types/APIs** (follow in order, don't skip):
   - Step 1: Read the dev-workflow and platform-apis skill files (if provided)
   - Step 2: Web search — translate the unknown type into search keywords, search the [WinAppSDK API Reference](https://learn.microsoft.com/en-us/windows/windows-app-sdk/api/winrt/) and [Platform SDK Reference](https://learn.microsoft.com/en-us/uwp/api/)
   - Step 3: Check [release notes](https://learn.microsoft.com/en-us/windows/apps/windows-app-sdk/stable-channel) for SDK version compatibility
   - Step 4: Search sample repos (WindowsAppSDK-Samples, WinUI-Gallery) for working examples
   - Step 5: Inspect `.winmd` metadata files (LAST RESORT only — always try web search first)
5. **After fixing** — rebuild and verify the fix before moving on. Never apply more than one fix at a time.

---

## 10. WPF Migration Notes

When converting a WPF app to WinUI 3, read the `wpf-migration` skill file first. Key rules:

1. **NEVER reference PresentationCore.dll** — it crashes the WinUI XAML compiler. Replace `System.Windows.Media.Imaging` with `Windows.Graphics.Imaging` before porting any XAML.
2. **Migrate file-by-file** — don't try to convert everything at once
3. **Imaging code goes early** — if the app has image processing, migrate it at step 2 (data models), not step 7 (views)
4. **Don't mix WPF and WinUI assemblies** — no `<UseWPF>true</UseWPF>`, no conditional PresentationCore references

---

## 11. Packaging & Distribution

Once the app is built and verified, if packaging is needed:

```powershell
# Generate a dev certificate (one-time)
winapp cert generate --manifest .

# Build for Release
dotnet build <project.csproj> -c Release -p:Platform=$Platform

# Package as MSIX
winapp package bin\Release\<TFM>\win-$($Platform.ToLower())\ --cert devcert.pfx

# Install cert for testing (may require admin)
winapp cert install devcert.pfx
```

For advanced packaging, CI/CD, or Store submission — these are handled by the winapp agent, not the builder.

---

## 12. Icon Generation

If a source logo is available (from the App Inspector or user):

```powershell
# Generate all MSIX icon assets from source logo
winapp manifest update-assets <path-to-logo-file>
```

- Source image should be at least 400x400px
- Accepts SVG, PNG, ICO, JPG, BMP, GIF
- If manifest isn't in current directory: `--manifest <path>`
- For light-theme variant: `--light-image <path>`

---

## 13. Visual Quality Pass

After functionality works, do a visual quality check before reporting completion:

- [ ] Typography: using `TextBlockStyle` resources, not hardcoded `FontSize`?
- [ ] Spacing: margins/padding are multiples of 4px (4, 8, 12, 16, 24)?
- [ ] Colors: all `{ThemeResource}` brushes, no hardcoded hex colors?
- [ ] Icons: `SymbolIcon` or `FontIcon` with proper sizes (16/20/24px)?
- [ ] Corner radius: using `ControlCornerRadius` / `OverlayCornerRadius` tokens?
- [ ] No unnecessary whitespace or extra chrome?
- [ ] Brand identity applied: accent color override in App.xaml, app name, logo?
