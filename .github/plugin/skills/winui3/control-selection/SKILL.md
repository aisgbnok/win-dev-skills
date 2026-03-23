---
name: control-selection
description: 'Decision trees for choosing the right WinUI 3 controls, layout panels, data loading patterns, and navigation approaches. Use when deciding which control to use, which layout panel fits, how to handle large data sets, or which navigation pattern to implement.'
---

# WinUI 3 Control Selection Guide

## Quick Reference

1. **Layout** — Use `StackPanel` for simple stacking, `Grid` for precise row/column placement.
2. **Lists** — `ListView` handles virtualization automatically; only reach for `ItemsRepeater` when you need a custom layout.
3. **Input** — Match the control to the data type (`NumberBox` for numbers, `AutoSuggestBox` for search, `CalendarDatePicker` for dates).
4. **Navigation** — `NavigationView` is the default for 3+ sections; use `TabView` for peer content.
5. **Dialogs** — `ContentDialog` for blocking decisions, `InfoBar` for non-blocking status, `TeachingTip` for onboarding.

---

## 1. Layout Panel Selection

```
What kind of layout?
├─ Items in a row or column
│  └─ StackPanel (Orientation, Spacing="8")
├─ Items in a grid with fixed rows/cols
│  └─ Grid (RowDefinitions, ColumnDefinitions)
│     tip: use Auto for content-sized rows, * for proportional
├─ Items that wrap to next line
│  └─ ItemsRepeater + UniformGridLayout
│     alt: WrapPanel from CommunityToolkit
├─ Single item centered
│  └─ Grid with single cell
│     set HorizontalAlignment="Center" VerticalAlignment="Center"
├─ Responsive / adaptive
│  └─ VisualStateManager with AdaptiveTriggers
│     breakpoint example: MinWindowWidth="640", "1008"
├─ Overlapping / absolute positioning
│  └─ Canvas (Canvas.Left, Canvas.Top)
│     alt: Grid with items sharing the same cell
└─ Proportional split (sidebar + content)
   └─ Grid with two columns: ColumnDefinition Width="300" + Width="*"
```

---

## 2. List / Collection Control Selection

```
Displaying a collection?
├─ Vertical list (any size) → ListView (virtualizes automatically)
│  └─ Grouped → ListView + CollectionViewSource (IsSourceGrouped)
├─ Grid / tiles → GridView or ItemsRepeater + UniformGridLayout
├─ Incremental / infinite scroll → ListView + ISupportIncrementalLoading
├─ Tabular data → CommunityToolkit DataGrid
├─ Custom layout → ItemsRepeater + custom Layout subclass
└─ Master-detail → ListView (left) + detail Grid (right)
```

**Key list tips:** Don't wrap `ListView` in `ScrollViewer` (breaks virtualization). Use `x:Bind` over `Binding`. Keep templates shallow (< 20 elements).

---

## 3. Input Control Selection

```
What type of input?
├─ Free text → TextBox (single line) or RichEditBox (multi-line)
├─ Number → NumberBox (Minimum, Maximum, SpinButtonPlacementMode)
├─ Search / autocomplete → AutoSuggestBox
├─ Date → CalendarDatePicker (single) or CalendarView (range)
├─ Time → TimePicker
├─ Boolean on/off → ToggleSwitch (settings) or CheckBox (forms)
├─ Choose one → RadioButtons (2-5 options) or ComboBox (5+)
├─ Choose multiple → ListView SelectionMode="Multiple" or CheckBox group
├─ Color → ColorPicker
├─ File → Button + FileOpenPicker (PickSingleFileAsync)
├─ Range / slider → Slider (StepFrequency)
└─ Password → PasswordBox (PasswordRevealMode)
```

---

## 4. Navigation Pattern Selection

```
App structure?
├─ 3+ top-level sections → NavigationView (Left or Top) + Frame
├─ 2-3 peer sections → TabView with TabViewItems
├─ Linear flow / wizard → Frame with page stack + step indicator
├─ Flat app, one page → Single Page + ScrollViewer
├─ Hub / dashboard → ScrollViewer with sectioned StackPanel
└─ Modal task → ContentDialog with ContentDialogResult
```

