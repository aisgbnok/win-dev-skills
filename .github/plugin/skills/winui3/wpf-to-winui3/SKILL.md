---
name: wpf-to-winui3
description: 'Guide for migrating .NET WPF applications to WinUI 3 (Windows App SDK). Use when asked to migrate WPF code, convert WPF XAML to WinUI 3, replace System.Windows namespaces with Microsoft.UI.Xaml, update Dispatcher to DispatcherQueue, replace DynamicResource with ThemeResource, migrate imaging APIs, convert WPF Window to WinUI Window, migrate .resx to .resw resources, migrate custom Observable/RelayCommand to CommunityToolkit.Mvvm source generators, or handle WPF control library to WinUI native control migration. Keywords: WPF, WinUI, WinUI3, migration, porting, convert, namespace, XAML, Dispatcher, DispatcherQueue, ThemeResource, DynamicResource, ResourceLoader, resw, resx, CommunityToolkit, ObservableProperty.'
---

# WPF to WinUI 3 Migration Skill

Migrate .NET WPF applications (`System.Windows.*`) to WinUI 3 (`Microsoft.UI.Xaml.*` / Windows App SDK).

## Quick Reference

- **Do NOT spawn a winui3-builder sub-agent** — Do all migration work yourself. Spawning sub-agents causes file conflicts where both agents overwrite each other's changes, wasting massive tokens.
- **Set `<RootNamespace>` immediately after `dotnet new winui`** — The template creates a namespace based on the project name. Set `<RootNamespace>` in the csproj to match your existing WPF namespace BEFORE porting any code. Also update `x:Class` in `App.xaml` and `MainWindow.xaml`.
- **Use `winapp run <build-output>` to test** — Packaged WinUI 3 apps cannot be launched by running the exe directly. Always use `winapp run` which registers the app with Windows and launches it. Never switch to `<WindowsPackageType>None</WindowsPackageType>` to work around launch issues.
- **`x:Bind` defaults to `OneTime`** — Unlike WPF's `{Binding}` (default OneWay), WinUI 3's `x:Bind` defaults to `OneTime`. Always set `Mode=OneWay` or `Mode=TwoWay` explicitly. In DataTemplate pages, add `Bindings.Update()` in the `DataContextChanged` handler.
- **Replace custom MVVM with CommunityToolkit.Mvvm** — Delete custom `Observable`, `RelayCommand`, and `DelegateCommand` classes. Use `[ObservableProperty]` and `[RelayCommand]` source generators instead.
- **Convert page switching to Frame navigation** — WPF's implicit DataTemplate page-switching should use Frame-based navigation (`Frame.Navigate(typeof(PageType), param)`) in WinUI 3, not `ContentControl` + `DataTemplateSelector`.
- **Scan for `System.Windows` after porting** — Run `Select-String -Pattern 'System.Windows' -Recurse -Include '*.cs'` to catch any remaining WPF-only namespace references.

---

## Critical Migration Rules

### Rule 1: No Sub-Agents
Do **all** migration work yourself — including XAML view creation, code-behind, and ViewModels. Do NOT spawn a winui3-builder agent or any other sub-agent to create views. When two agents modify the same project files simultaneously, they overwrite each other's changes, causing:
- Namespace reverts (agent A fixes a namespace, agent B reverts it)
- Deleted files re-appearing (agent A deletes a file, agent B re-creates it)
- 15+ minutes of wasted work fighting over the same files

### Rule 2: Namespace Alignment (Do FIRST)
After creating the WinUI 3 project with `dotnet new winui -n <Name>`:
1. Open the `.csproj` and add/set `<RootNamespace>YourExistingNamespace</RootNamespace>`
2. Update `App.xaml`: change `x:Class="<Name>.App"` to `x:Class="YourExistingNamespace.App"`
3. Update `App.xaml.cs`: change `namespace <Name>` to `namespace YourExistingNamespace`
4. Update `MainWindow.xaml` and `MainWindow.xaml.cs` similarly
5. Build to verify before porting any code

