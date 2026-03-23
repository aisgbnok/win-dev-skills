---
name: performance
description: 'Performance requirements for WinUI 3 apps — data binding, layout optimization, threading, and collection virtualization. Use when optimizing UI or data loading.'
---

# Performance

These rules apply to **every feature and change**. They are not optional add-ons.

---

## Quick Reference

1. **Use `x:Bind`** — compiled, type-safe, faster than `{Binding}`.
2. **Defer with `x:Load`** — don't pay for UI elements the user hasn't seen yet.
3. **Virtualize lists** — `ListView` or `ItemsRepeater`, never `StackPanel` for large collections.
4. **Keep the UI thread free** — `Task.Run` for CPU work, `async/await` for I/O, `DispatcherQueue` to post back.
5. **Measure before and after** — profile with Visual Studio Diagnostics Tools and PerfView.

---

## Rules

### x:Bind vs {Binding}

Always prefer `x:Bind` (compiled bindings) over `{Binding}` (runtime reflection). `x:Bind` resolves at compile time, generates strongly typed code, and avoids the reflection overhead of `{Binding}`.

| Feature | `x:Bind` | `{Binding}` |
|---|---|---|
| Resolution | Compile-time | Runtime (reflection) |
| Type safety | ✅ Yes | ❌ No |
| Default mode | OneTime | OneWay |
| Performance | Faster | Slower |

Reserve `{Binding}` only where `x:Bind` cannot be used (e.g., `Style` setters).

### Deferred Loading with x:Load

Use `x:Load` to defer creation of UI subtrees that aren't immediately visible (e.g., dialogs, secondary tabs, collapsed panels). The element is created only when `x:Load` evaluates to `true`.

```xml
<!-- The settings panel is not created until the user opens it -->
<StackPanel x:Name="SettingsPanel" x:Load="{x:Bind ViewModel.IsSettingsOpen, Mode=OneWay}">
    <TextBlock Text="Settings content here" />
</StackPanel>
```

### Incremental Rendering with x:Phase

Use `x:Phase` inside `DataTemplate` to prioritize which parts of each list item render first. Phase 0 (default) renders immediately; higher phases render in subsequent passes.

```xml
<DataTemplate x:DataType="vm:ItemViewModel">
    <StackPanel>
        <!-- Phase 0: renders immediately -->
        <TextBlock Text="{x:Bind Title}" />
        <!-- Phase 1: renders after all phase-0 items are visible -->
        <TextBlock Text="{x:Bind Description}" x:Phase="1" />
        <!-- Phase 2: renders last -->
        <Image Source="{x:Bind ThumbnailUrl}" x:Phase="2" />
    </StackPanel>
</DataTemplate>
```

### Collection Virtualization

Use `ListView`, `GridView`, or `ItemsRepeater` for any list that may exceed ~20 items. These controls create UI elements only for visible items and recycle them on scroll.

```xml
<!-- GOOD — ItemsRepeater with virtualizing layout -->
<ScrollViewer>
    <ItemsRepeater ItemsSource="{x:Bind ViewModel.Items}">
        <ItemsRepeater.Layout>
            <StackLayout Spacing="4" />
        </ItemsRepeater.Layout>
    </ItemsRepeater>
</ScrollViewer>
```

```xml
<!-- BAD — StackPanel creates all 1000 items at once -->
<ScrollViewer>
    <StackPanel>
        <!-- ItemTemplate applied via code for each of 1000 items — no virtualization -->
    </StackPanel>
</ScrollViewer>
```

For large datasets, also implement `ISupportIncrementalLoading` so the `ListView` fetches pages of data as the user scrolls.

### DispatcherQueue for UI-Thread Management

Use `DispatcherQueue.TryEnqueue` to marshal calls back to the UI thread from background threads. Never access UI elements from a non-UI thread.

```csharp
// GOOD — update UI from background work
public async Task LoadDataAsync()
{
    var data = await Task.Run(() => _service.GetExpensiveData());

    DispatcherQueue.TryEnqueue(() =>
    {
        ViewModel.Items.Clear();
        foreach (var item in data)
            ViewModel.Items.Add(item);
    });
}
```

