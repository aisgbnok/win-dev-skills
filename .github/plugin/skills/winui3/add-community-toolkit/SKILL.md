---
name: add-community-toolkit
description: 'Guide for using Windows Community Toolkit controls and helpers in WinUI 3 apps. Use when asked about CommunityToolkit.WinUI controls (SettingsCard, SettingsExpander, HeaderedContentControl, DataGrid, TokenizingTextBox, etc.), CommunityToolkit.Mvvm (ObservableObject, RelayCommand, source generators), or CommunityToolkit helpers (converters, behaviors, animations).'
---

# Windows Community Toolkit for WinUI 3

## Quick Reference

1. **Install only the packages you need** — the toolkit is modular; each control family and helper group ships as a separate NuGet package.
2. **Use source generators** — prefer `[ObservableProperty]` and `[RelayCommand]` over hand-written `INotifyPropertyChanged` / `ICommand` boilerplate.
3. **Add XAML namespace prefixes** — every toolkit control requires `xmlns:controls="using:CommunityToolkit.WinUI.Controls"` (or the correct sub-namespace) in your XAML.
4. **Match package versions to your TFM** — WinUI 3 apps target `net8.0-windows10.0.xxxxx.0`; ensure the toolkit package version supports that target.
5. **Check the Labs** — experimental controls live in `CommunityToolkit.Labs.WinUI.*` packages and may graduate to stable later.

---

## Package Overview

| Package | What it provides | Install command |
|---------|-----------------|-----------------|
| `CommunityToolkit.Mvvm` | `ObservableObject`, `ObservableRecipient`, `RelayCommand`, `AsyncRelayCommand`, source generators (`[ObservableProperty]`, `[RelayCommand]`, `[ObservableRecipient]`) | `dotnet add package CommunityToolkit.Mvvm` |
| `CommunityToolkit.WinUI.Controls.SettingsControls` | `SettingsCard`, `SettingsExpander` | `dotnet add package CommunityToolkit.WinUI.Controls.SettingsControls` |
| `CommunityToolkit.WinUI.Controls.Primitives` | `ConstrainedBox`, `SwitchPresenter`, `DockPanel` | `dotnet add package CommunityToolkit.WinUI.Controls.Primitives` |
| `CommunityToolkit.WinUI.Controls.Collections` | `DataGrid`, `TokenizingTextBox`, `AdaptiveGridView` | `dotnet add package CommunityToolkit.WinUI.Controls.Collections` |
| `CommunityToolkit.WinUI.Controls.Layout` | `HeaderedContentControl`, `HeaderedItemsControl`, `Segmented` | `dotnet add package CommunityToolkit.WinUI.Controls.Layout` |
| `CommunityToolkit.WinUI.Converters` | `BoolToVisibilityConverter`, `StringFormatConverter`, `BoolNegationConverter`, `EmptyStringToObjectConverter`, `CollectionVisibilityConverter` | `dotnet add package CommunityToolkit.WinUI.Converters` |
| `CommunityToolkit.WinUI.Behaviors` | `FocusBehavior`, `ViewportBehavior`, `AutoFocusBehavior`, `StackedNotificationsBehavior` | `dotnet add package CommunityToolkit.WinUI.Behaviors` |
| `CommunityToolkit.WinUI.Animations` | Implicit animations, connected animations, `AnimationSet`, `AnimationBuilder` | `dotnet add package CommunityToolkit.WinUI.Animations` |

---

## Installation

Install only what you need. For example, a typical settings-centric app:

```powershell
dotnet add package CommunityToolkit.Mvvm
dotnet add package CommunityToolkit.WinUI.Controls.SettingsControls
dotnet add package CommunityToolkit.WinUI.Converters
```

After installing, **rebuild the project** so source generators and IntelliSense pick up the new types:

```powershell
dotnet build
```

---

## Key Control Patterns

### SettingsCard + SettingsExpander

These controls provide the standard Windows 11 Settings-style layout.

```xml
<Page
    xmlns:controls="using:CommunityToolkit.WinUI.Controls">

    <!-- Simple setting with a toggle -->
    <controls:SettingsCard Header="Compact mode"
                           Description="Reduce padding between UI elements"
                           HeaderIcon="{ui:FontIcon Glyph=&#xE744;}">
        <ToggleSwitch IsOn="{x:Bind ViewModel.IsCompactMode, Mode=TwoWay}" />
    </controls:SettingsCard>

    <!-- Expandable group of related settings -->
    <controls:SettingsExpander Header="Advanced"
                               Description="Power-user options"
                               HeaderIcon="{ui:FontIcon Glyph=&#xE713;}">
        <controls:SettingsExpander.Items>
            <controls:SettingsCard Header="Logging level">
                <ComboBox SelectedIndex="{x:Bind ViewModel.LogLevel, Mode=TwoWay}"
                          MinWidth="120">
                    <ComboBoxItem Content="Error" />
                    <ComboBoxItem Content="Warning" />
                    <ComboBoxItem Content="Info" />
                    <ComboBoxItem Content="Debug" />
                </ComboBox>
            </controls:SettingsCard>
            <controls:SettingsCard Header="Enable telemetry">
                <ToggleSwitch IsOn="{x:Bind ViewModel.TelemetryEnabled, Mode=TwoWay}" />
            </controls:SettingsCard>
        </controls:SettingsExpander.Items>
    </controls:SettingsExpander>
</Page>
```

