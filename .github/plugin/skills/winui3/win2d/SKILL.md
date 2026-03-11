---
name: win2d
description: 'Win2D 2D graphics rendering — CanvasControl, drawing, effects, shaders, and performance patterns. Use when implementing custom 2D graphics, charts, or visual effects in WinUI 3.'
---

# Win2D — 2D Graphics for WinUI 3

Win2D is an easy-to-use Windows Runtime API for immediate-mode 2D graphics rendering with GPU acceleration. It wraps Direct2D and integrates with WinUI 3 XAML.

---

## 1. Setup

Add the Win2D NuGet package:

```bash
dotnet add package Microsoft.Graphics.Win2D
```

For custom pixel shaders, also add:

```bash
dotnet add package ComputeSharp.D2D1.WinUI
```

---

## 2. Choosing the right control

Win2D provides three XAML controls. Choose based on your scenario:

| Control | Ease of use | Target use case | Rendering model |
|---------|-------------|-----------------|-----------------|
| **CanvasControl** | Easiest — single `Draw` event | Static or infrequently updated content (charts, diagrams, icons) | On-demand — call `Invalidate()` to trigger redraw |
| **CanvasAnimatedControl** | Moderate — `Update` + `Draw` loop | Continuous animation, games, real-time visualizations | Fixed-timestep game loop with `TargetElapsedTime` |
| **CanvasVirtualControl** | Advanced — region-based invalidation | Very large or infinite canvases (maps, documents) | Only draws visible regions on demand |

### XAML usage

```xml
xmlns:canvas="using:Microsoft.Graphics.Canvas.UI.Xaml"

<!-- Static content -->
<canvas:CanvasControl Draw="OnCanvasDraw" />

<!-- Animated content -->
<canvas:CanvasAnimatedControl Draw="OnAnimatedDraw"
                              Update="OnAnimatedUpdate"
                              TargetElapsedTime="0:0:0.016"
                              IsFixedTimeStep="True" />
```

### WinUI features you must handle manually

Win2D renders directly to a GPU surface, bypassing the XAML visual tree. This means several WinUI features do **not** work automatically:

| Feature | What you lose | What to do |
|---------|--------------|------------|
| **Accessibility** | No `AutomationPeer`, no UIA tree, screen readers cannot see Win2D content | Implement `AutomationPeer` on the hosting control, expose content via UIA properties, or overlay invisible XAML elements for screen reader access |
| **Theming** | No automatic light/dark theme colors | Subscribe to `ActualThemeChanged` on the hosting `FrameworkElement` and re-read theme resources (`Application.Current.Resources`) to update your drawing colors |
| **Hit testing** | No built-in pointer-to-element mapping | Implement coordinate math in `PointerPressed`/`PointerMoved` on the hosting control, mapping pixel positions to your logical objects |
| **High contrast** | Win2D does not respond to system high-contrast settings | Detect high-contrast mode via `AccessibilitySettings.HighContrast` and switch to high-contrast color palettes |

---

## 3. Basic rendering

### Shapes and text

```csharp
private void OnCanvasDraw(CanvasControl sender, CanvasDrawEventArgs args)
{
    var ds = args.DrawingSession;

    // Clear background
    ds.Clear(Colors.White);

    // Draw filled shapes
    ds.FillRectangle(20, 20, 200, 100, Colors.CornflowerBlue);
    ds.FillEllipse(300, 70, 80, 50, Colors.Coral);
    ds.FillRoundedRectangle(420, 20, 150, 100, 12, 12, Colors.MediumSeaGreen);

    // Draw outlines
    ds.DrawRectangle(20, 20, 200, 100, Colors.Navy, 2);
    ds.DrawLine(20, 150, 580, 150, Colors.Gray, 1);

    // Draw text
    ds.DrawText("Hello Win2D", 20, 170, Colors.Black);
}
```

### Using brushes