### Rule 3: Always Use `winapp run` for Packaged Apps
Packaged WinUI 3 apps (with `Package.appxmanifest`) cannot be launched by running the exe directly — they will silently exit. Use:
```bash
dotnet build <project.csproj> -c Debug -p:Platform=x64
winapp run bin\x64\Debug\<tfm>\win-x64\
```
**Never** add `<WindowsPackageType>None</WindowsPackageType>` to work around launch issues — this removes package identity and breaks Windows API access.

### Rule 4: Source Analysis Strategy
Read source files efficiently to minimize token waste:
1. **Start with csproj** — understand dependencies, TFM, NuGet packages
2. **Read App.xaml/cs** — understand startup, DI, global resources
3. **Batch-read models/services** — use explore agents to read all at once
4. **Read ViewModels** — understand data flow and commands
5. **Read Views last** — XAML is verbose; only read what you need for each page
6. **Defer helpers/converters** — port them only when build errors reference them

## When to Use This Skill

- Migrate a .NET WPF application or module to WinUI 3
- Convert WPF XAML files to WinUI 3 XAML
- Replace `System.Windows` namespaces with `Microsoft.UI.Xaml`
- Migrate `Dispatcher` usage to `DispatcherQueue`
- Migrate custom `Observable`/`RelayCommand` to CommunityToolkit.Mvvm source generators
- Replace third-party WPF control libraries (e.g., WPF-UI / Lepo) with native WinUI 3 controls
- Handle WPF `Window` vs WinUI `Window` differences (sizing, positioning, SizeToContent)
- Migrate resource files from `.resx` to `.resw` with `ResourceLoader`
- Update project files, NuGet packages, and TFMs

## Prerequisites

- Visual Studio 2022 17.4+
- Windows App SDK NuGet package (`Microsoft.WindowsAppSDK`)
- .NET 8+ or .NET 10+ with Windows 10 TFM (e.g., `net8.0-windows10.0.19041.0` or `net10.0-windows10.0.26100.0`)
- Windows 10 1803+ (April 2018 Update or newer)

## Migration Strategy

### Recommended Order

> **⚠️ Before each step, read the linked reference doc(s) thoroughly.** The quick-reference tables in this file are summaries — the reference docs contain critical details, edge cases, and code examples needed for correct conversion.

