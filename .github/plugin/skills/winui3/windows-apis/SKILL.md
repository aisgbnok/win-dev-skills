---
name: windows-apis
description: 'Find and explore Windows desktop APIs using local WinMD metadata search and online documentation. Use when building features that need platform capabilities — camera, file access, notifications, UI controls, AI/ML, sensors, networking, etc. Discovers the right API for a task and retrieves full type details (methods, properties, events, enumeration values). Also use before implementing any Windows platform API to find samples and verify the correct API surface.'
---

## Quick Reference

- **Sample-first rule** — Before implementing any Windows API, search for an official sample. Use the API only after reading a working example.
- **Search WinMD cache first** — Use `winapp api search "<keyword>"` to find the right API by capability, then `winapp api members "<TypeName>"` for full signatures.
- **Translate user language to API terms** — Map natural descriptions ("take a picture") to technical keywords (camera, capture, MediaCapture) and try multiple variations.
- **Check both SDK surfaces** — `Windows.*` (Platform SDK, always available) and `Microsoft.*` (WinAppSDK, for WinUI/windowing/notifications).
- **Look up docs for context** — WinMD cache has signatures only. For explanations, examples, and remarks, check Microsoft Learn.

---

# Windows API Discovery

This skill helps you find the right Windows API for any capability and get its full details.

## API Surfaces

| Namespace prefix | What it covers | Documentation |
|-----------------|----------------|---------------|
| `Windows.*` | Platform SDK — WinRT APIs for camera, sensors, notifications, storage, networking, AI/ML | [learn.microsoft.com/uwp/api/](https://learn.microsoft.com/uwp/api/) |
| `Microsoft.UI.*` | WinUI 3 controls, windowing, composition, input | [learn.microsoft.com/windows/windows-app-sdk/api/winrt/](https://learn.microsoft.com/windows/windows-app-sdk/api/winrt/) |
| `Microsoft.Windows.*` | WinAppSDK extensions — AppLifecycle, Widgets, PushNotifications | Same as above |

## How to Find the Right API

### Step 1: Translate user language → search keywords

| User says | Keywords to try |
|-----------|----------------|
| "take a picture" | camera, capture, photo, MediaCapture |
| "send a notification" | notification, toast, AppNotification |
| "save settings" | settings, ApplicationData, LocalSettings |
| "pick a file" | file, picker, FileOpenPicker, StorageFile |
| "detect location" | location, geolocation, Geolocator |
| "use Bluetooth" | bluetooth, BluetoothLE, DeviceWatcher |
| "AI/ML inference" | MachineLearning, LearningModel, WindowsAI |
| "drag and drop" | drag, drop, DragDrop, DataPackage |
| "background work" | BackgroundTask, ExtendedExecution |
| "share content" | ShareTarget, DataTransferManager |

### Step 2: Search for the API

```powershell
# Search by capability keyword
winapp api search "<keyword>"

# List types in a namespace
winapp api types "<Namespace>"

# Get all members of a type
winapp api members "<FullTypeName>"

# Get enum values
winapp api enums "<FullTypeName>"
```

If `winapp api` is not available, fall back to online search:
- Platform SDK: search `site:learn.microsoft.com/uwp/api <keywords>`
- WinAppSDK: search `site:learn.microsoft.com/windows/windows-app-sdk/api/winrt <keywords>`

### Step 3: Look up documentation

| Namespace prefix | URL pattern |
|-----------------|-------------|
| `Windows.*` | `https://learn.microsoft.com/uwp/api/{fully.qualified.typename}` |
| `Microsoft.*` | `https://learn.microsoft.com/windows/windows-app-sdk/api/winrt/{fully.qualified.typename}` |

### Step 4: Find official samples

Before writing code, check for samples:
- [Windows App SDK Samples](https://github.com/microsoft/WindowsAppSDK-Samples)
- [Windows Universal Samples](https://github.com/microsoft/Windows-universal-samples)
- [WinUI 3 Gallery](https://github.com/microsoft/WinUI-Gallery)

## Common API Patterns

### Notifications (Toast)
```csharp
// Requires: Microsoft.Windows.AppNotifications
AppNotificationManager.Default.Register();
var builder = new AppNotificationBuilder()
    .AddText("Title")
    .AddText("Body");
AppNotificationManager.Default.Show(builder.BuildNotification());
```

### File Picker (Desktop)
```csharp
// Requires: InitializeWithWindow for desktop apps
var picker = new FileOpenPicker();
var hwnd = WinRT.Interop.WindowNative.GetWindowHandle(this);
WinRT.Interop.InitializeWithWindow.Initialize(picker, hwnd);
picker.FileTypeFilter.Add(".txt");
var file = await picker.PickSingleFileAsync();
```

### Geolocation
```csharp
var access = await Geolocator.RequestAccessAsync();
if (access == GeolocationAccessStatus.Allowed)
{
    var locator = new Geolocator();
    var position = await locator.GetGeopositionAsync();
    var lat = position.Coordinate.Point.Position.Latitude;
}
```

### Background Task Registration
```csharp
// Requires package identity (use winapp run or create-debug-identity)
var builder = new BackgroundTaskBuilder();
builder.Name = "MyTask";
builder.SetTrigger(new TimeTrigger(15, false));
builder.Register();
```

## Anti-Patterns

- ❌ Using an API without checking a sample first — leads to incorrect usage patterns
- ❌ Assuming UWP samples work directly in WinUI 3 — check for namespace and API differences
- ❌ Forgetting `InitializeWithWindow` for pickers/dialogs in desktop apps — causes runtime exceptions
- ❌ Using identity-requiring APIs without registering identity — use `winapp run` or `create-debug-identity` first
- ❌ Hardcoding namespace URLs — use the pattern table above to construct correct documentation links

## Validation Checklist

- [ ] Searched for and reviewed an official sample before implementing
- [ ] Verified the API exists in the target SDK version
- [ ] Added required capabilities to appxmanifest.xml if needed
- [ ] Used `InitializeWithWindow` for any picker or dialog in desktop context
- [ ] Registered package identity if using identity-requiring APIs
- [ ] Tested on both x64 and Arm64 if using platform-specific APIs