```csharp
private void OnCanvasDraw(CanvasControl sender, CanvasDrawEventArgs args)
{
    var ds = args.DrawingSession;

    // Linear gradient brush
    using var gradient = new CanvasLinearGradientBrush(sender, Colors.Blue, Colors.Cyan)
    {
        StartPoint = new Vector2(0, 0),
        EndPoint = new Vector2(400, 0)
    };
    ds.FillRectangle(20, 20, 400, 100, gradient);

    // Image brush for textured fills
    // (requires a CanvasBitmap loaded in CreateResources)
    using var imageBrush = new CanvasImageBrush(sender, loadedBitmap)
    {
        ExtendX = CanvasEdgeBehavior.Wrap,
        ExtendY = CanvasEdgeBehavior.Wrap
    };
    ds.FillEllipse(300, 200, 80, 80, imageBrush);
}
```

---

## 4. Lifecycle and CanvasDevice

### CreateResources — load GPU resources

Use the `CreateResources` event to load bitmaps and create GPU-dependent objects. This event fires when the control is first loaded and whenever the device is recovered after a loss:

```csharp
CanvasBitmap? texture;

private void OnCreateResources(CanvasControl sender, CanvasCreateResourcesEventArgs args)
{
    args.TrackAsyncAction(CreateResourcesAsync(sender).AsAsyncAction());
}

private async Task CreateResourcesAsync(CanvasControl sender)
{
    texture = await CanvasBitmap.LoadAsync(sender, new Uri("ms-appx:///Assets/texture.png"));
}
```

### Device lost handling

The GPU device can be lost at any time (driver update, hardware reset, resource exhaustion). Always handle this:

```csharp
public static T RunWithDeviceRecovery<T>(Func<CanvasDevice, T> action)
{
    while (true)
    {
        var device = CanvasDevice.GetSharedDevice();
        try
        {
            return action(device);
        }
        catch (Exception ex) when (device.IsDeviceLost(ex.HResult))
        {
            device.RaiseDeviceLost();
        }
    }
}
```

### Disposal

Win2D controls hold GPU resources and **must** be explicitly cleaned up:

```csharp
private void Page_Unloaded(object sender, RoutedEventArgs e)
{
    canvasControl.RemoveFromVisualTree();
    canvasControl = null;
}
```

---

## 5. Performance patterns

### CanvasTextLayout — cached text measurement

Calling `DrawText` every frame recalculates layout each time. For repeated text, pre-create a `CanvasTextLayout`:

```csharp
private CanvasTextLayout? cachedLayout;

private void OnCreateResources(CanvasControl sender, CanvasCreateResourcesEventArgs args)
{
    var format = new CanvasTextFormat
    {
        FontSize = 24,
        FontFamily = "Segoe UI",
        WordWrapping = CanvasWordWrapping.Wrap
    };
    cachedLayout = new CanvasTextLayout(sender, "Cached text content", format, maxWidth: 400, maxHeight: 200)
    {
        TrimmingGranularity = CanvasTextTrimmingGranularity.Character,
        TrimmingSign = CanvasTrimmingSign.Ellipsis
    };
}

private void OnCanvasDraw(CanvasControl sender, CanvasDrawEventArgs args)
{
    args.DrawingSession.DrawTextLayout(cachedLayout, 20, 20, Colors.Black);
}
```

### CanvasRenderTarget — off-screen caching

Render complex sub-trees once to an off-screen surface, then draw the cached result each frame:

```csharp
private CanvasRenderTarget? cachedScene;

private void RebuildCache(ICanvasResourceCreator creator, float width, float height)
{
    cachedScene?.Dispose();
    cachedScene = new CanvasRenderTarget(creator, width, height);

    using var ds = cachedScene.CreateDrawingSession();
    ds.Clear(Colors.Transparent);
    // draw complex content once...
    ds.FillRectangle(0, 0, width, height, Colors.LightGray);
    ds.DrawText("Cached", 10, 10, Colors.Black);
}

private void OnCanvasDraw(CanvasControl sender, CanvasDrawEventArgs args)
{
    if (cachedScene != null)
        args.DrawingSession.DrawImage(cachedScene);
}
```

