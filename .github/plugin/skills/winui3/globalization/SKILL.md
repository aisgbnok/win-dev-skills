---
name: globalization
description: 'Globalization and localization requirements — .resw resource files, x:Uid, culture-aware formatting. Use when adding user-facing text.'
---

# Globalization & Localization

These rules apply to **every feature and change** involving user-facing text. They are not optional add-ons.

---

## Quick Reference

1. **All user-facing strings** must come from `.resw` resource files — never hard-code them.
2. **Use `x:Uid`** in XAML to bind controls to resource keys.
3. **Use `ResourceLoader`** in C# code-behind and ViewModels.
4. **Format dates, numbers, and currencies** with `CultureInfo.CurrentCulture` — never assume a format.
5. **Design for text expansion** — translated text can be 30-40% longer than English.

---

## Rules

### .resw File Setup and Structure

Resource files live under `Strings/{language-tag}/` in the project. The default locale uses `en-us`:

```
MyApp/
├── Strings/
│   ├── en-us/
│   │   └── Resources.resw
│   ├── de-de/
│   │   └── Resources.resw
│   └── ja-jp/
│       └── Resources.resw
```

Each `.resw` file is an XML table of name–value pairs. Use dot notation for property targeting:

| Name | Value |
|---|---|
| `SaveButton.Content` | Save |
| `WelcomeMessage.Text` | Welcome! |
| `SearchBox.PlaceholderText` | Search… |
| `NameInput.Header` | Full Name |
| `ErrorFileNotFound` | The file could not be found. |

> **Naming convention:** Use PascalCase for the resource key, followed by a dot and the XAML property name. Keys without a dot suffix (like `ErrorFileNotFound`) are used in code-behind via `ResourceLoader`.

### x:Uid Binding Patterns

Use `x:Uid` in XAML to bind control properties to `.resw` entries. A single `x:Uid` can set multiple properties for the same control:

```xml
<!-- Sets SaveButton.Content from .resw -->
<Button x:Uid="SaveButton" />

<!-- Sets WelcomeMessage.Text from .resw -->
<TextBlock x:Uid="WelcomeMessage" />

<!-- Sets SearchBox.PlaceholderText and SearchBox.Header from .resw -->
<TextBox x:Uid="SearchBox" />

<!-- Sets DeleteConfirmDialog.Title, .Content, .PrimaryButtonText, .CloseButtonText -->
<ContentDialog x:Uid="DeleteConfirmDialog" />
```

Common property suffixes in `.resw`:

| Suffix | XAML Property | Controls |
|---|---|---|
| `.Text` | `TextBlock.Text` | `TextBlock` |
| `.Content` | `ContentControl.Content` | `Button`, `CheckBox`, `RadioButton` |
| `.PlaceholderText` | `TextBox.PlaceholderText` | `TextBox`, `AutoSuggestBox` |
| `.Header` | `HeaderedContentControl.Header` | `TextBox`, `ComboBox`, `Slider` |
| `.Title` | `ContentDialog.Title` | `ContentDialog` |
| `.Description` | `SettingsCard.Description` | `SettingsCard` |

### ResourceLoader in Code-Behind and ViewModels

Use `ResourceLoader` from the Windows App SDK to retrieve strings in C#:

```csharp
using Microsoft.Windows.ApplicationModel.Resources;

public class MainViewModel
{
    private readonly ResourceLoader _resourceLoader = new();

    public string GetErrorMessage(string fileName)
    {
        // Retrieves "ErrorFileNotFound" from Resources.resw
        string template = _resourceLoader.GetString("ErrorFileNotFound");
        return string.Format(template, fileName);
    }
}
```

For strings with format placeholders, define the `.resw` value with `{0}`, `{1}`, etc.:

| Name | Value |
|---|---|
| `ErrorFileNotFound` | The file "{0}" could not be found. |
| `ItemCount` | {0} items selected |

```csharp
string message = string.Format(_resourceLoader.GetString("ItemCount"), count);
```

### Culture-Aware Formatting

Format dates, numbers, and currencies using `CultureInfo.CurrentCulture` — never hard-code formats like `MM/dd/yyyy` or assume decimal separators.

```csharp
using System.Globalization;

// GOOD — respects user's regional settings
string date = DateTime.Now.ToString("d", CultureInfo.CurrentCulture);    // "3/10/2026" or "10.03.2026"
string price = cost.ToString("C", CultureInfo.CurrentCulture);           // "$9.99" or "9,99 €"
string number = value.ToString("N2", CultureInfo.CurrentCulture);        // "1,234.56" or "1.234,56"

// BAD — assumes US format
string date = DateTime.Now.ToString("MM/dd/yyyy");   // wrong for most locales
string price = $"${cost:F2}";                         // wrong currency symbol
```

