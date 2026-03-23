---
name: create-app
description: Creates a new WinUI 3 C# desktop application from scratch using dotnet new winui. Use when asked to create a new app, start a new project, scaffold a WinUI 3 application, or make a Windows desktop app. Use when the user wants to start a new project, build something from scratch, create a new Windows app, or scaffold a new application.
---

# Workflow: Create a New WinUI 3 C# App

**Trigger:** User wants to create a new WinUI 3 desktop application.

## When to Use This Skill

- User says "create a new app", "start a new project", "scaffold a WinUI 3 app"
- No existing project in workspace, or user wants a fresh project
- User describes an app idea and expects a working starting point

## Steps (add to TODO list)

### Step 1: Check Prerequisites

Follow the instructions in [check-env skill](../check-env/SKILL.md) to verify the development environment.

### Step 2: Gather App Metadata

Follow the instructions in [collect-app-info skill](../collect-app-info/SKILL.md) to collect:
- App display name
- Publisher name
- App description
- Target directory

### Step 3: Create the Project

Use the WinUI dotnet template. The `-n` flag creates the subfolder — do **NOT** `mkdir` first:

```powershell
dotnet new winui -n <AppName>
Set-Location <AppName>
```

### Step 5: Build and Run

```powershell
# Build and run (use arch that matches the machine -- x64 or Arm64, tfm is typically net10.0-windows10.0.26100.0 but check your project file to confirm)
dotnet build <path-to-project.csproj> -c Debug -p:Platform=(arch)
winapp run bin\(arch)\(tfm)\win-(arch)\
```

### Step 6: Verify

After launch, verify the app is running:

```bash
winapp ui status -a <pid/appname>
winapp ui screenshot -a <pid/appname>
```

### Step 7: Ready for Features

After successful build, check whether the user's original request includes feature requirements.

**If the user described any features, IMMEDIATELY proceed to [add-feature skill](../add-feature/SKILL.md).** Do NOT implement features inline — the add-feature workflow ensures specs and samples are searched first, which prevents incorrect API usage.

> **Tip:** The WinUI template creates a `.github/instructions/` folder inside the app with WinUI 3 development best practices. Read these — they complement the skills available to you.

---

## Key Rules

1. **Template name is `winui`, NOT `winui3`** — use `dotnet new winui -n <AppName>`
2. **`-n` creates the subfolder** — do NOT `mkdir` first
3. **Preserve template-generated files** — the template creates MainWindow.xaml with TitleBar, SystemBackdrop, and layout. Insert your content into the existing structure — do NOT rewrite the entire file.

---

## Success Criteria

1. Prerequisites verified via check-env skill
2. App metadata collected (name, publisher, description)
3. Project created with `dotnet new winui`
5. Initial build successful with `dotnet build <path-to-project.csproj> -c Debug -p:Platform=(arch)
6. App runs successfully with `winapp run bin\(arch)\(tfm)\win-(arch)\`
6. App verified running via `winapp ui` commands