### CanvasSpriteBatch — mass rendering

When drawing thousands of identical or similar sprites, use `CanvasSpriteBatch` for a single GPU draw call:

```csharp
private void OnCanvasDraw(CanvasControl sender, CanvasDrawEventArgs args)
{
    using var batch = args.DrawingSession.CreateSpriteBatch(
        CanvasSpriteSortMode.None,
        CanvasImageInterpolation.Linear,
        CanvasSpriteOptions.ClampToSourceRect);

    var sourceRect = new Rect(0, 0, spriteSheet.SizeInPixels.Width, spriteSheet.SizeInPixels.Height);

    for (int i = 0; i < items.Count; i++)
    {
        var item = items[i];
        batch.DrawFromSpriteSheet(
            spriteSheet,
            new Rect(item.X, item.Y, item.Width, item.Height),
            sourceRect,
            new Vector4(item.R / 255f, item.G / 255f, item.B / 255f, item.Opacity));
    }
}
```

---

## 6. Custom shaders with ComputeSharp

Win2D supports custom GPU pixel shaders via the `ComputeSharp.D2D1.WinUI` package. This enables effects beyond the built-in set.

### Writing a CanvasEffect subclass

```csharp
using ComputeSharp;
using ComputeSharp.D2D1;
using ComputeSharp.D2D1.WinUI;
using Microsoft.Graphics.Canvas;

// 1. Define the shader struct
[D2DInputCount(1)]
[D2DInputSimple(0)]
[D2DPixelShaderSource("""
    float4 Execute()
    {
        float4 color = D2D1GetInput(0);
        float gray = dot(color.rgb, float3(0.299, 0.587, 0.114));
        return float4(gray, gray, gray, color.a);
    }
""")]
partial struct GrayscaleShader : ID2D1PixelShader;
```

### Building the effect graph

Chain effects using the `CanvasEffect` base class:

```csharp
public sealed class GrayscaleEffect : CanvasEffect
{
    private static readonly CanvasEffectNode<PixelShaderEffect<GrayscaleShader>> ShaderNode = new();

    private readonly UnPremultiplyEffect unpremultiply = new();
    private readonly PremultiplyEffect premultiply = new();
    private readonly PixelShaderEffect<GrayscaleShader> shader = new();

    public IGraphicsEffectSource? Source { get; set; }

    protected override void BuildEffectGraph(CanvasEffectGraph graph)
    {
        // Chain: source → unpremultiply → shader → premultiply → output
        shader.Sources[0] = unpremultiply;
        premultiply.Source = shader;

        graph.RegisterNode(ShaderNode, shader);
        graph.RegisterOutputNode(premultiply);
    }

    protected override void ConfigureEffectGraph(CanvasEffectGraph graph)
    {
        unpremultiply.Source = Source;
    }
}
```

### Using the effect

```csharp
private void OnCanvasDraw(CanvasControl sender, CanvasDrawEventArgs args)
{
    var effect = new GrayscaleEffect { Source = loadedBitmap };
    args.DrawingSession.DrawImage(effect, 0, 0);
}
```

> **Note:** Always chain through `UnPremultiplyEffect` → shader → `PremultiplyEffect` when working with alpha. Direct2D uses pre-multiplied alpha internally, and shaders that assume straight alpha will produce incorrect blending.

---

## 7. Other interop

### Composition API

Win2D surfaces can be used with `Windows.UI.Composition` for advanced animation and effects outside the canvas:

```csharp
using Microsoft.Graphics.Canvas.UI.Composition;

var compositionDevice = CanvasComposition.CreateCompositionGraphicsDevice(
    compositor, CanvasDevice.GetSharedDevice());

var surface = compositionDevice.CreateDrawingSurface(
    new Size(400, 300), DirectXPixelFormat.B8G8R8A8UIntNormalized, DirectXAlphaMode.Premultiplied);

using (var ds = CanvasComposition.CreateDrawingSession(surface))
{
    ds.Clear(Colors.Transparent);
    ds.FillRectangle(0, 0, 400, 300, Colors.SkyBlue);
}
```