> **Tip:** `SettingsCard` can display any content in its action area (right side). Common choices: `ToggleSwitch`, `ComboBox`, `Button`, `HyperlinkButton`.

### HeaderedContentControl

Wraps any content with a consistent header and optional description.

```xml
<Page
    xmlns:controls="using:CommunityToolkit.WinUI.Controls">

    <controls:HeaderedContentControl Header="Profile picture"
                                      Description="Choose an image to represent your account">
        <PersonPicture ProfilePicture="{x:Bind ViewModel.AvatarSource}" />
    </controls:HeaderedContentControl>
</Page>
```

### DataGrid Basics

A full-featured data grid for tabular data.

```xml
<Page
    xmlns:controls="using:CommunityToolkit.WinUI.Controls">

    <controls:DataGrid ItemsSource="{x:Bind ViewModel.Employees}"
                        AutoGenerateColumns="False"
                        IsReadOnly="True"
                        GridLinesVisibility="Horizontal"
                        AlternatingRowBackground="{ThemeResource CardBackgroundFillColorDefaultBrush}">
        <controls:DataGrid.Columns>
            <controls:DataGridTextColumn Header="Name"
                                          Binding="{Binding FullName}" />
            <controls:DataGridTextColumn Header="Department"
                                          Binding="{Binding Department}" />
            <controls:DataGridTextColumn Header="Start Date"
                                          Binding="{Binding StartDate}" />
        </controls:DataGrid.Columns>
    </controls:DataGrid>
</Page>
```

> **Note:** `DataGrid` columns use `{Binding}` (not `{x:Bind}`) because column bindings resolve against the row item, not the page.

### SwitchPresenter

Conditionally displays content based on a value — a XAML-only replacement for converters in simple show/hide scenarios.

```xml
<controls:SwitchPresenter Value="{x:Bind ViewModel.Status, Mode=OneWay}">
    <controls:Case Value="Loading">
        <ProgressRing IsActive="True" />
    </controls:Case>
    <controls:Case Value="Loaded">
        <TextBlock Text="Data loaded successfully." />
    </controls:Case>
    <controls:Case Value="Error">
        <TextBlock Text="Something went wrong." Foreground="Red" />
    </controls:Case>
</controls:SwitchPresenter>
```

---

## MVVM Source Generators

The `CommunityToolkit.Mvvm` package provides source generators that eliminate boilerplate. The ViewModel class **must** be `partial`.

### `[ObservableProperty]`

Generates a public property with `PropertyChanged` notification from a private field.

```csharp
using CommunityToolkit.Mvvm.ComponentModel;

namespace MyApp.ViewModels;

public partial class MainViewModel : ObservableObject
{
    [ObservableProperty]
    private string _title = "Hello";

    [ObservableProperty]
    private bool _isBusy;

    // Generated: public string Title { get; set; }  (with INPC)
    // Generated: public bool IsBusy { get; set; }    (with INPC)

    // Optional: react to changes
    partial void OnTitleChanged(string value)
    {
        // Runs after Title is set
    }

    partial void OnIsBusyChanged(bool oldValue, bool newValue)
    {
        // Overload with old and new values
    }
}
```

**Naming convention:** the field must start with `_` or `m_`. The generator strips the prefix and capitalizes: `_title` → `Title`, `m_count` → `Count`.

### `[RelayCommand]`

Generates an `ICommand` property from a method.

```csharp
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;

namespace MyApp.ViewModels;

public partial class MainViewModel : ObservableObject
{
    [ObservableProperty]
    private bool _isBusy;

    [RelayCommand(CanExecute = nameof(CanSave))]
    private async Task SaveAsync()
    {
        IsBusy = true;
        await _repository.SaveAsync();
        IsBusy = false;
    }

    private bool CanSave() => !IsBusy;

    // Generated: public IAsyncRelayCommand SaveCommand { get; }
}
```

Bind in XAML:

```xml
<Button Content="Save" Command="{x:Bind ViewModel.SaveCommand}" />
```

> **Agent Rule:** When generating a ViewModel, always make the class `partial` and inherit from `ObservableObject`. Without `partial`, the source generators cannot emit the property/command implementations.

### `[NotifyPropertyChangedFor]` and `[NotifyCanExecuteChangedFor]`

Chain property and command invalidation:

```csharp
[ObservableProperty]
[NotifyPropertyChangedFor(nameof(FullName))]
private string _firstName = string.Empty;

[ObservableProperty]
[NotifyPropertyChangedFor(nameof(FullName))]
private string _lastName = string.Empty;

public string FullName => $"{FirstName} {LastName}";

[ObservableProperty]
[NotifyCanExecuteChangedFor(nameof(SaveCommand))]
private bool _isBusy;
```

---