1. **Project file** — Update TFM, NuGet packages, set `<UseWinUI>true</UseWinUI>`. Read [Namespace and API Mapping → Project File Changes](./references/namespace-api-mapping.md#project-file-changes)
2. **Data models and business logic** — No UI dependencies, migrate first. Read [Namespace and API Mapping](./references/namespace-api-mapping.md) for type replacements
3. **MVVM framework** — Replace custom Observable/RelayCommand with CommunityToolkit.Mvvm source generators (`[ObservableProperty]`, `[RelayCommand]`)

   **Concrete steps:**
   - Delete custom `Observable.cs`, `RelayCommand.cs`, `DelegateCommand.cs`
   - Add package: `dotnet add package CommunityToolkit.Mvvm`
   - Replace `Observable` base class → `ObservableObject`
   - Replace manual `SetProperty`/`OnPropertyChanged` → `[ObservableProperty]` attribute on fields
   - Replace custom `RelayCommand` → `[RelayCommand]` attribute on methods
   - Replace `ICommand` properties → auto-generated by `[RelayCommand]`

4. **Resource strings** — Migrate `.resx` → `.resw`, introduce `ResourceLoader`. Read [XAML Migration → Resource Strings](./references/xaml-migration.md#xstatic-resource-strings--xuid)

   **Concrete steps:**
   ```powershell
   # Create WinUI 3 resource structure
   mkdir "Strings\en-us"
   # Convert .resx to .resw (same XML format, just rename and move)
   Copy-Item "Properties\Resources.resx" "Strings\en-us\Resources.resw"
   # Remove Designer.cs (not used in WinUI 3)
   Remove-Item "Properties\Resources.Designer.cs"
   ```
   In XAML, replace `{x:Static props:Resources.Key}` with `x:Uid="Key"` and add `.Content`, `.Text`, etc. properties in the `.resw` file.
   In C#, replace `Properties.Resources.Key` with `ResourceLoader.GetForViewIndependentUse().GetString("Key")`.
5. **Services and utilities** — Replace `System.Windows` types with WinUI equivalents. Read [Namespace and API Mapping](./references/namespace-api-mapping.md)
6. **ViewModels** — Update Dispatcher usage, binding patterns. Read [Threading and Windowing](./references/threading-and-windowing.md)
7. **Views/Pages** — Starting from leaf pages with fewest dependencies. Read [XAML Migration Guide](./references/xaml-migration.md) thoroughly before converting any XAML
8. **Main page / shell** — Last, since it depends on everything. Read [XAML Migration](./references/xaml-migration.md) and [Threading and Windowing](./references/threading-and-windowing.md)
9. **App.xaml / startup code** — MERGE carefully (do NOT overwrite WinUI 3 boilerplate). Read [XAML Migration → App.xaml Resources](./references/xaml-migration.md#appxaml-resources)
10. **Tests** — Adapt for WinUI 3 runtime and async patterns

### Key Principles

- **Do NOT overwrite `App.xaml` / `App.xaml.cs`** — WinUI 3 has different application lifecycle boilerplate. Merge your resources and initialization code into the generated WinUI 3 App class.
- **Do NOT create Exe→WinExe `ProjectReference`** — Extract shared code to a Library project to avoid phantom build artifacts.
- **Use `Lazy<T>` for resource-dependent statics** — `ResourceLoader` is not available at class-load time in all contexts.

## Quick Reference Tables

### Namespace Mapping

| WPF | WinUI 3 |
|-----|---------|
| `System.Windows` | `Microsoft.UI.Xaml` |
| `System.Windows.Controls` | `Microsoft.UI.Xaml.Controls` |
| `System.Windows.Media` | `Microsoft.UI.Xaml.Media` |
| `System.Windows.Media.Imaging` | `Microsoft.UI.Xaml.Media.Imaging` |
| `System.Windows.Input` | `Microsoft.UI.Xaml.Input` |
| `System.Windows.Data` | `Microsoft.UI.Xaml.Data` |
| `System.Windows.Threading` | `Microsoft.UI.Dispatching` |
| `System.Windows.Interop` | `WinRT.Interop` |

### Critical API Replacements

| WPF | WinUI 3 | Notes |
|-----|---------|-------|
| `Dispatcher.Invoke()` | `DispatcherQueue.TryEnqueue()` | Returns `bool` |
| `Dispatcher.CheckAccess()` | `DispatcherQueue.HasThreadAccess` | Property vs method |
| `Application.Current.Dispatcher` | Store `DispatcherQueue` in static field | See [Threading](./references/threading-and-windowing.md) |
| `MessageBox.Show()` | `ContentDialog` | Must set `XamlRoot` |
| `DynamicResource` | `ThemeResource` | Theme-reactive only |
| `clr-namespace:` | `using:` | XAML namespace prefix |
| `{x:Static props:Resources.Key}` | `x:Uid` or `ResourceLoader.GetString()` | .resx → .resw |
| `DataType="{x:Type m:Foo}"` | `x:DataType="m:Foo"` | `x:Type` not supported |
| `Properties.Resources.MyString` | `ResourceLoader.GetString("MyString")` | Lazy-init pattern |
| `Application.Current.MainWindow` | Custom `App.Window` static property | Must track manually |
| `SizeToContent="Height"` | Manual `AppWindow.Resize()` | See [Windowing](./references/threading-and-windowing.md) |
| `MouseLeftButtonDown` | `PointerPressed` | Mouse → Pointer events |
| `Pack URI (pack://...)` | `ms-appx:///` | Resource URI scheme |
| `Observable` (custom base) | `ObservableObject` + `[ObservableProperty]` | CommunityToolkit.Mvvm |
| `RelayCommand` (custom) | `[RelayCommand]` source generator | CommunityToolkit.Mvvm |

### NuGet Package Migration

| WPF | WinUI 3 |
|-----|---------|
| `Microsoft.Xaml.Behaviors.Wpf` | `Microsoft.Xaml.Behaviors.WinUI.Managed` |
| Third-party WPF control libraries | Remove — use native WinUI 3 controls |
| `CommunityToolkit.Mvvm` | `CommunityToolkit.Mvvm` (same) |
| `Microsoft.Toolkit.Wpf.*` | `CommunityToolkit.WinUI.*` |
| (none) | `Microsoft.WindowsAppSDK` |
| (none) | `Microsoft.Windows.SDK.BuildTools` |
| (none) | `WinUIEx` (optional, for window helpers) |
| (none) | `CommunityToolkit.WinUI.Converters` |

### XAML Syntax Changes

| WPF | WinUI 3 |
|-----|---------|
| `xmlns:local="clr-namespace:MyApp"` | `xmlns:local="using:MyApp"` |
| `{DynamicResource Key}` | `{ThemeResource Key}` |
| `{x:Static Type.Member}` | `{x:Bind}` or code-behind |
| `{x:Type local:MyType}` | Not supported |
| `<Style.Triggers>` / `<DataTrigger>` | `VisualStateManager` |
| `{Binding}` in `Setter.Value` | Not supported — use `StaticResource` |
| `Content="{x:Static p:Resources.Cancel}"` | `x:Uid="Cancel"` with `.Content` in `.resw` |
| `BasedOn="{StaticResource {x:Type Button}}"` | `BasedOn="{StaticResource DefaultButtonStyle}"` |
| `IsDefault="True"` / `IsCancel="True"` | `Style="{StaticResource AccentButtonStyle}"` / handle via KeyDown |
| `<AccessText>` | Not available — use `AccessKey` property |
| `<behaviors:Interaction.Triggers>` | Migrate to code-behind or WinUI behaviors |

### Page Navigation Pattern

**WPF pattern (don't port this directly):**
```xaml
<!-- WPF: ContentControl with implicit DataTemplates -->
<ContentControl Content="{Binding CurrentViewModel}">
    <ContentControl.Resources>
        <DataTemplate DataType="{x:Type vm:InputViewModel}">
            <views:InputPage/>
        </DataTemplate>
    </ContentControl.Resources>
</ContentControl>
```

**WinUI 3 pattern (use this instead):**
```xaml
<!-- WinUI 3: Frame-based navigation -->
<Frame x:Name="ContentFrame"/>
```
```csharp
// Navigate with parameter
ContentFrame.Navigate(typeof(InputPage), viewModel);

// In the page, receive the parameter
protected override void OnNavigatedTo(NavigationEventArgs e)
{
    if (e.Parameter is InputViewModel vm)
        ViewModel = vm;
}
```
WinUI 3 does not support implicit DataTemplates (`DataType` on `DataTemplate` is not available). Use `Frame.Navigate()` instead.

## Common Pitfalls

| Pitfall | Solution |
|---------|----------|
| `ContentDialog` throws "does not have a XamlRoot" | Set `dialog.XamlRoot = this.Content.XamlRoot` before `ShowAsync()` |
| `FilePicker` throws error in desktop app | Call `WinRT.Interop.InitializeWithWindow.Initialize(picker, hwnd)` |
| `Window.Dispatcher` returns null | Use `Window.DispatcherQueue` instead |
| Resources on `Window` element not found | Move resources to root layout container (`Grid.Resources`) |
| `VisualStateManager` on `Window` fails | Use `UserControl` or `Page` inside the Window |
| `ResourceLoader` crash at static init | Wrap in `Lazy<T>` or null-coalescing property |
| `SizeToContent` not available | Implement manual content measurement + `AppWindow.Resize()` with DPI scaling |
| `x:Bind` default mode is `OneTime` | Explicitly set `Mode=OneWay` or `Mode=TwoWay` |
| `DynamicResource` / `x:Static` not compiling | Replace with `ThemeResource` / `ResourceLoader` or `x:Uid` |
| `IValueConverter.Convert` signature mismatch | Last param: `CultureInfo` → `string` (language tag) |
| `DataContext` not working on Window | WinUI 3 `Window` is not a `DependencyObject`; use a root `Page` or `UserControl` |
| XAML Designer not available | WinUI 3 does not support XAML Designer; use Hot Reload instead |

### DataContext + x:Bind Pitfall (Critical)

When using `x:Bind` in pages that receive their `DataContext` at runtime (e.g., from a `DataTemplate` or `Frame.Navigate`), bindings won't update because `x:Bind` defaults to `OneTime` and evaluates before `DataContext` is set.

**Fix 1: Add `Bindings.Update()` on DataContextChanged**
```csharp
public sealed partial class InputPage : Page
{
    public InputPage()
    {
        this.InitializeComponent();
        this.DataContextChanged += (s, e) => Bindings.Update();
    }

    public InputViewModel ViewModel => DataContext as InputViewModel;
}
```

**Fix 2: If command bindings still don't fire, use Click handlers as fallback**
```csharp
// In XAML: <Button Click="OnResizeClick" ... />
private void OnResizeClick(object sender, RoutedEventArgs e)
{
    ViewModel?.ResizeCommand.Execute(null);
}
```
This is needed because `x:Bind` command bindings through `DataContext` can be unreliable in `DataTemplate` scenarios. Prefer `Click` handlers that delegate to the ViewModel command.

## Detailed Reference Docs

Read only the section relevant to your current task:

- [Namespace and API Mapping](./references/namespace-api-mapping.md) — Full type mapping, NuGet changes, project file, CsWinRT interop
- [XAML Migration Guide](./references/xaml-migration.md) — XAML syntax, markup extensions, styles, resources, data binding, control replacements
- [Threading and Window Management](./references/threading-and-windowing.md) — Dispatcher, DispatcherQueue, SizeToContent, AppWindow, HWND interop, custom title bar

## Post-Migration Validation

Run these checks after completing the migration:

### 1. Check for remaining WPF references
```powershell
# Find any lingering System.Windows references (should return 0 results)
Select-String -Path (Get-ChildItem -Recurse -Filter "*.cs" | Where-Object { $_.FullName -notlike "*\obj\*" }) -Pattern "System\.Windows\." | Where-Object { $_.Line -notlike "*// WPF:*" }
```

### 2. Verify packaging is preserved
```powershell
# Ensure app is still packaged (should NOT find WindowsPackageType=None)
Select-String -Path "*.csproj" -Pattern "WindowsPackageType.*None"
# Verify manifest exists
Test-Path "Package.appxmanifest"
```

### 3. Build and run
```bash
dotnet build <project.csproj> -c Debug -p:Platform=x64
winapp run bin\x64\Debug\<tfm>\win-x64\
```

### 4. Verify UI renders
After launching with `winapp run`, take a screenshot or use `winapp ui inspect` to verify:
- All pages render content (not blank)
- Navigation between pages works
- Data bindings show data (not empty or default values)

### 5. Check for custom MVVM remnants
```powershell
# Should not find custom Observable/RelayCommand classes
Get-ChildItem -Recurse -Filter "*.cs" | Select-String -Pattern "class (Observable|RelayCommand|DelegateCommand)\b" | Where-Object { $_.Line -notlike "*///*" }
```

## External References

- [WinUI 3 Overview](https://learn.microsoft.com/en-us/windows/apps/winui/winui3/) — Getting started, samples, and the WinUI 3 Gallery
- [CommunityToolkit.Mvvm Documentation](https://learn.microsoft.com/en-us/dotnet/communitytoolkit/mvvm/) — ObservableObject, RelayCommand, source generators
- [WinUI 3 Controls Gallery](https://learn.microsoft.com/en-us/windows/apps/design/controls/) — Native control catalog
- [Windows App SDK API Reference](https://learn.microsoft.com/en-us/windows/windows-app-sdk/api/winrt/) — Full WinUI 3 and Windows App SDK API reference
- [Migrate from WPF to WinUI 3](https://learn.microsoft.com/en-us/windows/apps/winui/winui3/migrate-from-wpf) — Official migration guide
