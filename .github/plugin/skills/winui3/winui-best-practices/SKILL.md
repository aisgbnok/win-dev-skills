---
name: winui-best-practices
description: 'WinUI 3 / WinAppSDK architecture, MVVM, XAML patterns, DI, theming, navigation, and controls guidance. Use when building or modifying WinUI 3 UI code.'
---

## Quick Reference

- **Use MVVM with CommunityToolkit.Mvvm** — `[ObservableProperty]` and `[RelayCommand]` source generators eliminate boilerplate.
- **Always use `x:Bind` over `{Binding}`** — compiled, type-safe, faster. Set `Mode=` explicitly (defaults to `OneTime`).
- **Use `Microsoft.UI.Xaml`, not `Windows.UI.Xaml`** — UWP namespaces won't work in WinUI 3 desktop apps.
- **Use `{ThemeResource}` for all colors** — never hardcode hex values. Ensures Light, Dark, and High Contrast.
- **Use `DispatcherQueue`, not `CoreDispatcher`** — never call `Window.Current`; pass window references explicitly.

---

# WinUI 3 — Project Setup & Architecture

Covers project-level setup, folder conventions, DI, navigation, and WinUI 3 pitfalls. For deep dives, see [Related Skills](#related-skills).

---

## 1. Project Structure

```
<ProjectName>/
  Models/    ViewModels/    Views/    Services/
  Converters/    Helpers/    Controls/    Assets/
  Strings/en-us/Resources.resw
```

| Layer | Responsibility | Example |
|---|---|---|
| **Model** | Data structures & business entities | `Item.cs` |
| **View** | XAML UI, layout, styles | `MainPage.xaml` |
| **ViewModel** | UI state, commands, data transformation | `MainViewModel.cs` |
| **Service** | Business logic, data access, navigation | `IDataService.cs` |

---

## 2. App.xaml & Dependency Injection

Always include `XamlControlsResources` in App.xaml merged dictionaries. Wire DI in `App.xaml.cs`:

```csharp
public partial class App : Application
{
    public static IServiceProvider Services { get; private set; } = null!;
    public App() { InitializeComponent(); Services = ConfigureServices(); }

    private static IServiceProvider ConfigureServices()
    {
        var services = new ServiceCollection();
        services.AddSingleton<INavigationService, NavigationService>();
        services.AddTransient<IDataService, DataService>();
        services.AddTransient<MainViewModel>();
        return services.BuildServiceProvider();
    }
}
```

---

## 3. Navigation

Use `NavigationView` + `Frame`. Define `INavigationService` (`CanGoBack`, `NavigateTo<TPage>()`, `GoBack()`) and register in DI.

---

## 4. XAML Conventions

- Use `Microsoft.UI.Xaml.Controls`, never `Windows.UI.Xaml.Controls`.
- **Attribute order** (one per line for 3+ attrs): `x:Name` → `x:Uid` → `AutomationProperties` → layout → data → style.
- **System Backdrop:** Mica for main window, Acrylic for overlays.
- **Theming:** Always `{ThemeResource}` for colors/brushes. Detect changes via `rootElement.ActualThemeChanged`.

> Use [XAML Styler](https://github.com/Xavalon/XamlStyler) for automated formatting.

---

## 5. Common Pitfalls

| Pitfall | Solution |
|---|---|
| `Windows.UI.Xaml` namespace | Use `Microsoft.UI.Xaml` |
| `Window.Current` | Pass window reference explicitly |
| `CoreDispatcher` | Use `DispatcherQueue` |
| `REGDB_E_CLASSNOTREG` | Enable Developer Mode; re-register MSIX |
| XAML Designer crashes | Clean & rebuild; match platform (x64) |
| `{Binding}` not updating | Use `x:Bind` with `Mode=OneWay`/`TwoWay` |

---

## 6. Validation Checklist

- Verify UI renders correctly on x64.
- Replace `{Binding` → `x:Bind`, `Foreground="#`/`Background="#` → `{ThemeResource}`.
- Replace `Windows.UI.Xaml` → `Microsoft.UI.Xaml`, `Window.Current` → explicit ref, `CoreDispatcher` → `DispatcherQueue`.
- Test Light, Dark, and High Contrast themes.

---

## 7. Must Read

> **Agent Rule:** Before making WinUI/WinAppSDK changes, **fetch and review** relevant references using `fetch_webpage`.

- [WinUI 3 Overview](https://learn.microsoft.com/en-us/windows/apps/winui/winui3/) | [Windows App SDK](https://learn.microsoft.com/en-us/windows/apps/windows-app-sdk/) | [API Reference](https://learn.microsoft.com/en-us/windows/windows-app-sdk/api/winrt/)
- [WinUI 3 Gallery](https://learn.microsoft.com/en-us/windows/apps/design/controls/) | [CommunityToolkit.Mvvm](https://learn.microsoft.com/en-us/dotnet/communitytoolkit/mvvm/)
- [Windows APIs instruction file](windows-apis.instructions.md) — built-in APIs (AI, windowing, notifications)

> **Sample-First Rule (MANDATORY):** Before implementing any new WinAppSDK API, **search [Windows App SDK Samples](https://github.com/microsoft/WindowsAppSDK-Samples) first**. See [Sample-First Rule](windows-apis.instructions.md#sample-first-rule).

---

## Related Skills

For detailed guidance, see these specialized skills:

| Topic | Skill | Covers |
|-------|-------|--------|
| MVVM patterns & CommunityToolkit | `advanced-mvvm` | Source generators, messenger, behaviors, validation, async commands |
| Data binding & x:Bind | `data-binding` | x:Bind vs {Binding}, modes, converters, templates, CollectionViewSource |
| Performance optimization | `performance` | x:Load/x:Phase, virtualization, DispatcherQueue threading |
| Design principles | `design-principles` | DRY, KISS, SOLID, YAGNI enforcement |
| Fluent Design System | `fluent-design` | Type ramp, spacing, colors, materials (Mica/Acrylic), motion |
| Windowing & title bars | `advanced-windowing` | AppWindow API, TitleBar control, presenters, multi-window |