**NavigationView tips:** Set `IsBackButtonVisible="Auto"`, place search in `NavigationView.AutoSuggestBox`, use `NavigationViewItem.MenuItems` for nested hierarchy.

---

## 5. Data Loading Pattern Selection

```
How much data and where from?
├─ Local, small (< 1K items) → ObservableCollection<T>, load all
├─ Local, large (1K+) → Virtualized ListView + background thread
├─ Remote API, paged → ISupportIncrementalLoading + HttpClient
├─ Remote API, real-time → DispatcherTimer or WebSocket + DispatcherQueue
├─ Database (SQLite) → EF Core async or sqlite-net
├─ File-based → System.IO async (File.ReadAllTextAsync)
└─ Settings / preferences → ApplicationData.Current.LocalSettings
```

**Key data tip:** Always load on background thread and marshal to UI via `DispatcherQueue.TryEnqueue`. Use `x:Bind` with `IsLoading` property to show `ProgressRing`.

---

## 6. Dialog / Flyout Selection

```
Need user attention?
├─ Blocking decision (OK / Cancel)
│  └─ ContentDialog
│     set XamlRoot = this.XamlRoot (required in WinUI 3)
│     use PrimaryButtonText, SecondaryButtonText, CloseButtonText
│     await ShowAsync() → check ContentDialogResult
├─ Quick action from a button
│  └─ Flyout (single content) or MenuFlyout (menu items)
│     attach with Button.Flyout property
│     Flyout auto-dismisses on outside click
├─ First-run tip / onboarding
│  └─ TeachingTip
│     set Target to the element to highlight
│     use PreferredPlacement, IsLightDismissEnabled
├─ Status message (inline)
│  └─ InfoBar
│     set Severity (Informational, Success, Warning, Error)
│     set IsOpen="True" to show, IsClosable for dismiss
├─ System notification (toast)
│  └─ AppNotification (Windows App SDK)
│     build with AppNotificationBuilder
│     send via AppNotificationManager
├─ Progress / loading
│  ├─ Known duration → ProgressBar (Value, Maximum)
│  └─ Unknown duration → ProgressRing (IsActive="True")
│     alt: ProgressBar IsIndeterminate="True"
└─ Tooltip on hover
   └─ ToolTipService.ToolTip="text"
      or ToolTip element for rich content
```

**WinUI 3 gotcha:** `ContentDialog` requires `XamlRoot = this.Content.XamlRoot` — it will crash without it.

---

## Anti-Patterns

| Wrong Choice | Problem | Use Instead |
|---|---|---|
| `ScrollViewer` wrapping `ListView` | Breaks virtualization — all items render at once | Let `ListView` handle its own scrolling |
| `StackPanel` for 100+ dynamic items | No virtualization, high memory usage | `ListView` or `ItemsRepeater` |
| `TextBox` for number input | No validation, allows non-numeric text | `NumberBox` with min/max constraints |
| `ComboBox` for 2-3 options | Hides options behind a click; slower to use | `RadioButtons` for visible choices |
| `ContentDialog` for status updates | Blocks interaction unnecessarily | `InfoBar` for non-blocking inline status |
| `Popup` for custom dialogs | Missing light-dismiss, accessibility, focus traps | `ContentDialog` or `Flyout` |
| `DispatcherTimer` for UI updates at 60fps | Timer overhead, not frame-synced | `CompositionTarget.Rendering` or animations |
| Nested `Grid` 4+ levels deep | Layout pass is O(n²), hurts performance | Flatten layout, use `ColumnSpan`/`RowSpan` |
| `Binding` with string paths everywhere | Slower reflection-based, no compile-time checks | `x:Bind` for compiled bindings |
| Loading all remote data at once | UI freeze, memory spike on large datasets | `ISupportIncrementalLoading` for paged fetch |
