---
name: security
description: 'Security requirements for WinUI 3 apps — secrets management, input validation, permissions, and secure coding. Use when handling credentials, network calls, or user input.'
---

# Security

These rules apply to **every feature and change**. They are not optional add-ons.

---

## Quick Reference

1. **Never hard-code secrets** — use `PasswordVault`, environment variables, or Azure Key Vault.
2. **Validate all external input** — user input, file content, and network responses.
3. **Least privilege** — request only the capabilities your app needs in `Package.appxmanifest`.
4. **HTTPS only** — enforce TLS and never disable certificate validation.
5. **Sign MSIX packages** — enable code signing for all published builds.

---

## Rules

### Secrets Management with PasswordVault

Use the Windows **Credential Locker** (`PasswordVault`) to store secrets such as tokens and passwords. Credentials are encrypted per-user, per-app and never leave the device unencrypted.

```csharp
using Windows.Security.Credentials;

// Store a credential
var vault = new PasswordVault();
vault.Add(new PasswordCredential("MyApp", username, accessToken));

// Retrieve a credential
var credential = vault.Retrieve("MyApp", username);
credential.RetrievePassword();
string token = credential.Password;

// Remove when no longer needed (e.g., sign-out)
vault.Remove(credential);
```

For encrypting arbitrary data at rest (e.g., local cache files), use **DPAPI** via `DataProtectionProvider`:

```csharp
using Windows.Security.Cryptography.DataProtection;
using Windows.Storage.Streams;

// Encrypt
var provider = new DataProtectionProvider("LOCAL=user");
IBuffer encrypted = await provider.ProtectAsync(dataBuffer);

// Decrypt
var unprotectProvider = new DataProtectionProvider();
IBuffer decrypted = await unprotectProvider.UnprotectAsync(encrypted);
```

### Package Identity and Secure Storage

Packaged WinUI 3 apps run inside an MSIX container with their own isolated `ApplicationData` storage. Use `ApplicationData.Current.LocalFolder` for app-private files — these are sandboxed per package identity and inaccessible to other apps.

Follow the **principle of least privilege** — declare only the capabilities your app needs in `Package.appxmanifest`. Every capability widens the app's attack surface.

### Input Validation

Validate and sanitize all external input before processing. Use XAML input constraints and C# validation together:

```xml
<!-- Constrain input at the UI level -->
<TextBox x:Name="AgeInput"
         InputScope="Number"
         MaxLength="3"
         BeforeTextChanging="AgeInput_BeforeTextChanging" />
```

```csharp
private void AgeInput_BeforeTextChanging(TextBox sender,
    TextBoxBeforeTextChangingEventArgs args)
{
    // Reject non-numeric input
    args.Cancel = !args.NewText.All(char.IsDigit);
}
```

For file paths and process execution, never pass unsanitized user input:

```csharp
// BAD — command injection risk
Process.Start("cmd.exe", $"/c {userInput}");

// GOOD — validate and use typed APIs
if (Path.GetExtension(filePath) == ".txt" && Path.IsPathFullyQualified(filePath))
{
    var content = await File.ReadAllTextAsync(filePath);
}
```

### Secure WebView2 Configuration

When using `WebView2`, restrict content and disable dangerous features:

```csharp
async Task InitializeWebView()
{
    await webView.EnsureCoreWebView2Async();
    var settings = webView.CoreWebView2.Settings;

    // Disable features you don't need
    settings.IsScriptEnabled = false;           // disable if no JS needed
    settings.AreDefaultScriptDialogsEnabled = false;
    settings.IsWebMessageEnabled = false;       // disable if no host↔web messaging
    settings.AreDevToolsEnabled = false;        // disable in production

    // Restrict navigation to allowed origins
    webView.CoreWebView2.NavigationStarting += (s, e) =>
    {
        var uri = new Uri(e.Uri);
        if (uri.Host != "trusted.example.com")
            e.Cancel = true;
    };
}
```

