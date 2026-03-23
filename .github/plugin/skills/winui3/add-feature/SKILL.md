---
name: add-feature
description: Complete workflow for adding new functionality to an existing WinUI 3 C# app. Use when asked to add a feature, implement a control, integrate an API, add a button, create a new page, or extend app capabilities. Guides through mandatory spec and sample searching, implementation, and build verification. Use when the user wants to add something to their app, implement new functionality, add a button, create a new page, or extend their application.
---

# Workflow: Add New Feature to a WinUI 3 App

**Trigger:** User wants to add new functionality to an existing WinUI 3 C# application.

## When to Use This Skill

- User wants to add new functionality to an existing WinUI 3 app
- User says "add a button", "implement X feature", "integrate an API", "create a new page"
- An existing WinUI 3 C# project is open in workspace
- User describes specific features to build on top of a working app

## Steps (must be added to TODO list)

### Step 1: Check Prerequisites

Follow the instructions in [check-env skill](../check-env/SKILL.md) if not already done.

### Step 2: Get App Context

Identify the project folder and app name. If unknown, look for a `.csproj` file that references `Microsoft.WindowsAppSDK`.

### Step 3: Identify SDK Version

Identify the release branch based on the project's WindowsAppSDK NuGet package version (e.g., `1.7`, `1.8`, `2.0`).

### Step 4: Break Down Implementation

Outline specific implementation steps based on the feature request.

### Step 5: Implement Each Step

For each implementation step:

#### 5.1 MANDATORY — Search Specs

⚠️ **DO NOT write any feature code before completing this step.**

Follow the instructions in [search-docs skill](../search-docs/SKILL.md) with category `WindowsAppSDK-specs` to find API specifications.

#### 5.2 If AI-related Feature

Follow the instructions in [search-docs skill](../search-docs/SKILL.md) with category `Windows-AI-Docs` for AI/ML guidance.

#### 5.3 MANDATORY — Search Samples

⚠️ **DO NOT write any feature code before completing this step.**

Follow the instructions in [search-docs skill](../search-docs/SKILL.md) with category `WindowsAppSDK-Samples` for code examples. Official samples contain proven patterns and correct API usage.

#### 5.4 Implement the Feature

Implement the feature based on the specs and samples found. Follow the patterns in [winui-best-practices](../winui-best-practices/SKILL.md) for MVVM, XAML, and architecture guidance.

### Step 6: Build and Verify

```powershell
# Build and run (use arch that matches the machine -- x64 or Arm64, tfm is typically net10.0-windows10.0.26100.0 but check your project file to confirm)
dotnet build <path-to-project.csproj> -c Debug -p:Platform=(arch)
winapp run bin\(arch)\(tfm))\win-(arch)\
```

After launch, use `winapp ui` to verify the feature works:

```bash
winapp ui status -a <pid/appname>
winapp ui inspect -d 3 <selector> -a <pid/appname>

# always delete screenshots after use to prevent bloating the working directory
winapp ui screenshot -a <pid/appname>
```

### Step 7: Log Feedback

If **anything** went wrong during implementation (build error, retry, workaround, unexpected behavior), append an entry to `FEEDBACK.md` immediately.

---

## Success Criteria

1. Prerequisites verified
2. Specs and samples searched for relevant API patterns
3. Feature implemented following WinUI 3 best practices (MVVM, proper XAML patterns)
4. Build successful with no errors
5. Feature verified visually with `winapp ui screenshot`