### RTL Layout Support

Support right-to-left (RTL) languages (Arabic, Hebrew) by setting `FlowDirection` at the root level so it cascades to all children:

```xml
<Grid FlowDirection="{x:Bind ViewModel.AppFlowDirection, Mode=OneTime}">
    <!-- All child controls inherit the flow direction -->
</Grid>
```

Avoid hard-coding `Margin` or `Padding` that assumes LTR layout. Use symmetric spacing or `Start`/`End` alignment instead of `Left`/`Right`.

### Pluralization Handling

Different languages have different pluralization rules. Use separate resource keys per plural form:

| Name | Value |
|---|---|
| `ItemCount_One` | {0} item |
| `ItemCount_Other` | {0} items |

```csharp
string key = count == 1 ? "ItemCount_One" : "ItemCount_Other";
string message = string.Format(_resourceLoader.GetString(key), count);
```

### Testing Localization

Test localization by overriding the app language at startup without changing the OS locale:

```csharp
// In App.xaml.cs — set before any UI loads
Windows.Globalization.ApplicationLanguages.PrimaryLanguageOverride = "de-de";
```

---

## Anti-patterns

- ❌ **Hard-coded strings** in XAML (`Content="Save"`) or C# (`MessageBox("Error")`) — always use `.resw` and `x:Uid` or `ResourceLoader`.
- ❌ **String concatenation for localized text** (`"Hello, " + name + "!"`) — use format placeholders (`"Hello, {0}!"`) so translators can reorder.
- ❌ **Hard-coded date/number formats** (`ToString("MM/dd/yyyy")`) — use `CultureInfo.CurrentCulture`.
- ❌ **Fixed-width UI elements** that clip translated text — use auto-sizing or `MinWidth`/`MaxWidth` and test with longer locales (e.g., German).
- ❌ **Assuming LTR layout** — hard-coded `Left`/`Right` margins break RTL languages. Use symmetric spacing.
- ❌ **Single string for all plural forms** (`"{0} item(s)"`) — different languages have different plural rules.
- ❌ **Using images with embedded text** — text in images can't be localized. Use overlaid `TextBlock` elements instead.

---

## Validation

- Build & register the MSIX package — see **Build, Run & Deploy** in `Agents.md`.
- Check for hard-coded strings: search `Content="` and `Text="` in `.xaml` files — replace with `x:Uid`.
- Check for hard-coded format strings in `.cs` files.

### Verification Checklist

- [ ] All user-facing strings are in `.resw` resource files
- [ ] XAML controls use `x:Uid` — no hard-coded `Content`, `Text`, `Header`, or `PlaceholderText`
- [ ] Code-behind uses `ResourceLoader.GetString()` for dynamic strings
- [ ] Dates, numbers, and currencies use `CultureInfo.CurrentCulture` formatting
- [ ] Format placeholders (`{0}`, `{1}`) are used instead of string concatenation
- [ ] UI accommodates text expansion without clipping (test with German or Finnish)
- [ ] RTL layout is supported via `FlowDirection` for Arabic/Hebrew locales
- [ ] Pluralization uses separate resource keys per plural form
- [ ] App can be tested by setting `ApplicationLanguages.PrimaryLanguageOverride`

---

## Must Read & Research

> **Agent Rule:** Before any localization-related change, you **must** fetch and review these references using `fetch_webpage`. Apply what you learn.

| # | Reference | When to consult |
|---|---|---|
| 1 | [Globalize your WinUI app](https://learn.microsoft.com/en-us/windows/apps/design/globalizing/guidelines-and-checklist-for-globalizing-your-app) | Adding any new user-facing strings or culture-aware formatting |
| 2 | [Resource Management System](https://learn.microsoft.com/en-us/windows/apps/windows-app-sdk/mrtcore/localize-strings) | Setting up or modifying `.resw` files and `ResourceLoader` usage |
| 3 | [WinUI Localization with x:Uid](https://learn.microsoft.com/en-us/windows/apps/develop/ui-input/localizing-strings) | Binding XAML controls to localized resources via `x:Uid` |
| 4 | [Adjust layout for RTL](https://learn.microsoft.com/en-us/windows/apps/design/globalizing/adjust-layout-and-fonts--and-support-rtl) | Supporting right-to-left languages and mirrored layouts |