### Network Security

- Always use **HTTPS**. Never disable TLS certificate validation, even during development.
- Use `HttpClient` with default certificate validation — do not override `ServerCertificateCustomValidationCallback` to return `true`.
- Pin certificates for high-security scenarios using a custom `HttpClientHandler`.

```csharp
// BAD — disables all certificate validation
var handler = new HttpClientHandler
{
    ServerCertificateCustomValidationCallback = (msg, cert, chain, errors)
        => true // NEVER do this
};

// GOOD — use default validation (or pin a specific certificate)
var client = new HttpClient(); // default TLS validation
```

### General Practices

- Keep NuGet packages up to date — run `dotnet list package --outdated` regularly.
- Never log sensitive data (PII, tokens, passwords) — scrub before logging.
- Enable code signing for all published MSIX packages.

---

## Anti-patterns

- ❌ **Hard-coded secrets** in source code — API keys, passwords, or connection strings in `.cs` or `appsettings.json` committed to source control.
- ❌ **Storing passwords in `ApplicationData.LocalSettings` without encryption** — use `PasswordVault` or `DataProtectionProvider` instead.
- ❌ **Disabling TLS validation** for debugging and forgetting to re-enable it — never override certificate callbacks to return `true`.
- ❌ **Using `Process.Start` with unsanitized user input** — command injection risk.
- ❌ **Broad `catch (Exception) { }`** that swallows errors silently — always log or rethrow.
- ❌ **Requesting unnecessary capabilities** in `Package.appxmanifest` — each capability widens the attack surface.
- ❌ **Leaving WebView2 defaults enabled in production** — disable DevTools, restrict navigation, and limit script execution.
- ❌ **Using `SecureString` for new code** — it is [not recommended](https://learn.microsoft.com/en-us/dotnet/api/system.security.securestring) in modern .NET. Use `PasswordVault` or DPAPI instead.

---

## Validation

- Build & register the MSIX package — see **Build, Run & Deploy** in `Agents.md`.
- Check for hard-coded secrets: search for `password`, `apikey`, `secret`, `connectionstring` in `.cs` files.
- Run `dotnet list package --outdated` to verify no vulnerable packages.

### Verification Checklist

- [ ] No secrets are hard-coded in source files or config committed to version control
- [ ] Credentials are stored via `PasswordVault` or encrypted with `DataProtectionProvider`
- [ ] All external input (user input, file paths, network data) is validated before use
- [ ] `Package.appxmanifest` declares only required capabilities
- [ ] `HttpClient` uses HTTPS with default TLS certificate validation
- [ ] WebView2 has unnecessary features disabled and navigation restricted to trusted origins
- [ ] MSIX packages are code-signed for distribution
- [ ] No PII, tokens, or passwords appear in log output

---

## Must Read & Research

> **Agent Rule:** Before any security-related change (auth, input handling, permissions, HTTP), you **must** fetch and review these references using `fetch_webpage`. Apply what you learn.

| # | Reference | When to consult |
|---|---|---|
| 1 | [.NET Security Best Practices](https://learn.microsoft.com/en-us/dotnet/standard/security/) | Any code handling credentials, tokens, or sensitive data |
| 2 | [Secure coding guidelines for .NET](https://learn.microsoft.com/en-us/dotnet/standard/security/secure-coding-guidelines) | Input validation, exception handling, type safety |
| 3 | [MSIX Security](https://learn.microsoft.com/en-us/windows/msix/msix-container) | Packaging, signing, or distribution changes |
| 4 | [Package.appxmanifest capabilities](https://learn.microsoft.com/en-us/windows/uwp/packaging/app-capability-declarations) | Adding or modifying app capabilities/permissions |
| 5 | [PasswordVault class](https://learn.microsoft.com/en-us/uwp/api/windows.security.credentials.passwordvault) | Storing or retrieving user credentials |
| 6 | [WebView2 security best practices](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/security) | Configuring WebView2 settings for production |