### Printing

Use `CanvasPrintDocument` to render Win2D content to a printer:

```csharp
var printDoc = new CanvasPrintDocument();
printDoc.PrintTaskOptionsChanged += (sender, args) =>
{
    sender.SetPageCount(1);
};
printDoc.Print += (sender, args) =>
{
    using var ds = args.CreateDrawingSession();
    ds.DrawText("Printed from Win2D", 100, 100, Colors.Black);
};
```

### SVG

Load and render vector graphics with `CanvasSvgDocument`:

```csharp
CanvasSvgDocument? svgDoc;

private async Task LoadSvgAsync(ICanvasResourceCreator creator)
{
    var file = await StorageFile.GetFileFromApplicationUriAsync(new Uri("ms-appx:///Assets/icon.svg"));
    using var stream = await file.OpenReadAsync();
    svgDoc = await CanvasSvgDocument.LoadAsync(creator, stream);
}

private void OnCanvasDraw(CanvasControl sender, CanvasDrawEventArgs args)
{
    if (svgDoc != null)
        args.DrawingSession.DrawSvg(svgDoc, new Size(200, 200));
}
```

---

## Common pitfalls

| Mistake | Fix |
|---------|-----|
| Not disposing `CanvasControl` on page unload | Call `RemoveFromVisualTree()` in `Page.Unloaded`; set the control reference to `null` |
| Calling `DrawText` every frame with the same string | Pre-create a `CanvasTextLayout` and call `DrawTextLayout` instead |
| Ignoring device lost exceptions | Wrap device operations with `IsDeviceLost` check and retry after `RaiseDeviceLost` |
| Creating `CanvasRenderTarget` every frame | Create once, cache, and only recreate when size or content changes |
| Forgetting pre-multiplied alpha in custom shaders | Chain through `UnPremultiplyEffect` → shader → `PremultiplyEffect` |
| Drawing thousands of items with individual draw calls | Use `CanvasSpriteBatch` for batch rendering |
| Using Win2D without accessibility fallbacks | Add `AutomationPeer` or overlay invisible XAML elements for screen reader content |
| Not handling theme changes | Subscribe to `ActualThemeChanged` and update drawing colors |

## Verification checklist

- [ ] `Microsoft.Graphics.Win2D` NuGet package is referenced in the project
- [ ] Win2D controls are disposed in the page `Unloaded` event via `RemoveFromVisualTree()`
- [ ] GPU resources (bitmaps, render targets, text layouts) are created in `CreateResources`, not in `Draw`
- [ ] Device lost is handled with retry logic when using `CanvasDevice` directly
- [ ] `CanvasTextLayout` is used instead of `DrawText` for repeated text
- [ ] `CanvasRenderTarget` caching is used for complex sub-trees that don't change every frame
- [ ] Custom shaders use the UnPremultiply → Shader → Premultiply chain for correct alpha
- [ ] Accessibility is addressed: either `AutomationPeer` is implemented or invisible XAML overlays provide screen reader content
- [ ] Theme changes are handled: colors update when light/dark mode switches

## Must read and research

| Resource | Link |
|----------|------|
| Win2D documentation (WinUI 3) | https://microsoft.github.io/Win2D/WinUI3/html/Introduction.htm |
| Win2D GitHub repository | https://github.com/Microsoft/Win2D |
| Win2D samples (WinUI 3) | https://github.com/Microsoft/Win2D-Samples |
| ComputeSharp GitHub | https://github.com/Sergio0694/ComputeSharp |
| CanvasControl reference | https://microsoft.github.io/Win2D/WinUI3/html/T_Microsoft_Graphics_Canvas_UI_Xaml_CanvasControl.htm |
| CanvasAnimatedControl reference | https://microsoft.github.io/Win2D/WinUI3/html/T_Microsoft_Graphics_Canvas_UI_Xaml_CanvasAnimatedControl.htm |