**Do not flood the queue.** Batch updates into a single `TryEnqueue` call rather than enqueuing per item:

```csharp
// BAD — floods the dispatcher with 1000 individual calls
foreach (var item in data)
{
    DispatcherQueue.TryEnqueue(() => ViewModel.Items.Add(item));
}
```

### Async Patterns

- Use `async/await` for I/O-bound work (file access, HTTP calls, database queries).
- Use `Task.Run` for CPU-bound work (parsing, compression, image processing).
- Never block the UI thread with `.Result`, `.Wait()`, or `.GetAwaiter().GetResult()`.

```csharp
// GOOD — async I/O keeps UI responsive
public async Task SaveAsync()
{
    await File.WriteAllTextAsync(path, content);
}

// BAD — blocks the UI thread
public void Save()
{
    File.WriteAllTextAsync(path, content).Result; // DEADLOCK RISK
}
```

### Layout and Visual Tree

- Minimize XAML visual tree depth — deep nesting compounds layout-pass cost.
- Prefer `Grid` over nested `StackPanel` layouts when you need rows and columns.
- Cache expensive computations and HTTP responses when appropriate.

---

## Anti-patterns

- ❌ **Blocking the UI thread** with `.Result`, `.Wait()`, or `.GetAwaiter().GetResult()` — causes freezes or deadlocks.
- ❌ **Using `{Binding}` when `x:Bind` works** — `{Binding}` is slower and fails silently at runtime.
- ❌ **Rendering large lists without virtualization** — `StackPanel` with hundreds of children causes startup lag and high memory use.
- ❌ **Loading all data upfront** when only a subset is needed — use incremental loading or pagination.
- ❌ **Flooding `DispatcherQueue`** with one enqueue per item — batch UI updates into a single call.
- ❌ **Creating new `HttpClient` instances per request** — use `IHttpClientFactory` or a shared static instance.
- ❌ **Using `FindName()` or `VisualTreeHelper` in tight loops** — these are expensive tree traversals.
- ❌ **Skipping `x:Phase`** on complex list item templates — users see a blank list while all phases render at once.

---

## Validation

- Build & register the MSIX package — see **Build, Run & Deploy** in `Agents.md`.
- Profile the app with Visual Studio Diagnostics Tools — check for UI thread blocking and excessive allocations.

### Verification Checklist

- [ ] No blocking calls (`.Result`, `.Wait()`) on the UI thread
- [ ] All data bindings use `x:Bind` (not `{Binding}`) where possible
- [ ] Large or dynamic lists use `ListView`, `GridView`, or `ItemsRepeater` with virtualizing layout
- [ ] `x:Load` is used for UI elements not immediately visible
- [ ] Complex `DataTemplate` items use `x:Phase` for incremental rendering
- [ ] Background-to-UI updates use `DispatcherQueue.TryEnqueue` with batched operations
- [ ] `HttpClient` is shared or obtained from `IHttpClientFactory`
- [ ] Visual tree depth is minimized — no unnecessary nesting

---

## Must Read & Research

> **Agent Rule:** Before any performance-sensitive change (data binding, layout, collections, async), you **must** fetch and review these references using `fetch_webpage`. Apply what you learn.

| # | Reference | When to consult |
|---|---|---|
| 1 | [Performance best practices for WinUI 3](https://learn.microsoft.com/en-us/windows/apps/performance/) | Any change touching UI rendering, data loading, or threading |
| 2 | [x:Bind markup extension](https://learn.microsoft.com/en-us/windows/uwp/xaml-platform/x-bind-markup-extension) | Adding or modifying XAML data bindings |
| 3 | [x:Load attribute](https://learn.microsoft.com/en-us/windows/uwp/xaml-platform/x-load-attribute) | Deferring UI element loading |
| 4 | [Optimize XAML layout](https://learn.microsoft.com/en-us/windows/apps/performance/optimize-xaml-layout) | Restructuring XAML panels, reducing visual tree depth |
| 5 | [ListView optimization](https://learn.microsoft.com/en-us/windows/apps/performance/optimize-listview) | Working with lists, collections, or `ItemsRepeater` |
