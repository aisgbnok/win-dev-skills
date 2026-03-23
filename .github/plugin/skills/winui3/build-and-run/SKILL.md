---
name: build-and-run
description: 'How to build, run, and debug WinUI 3 desktop apps. Covers dotnet build with correct Platform and TFM arguments, winapp run for packaged apps, dotnet run for unpackaged apps, diagnosing silent exits, XAML parse errors, missing WindowsAppSDK runtime, and common build/launch troubleshooting. Use when building a WinUI 3 project, running a WinUI 3 app, or debugging why a WinUI 3 app won''t launch, shows a blank window, or crashes at startup.'
---

## Quick Reference

- **Build with Platform**: `dotnet build <project.csproj> -c Debug -p:Platform=x64` (or `Arm64`). WinUI 3 requires explicit Platform — `AnyCPU` won't work.
- **Run packaged apps with `winapp run`**: `winapp run bin\x64\Debug\<tfm>\win-x64\` — registers the app with Windows and launches it. Running the exe directly will silently exit.
- **Never use `<WindowsPackageType>None`** as a workaround for launch issues — this removes package identity and breaks Windows APIs.
- **Check TFM in csproj**: The target framework must be `net10.0-windows10.0.26100.0` (or similar). Check `<TargetFramework>` in the csproj to get the correct path.
- **Clean `obj/` folder** when you see stale XAML errors: `Remove-Item obj -Recurse -Force` then rebuild.

---

# Build and Run WinUI 3 Apps

## Building

### Basic build
```bash
# Debug build for x64
dotnet build <project.csproj> -c Debug -p:Platform=x64

# Release build for x64
dotnet build <project.csproj> -c Release -p:Platform=x64

# Arm64 build
dotnet build <project.csproj> -c Debug -p:Platform=ARM64
```

### Finding the build output
The output path follows this pattern:
```
bin\<Platform>\<Configuration>\<TFM>\win-<platform>\
```
Example: `bin\x64\Debug\net10.0-windows10.0.26100.0\win-x64\`

To find the TFM, check `<TargetFramework>` in the `.csproj` file.

### Build prerequisites
- .NET SDK 10.0+ (install: `winget install Microsoft.DotNet.SDK.10 --source winget`)
- winapp CLI (install: `winget install Microsoft.WinAppCLI --source winget`)
- Windows 10 1903+ or Windows 11

## Running

### Packaged apps (with Package.appxmanifest) — USE THIS
```bash
# Build first
dotnet build <project.csproj> -c Debug -p:Platform=x64

# Run with winapp (registers loose layout + launches)
winapp run bin\x64\Debug\<tfm>\win-x64\
```

`winapp run` does three things:
1. Creates a loose layout package from the build output
2. Registers it with Windows via `Add-AppxPackage`
3. Launches the app with full package identity

**⚠️ You MUST use `winapp run` for packaged apps.** Running the exe directly will silently exit because packaged apps need registration with Windows first.

### Unpackaged apps (no Package.appxmanifest)
If the project has `<WindowsPackageType>None</WindowsPackageType>`:
```bash
dotnet run --project <project.csproj> -p:Platform=x64
# Or run the exe directly:
.\bin\x64\Debug\<tfm>\win-x64\<AppName>.exe
```

### Re-run after code changes
After editing code:
```bash
dotnet build <project.csproj> -c Debug -p:Platform=x64
winapp run bin\x64\Debug\<tfm>\win-x64\
```
No need to unregister — `winapp run` handles re-registration automatically.

## Debugging Launch Issues

### App silently exits (no window, no error)

| Possible Cause | Fix |
|----------------|-----|
| Packaged app run without registration | Use `winapp run` instead of running exe directly |
| Missing Windows App SDK runtime | Run `winapp run` — it handles this, or install runtime from https://aka.ms/windowsappsdk |
| Wrong Platform (built as AnyCPU) | Add `-p:Platform=x64` to build command |
| XAML parse error in App.xaml | Check build output for XAML warnings; add try/catch in `OnLaunched` |
| Entry point mismatch | Verify `<EntryPoint>` in `Package.appxmanifest` matches the `App` class fully-qualified name |

### App launches but shows blank window

| Possible Cause | Fix |
|----------------|-----|
| x:Bind bindings not updating | `x:Bind` defaults to `OneTime`. Use `Mode=OneWay`. In DataTemplate pages, call `Bindings.Update()` in `DataContextChanged` |
| DataContext not set | Verify ViewModel is assigned to page's `DataContext` or use `x:Bind` without DataContext |
| XAML namespace wrong | Check `xmlns:local="using:CorrectNamespace"` matches code-behind namespace |
| Content outside visible area | Check window size with `winapp ui inspect`; resize with `AppWindow.Resize()` |

### Build errors

| Error | Fix |
|-------|-----|
| `error NETSDK1136: Platform must be x64, x86, or ARM64` | Add `-p:Platform=x64` to build command |
| `error CS0246: type not found` | Check namespace — WinUI uses `Microsoft.UI.Xaml`, not `System.Windows` |
| `error MC1000: XAML markup error` | Check XAML syntax — use `using:` not `clr-namespace:`, `ThemeResource` not `DynamicResource` |
| `error NU1101: package not found` | Run `dotnet restore` first |
| `APPX1101: Manifest validation error` | Check `Package.appxmanifest` for correct namespace and entry point |
| File lock errors during build | Delete `obj/` folder: `Remove-Item obj -Recurse -Force` |

### Runtime crashes

Add this to `App.xaml.cs` for better error reporting:
```csharp
public App()
{
    this.InitializeComponent();
    this.UnhandledException += (s, e) =>
    {
        System.Diagnostics.Debug.WriteLine($"Unhandled: {e.Exception}");
        File.WriteAllText("crash.log", e.Exception.ToString());
        e.Handled = true;
    };
}
```

## Using UI Automation for Verification

After launching with `winapp run`, verify the UI:
```bash
# Inspect element tree
winapp ui inspect -a <appname>

# Take screenshot
winapp ui screenshot -a <appname>

# Find specific elements
winapp ui search "#ButtonName" -a <appname>

# Click a button
winapp ui invoke "#ButtonName" -a <appname>
```

## Anti-Patterns

- ❌ Running a packaged app exe directly — will silently exit
- ❌ Adding `<WindowsPackageType>None</WindowsPackageType>` to fix launch issues — removes identity
- ❌ Building without `-p:Platform=x64` — WinUI 3 doesn't support AnyCPU
- ❌ Assuming blank window means build failed — usually a binding issue, not a build issue
- ❌ Deleting `Package.appxmanifest` to "simplify" — breaks packaged app functionality
- ❌ Using `dotnet run` for packaged apps — doesn't register the package

## Validation Checklist

- [ ] Build succeeds with 0 errors: `dotnet build -c Debug -p:Platform=x64`
- [ ] App launches via `winapp run` and shows a window
- [ ] Window has content (not blank) — verified with screenshot or `winapp ui inspect`
- [ ] Navigation between pages works (if multi-page app)
- [ ] Data bindings show actual data, not defaults
- [ ] App closes cleanly without crash dialog