## Common Converters Reference

Add the XAML namespace:

```xml
xmlns:converters="using:CommunityToolkit.WinUI.Converters"
```

Declare in page or `App.xaml` resources:

```xml
<Page.Resources>
    <converters:BoolToVisibilityConverter x:Key="BoolToVis" />
    <converters:BoolNegationConverter x:Key="BoolNeg" />
    <converters:StringFormatConverter x:Key="StringFmt" />
    <converters:EmptyStringToObjectConverter x:Key="EmptyToObj"
        NotEmptyValue="Visible" EmptyValue="Collapsed" />
    <converters:CollectionVisibilityConverter x:Key="CollectionToVis" />
</Page.Resources>
```

Usage:

```xml
<!-- Show element only when IsBusy is true -->
<ProgressRing Visibility="{x:Bind ViewModel.IsBusy, Converter={StaticResource BoolToVis}, Mode=OneWay}" />

<!-- Disable button when IsBusy is true -->
<Button IsEnabled="{x:Bind ViewModel.IsBusy, Converter={StaticResource BoolNeg}, Mode=OneWay}"
        Content="Submit" />

<!-- Format a string -->
<TextBlock Text="{x:Bind ViewModel.Count, Converter={StaticResource StringFmt}, ConverterParameter='{}{0} items', Mode=OneWay}" />

<!-- Show when collection has items -->
<ListView Visibility="{x:Bind ViewModel.Items.Count, Converter={StaticResource CollectionToVis}, Mode=OneWay}" />
```

> **Tip:** Prefer `x:Bind` function bindings over converters where possible — they are compiled and faster: `Visibility="{x:Bind vm:Converters.ToVisibility(ViewModel.IsBusy), Mode=OneWay}"`.

---

## Animations Quick Start

### Implicit Animations

Apply smooth transitions automatically when properties change:

```xml
<Page
    xmlns:ani="using:CommunityToolkit.WinUI.Animations">

    <Border Width="200" Height="200"
            Background="{ThemeResource AccentFillColorDefaultBrush}"
            ani:Implicit.ShowAnimations="{StaticResource DefaultShowAnimations}"
            ani:Implicit.HideAnimations="{StaticResource DefaultHideAnimations}">
        <ani:Implicit.Animations>
            <ani:OffsetAnimation Duration="0:0:0.3" />
            <ani:ScaleAnimation Duration="0:0:0.3" />
            <ani:OpacityAnimation Duration="0:0:0.3" />
        </ani:Implicit.Animations>
    </Border>
</Page>
```

---

## Anti-patterns

❌ **Installing the umbrella `CommunityToolkit.WinUI` meta-package** — it pulls in every control and inflates app size. Install only the specific sub-packages you need (e.g., `CommunityToolkit.WinUI.Controls.SettingsControls`).

❌ **Forgetting `partial` on ViewModel classes** — source generators for `[ObservableProperty]` and `[RelayCommand]` require the class to be `partial`. Without it, the generated code is silently not emitted and bindings fail at runtime.

❌ **Using `{Binding}` when `{x:Bind}` is available** — `{Binding}` is reflection-based and slower. Use `{x:Bind}` for compile-time type checking and better performance. Exception: `DataGrid` column bindings require `{Binding}`.

❌ **Not rebuilding after adding a Toolkit package** — source generators and XAML designer support require a build to activate. Always `dotnet build` after adding or updating a package.

❌ **Mixing CommunityToolkit.WinUI 7.x (UWP) with 8.x (WinUI 3)** — the 7.x packages target UWP and will not compile in a WinUI 3 / Windows App SDK project. Ensure all `CommunityToolkit.WinUI.*` packages are version **8.x** or later.

---

## Verification Checklist

- [ ] Only the required toolkit packages are installed (check `.csproj`)
- [ ] All ViewModels using source generators are declared `partial` and inherit `ObservableObject`
- [ ] XAML files include the correct `xmlns` for each toolkit namespace used
- [ ] Project builds without warnings after package installation
- [ ] `DataGrid` column bindings use `{Binding}` (not `{x:Bind}`)
- [ ] No UWP-era 7.x packages are referenced in a WinUI 3 project

---

## Must Read & Research

| # | Reference | When to consult |
|---|-----------|-----------------|
| 1 | [CommunityToolkit.Mvvm overview](https://learn.microsoft.com/dotnet/communitytoolkit/mvvm/) | Setting up MVVM with source generators |
| 2 | [SettingsCard / SettingsExpander docs](https://learn.microsoft.com/dotnet/communitytoolkit/windows/settingscontrols/settingscard) | Building a Settings page UI |
| 3 | [DataGrid for WinUI 3](https://learn.microsoft.com/dotnet/communitytoolkit/windows/controls/datagrid) | Showing tabular data |
| 4 | [Converter reference](https://learn.microsoft.com/dotnet/communitytoolkit/windows/converters/booltovisibilityconverter) | Using built-in value converters |
| 5 | [Windows Community Toolkit GitHub](https://github.com/CommunityToolkit/Windows) | Checking latest releases, issues, and Labs controls |
