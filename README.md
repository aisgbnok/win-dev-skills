# Windows Development Skills

Copilot CLI skills and agents for Windows app development.

> [!IMPORTANT]
> :warning: **Note:** The install script and release bundling are **temporary**. WinApp CLI is currently in preview. For public facing skills, the agents will handle tool installation automatically — no script needed, and the plugin will be installable directly from the Copilot CLI.

## What's in this repo

- **`.github/plugin/`** — Copilot CLI plugin with agents and skills for Windows development
  - **winapp** agent — App packaging, code signing, Windows SDK, package identity, UI automation (Electron, .NET, C++, Rust, Flutter, Tauri)
  - **winui3-builder** agent — WinUI 3 app development with live UI verification
  - 20 skills organized as thin rule sets with `references/` for detailed patterns
- **`scripts/install.ps1` / `scripts/install.cmd`** — User installer (temporary, see below)
- **`scripts/build-release.ps1`** — Maintainer script to bundle artifacts and publish releases

## Quick start

1. Download the latest release from [Releases](https://github.com/microsoft/win-dev-skills/releases)
2. Extract the zip
3. Double-click `install.cmd`
4. When prompted, confirm the installation

The installer will:
- Install **WinApp CLI** as a portable executable (no internet or admin required)
- Install **WinUI 3 project templates** from NuGet.org (requires .NET SDK)
- Install the **Copilot CLI plugin** with Windows development agents and skills

After installation, open a terminal and run:

```
copilot
```

Then ask something like:

```
Build me a WinUI 3 app called TaskFlow
```

## Building a release (maintainers)

The `build-release.ps1` script bundles local WinApp CLI artifacts with the plugin and publishes to GitHub Releases.

### Prerequisites

- [GitHub CLI](https://cli.github.com/) (`gh`) installed and authenticated (only needed for publishing)
- Local WinApp CLI build artifacts (the `artifacts/` folder from a winappCli build)

### Usage

```powershell
# Bundle from local artifacts (creates zip, no publish)
.\scripts\build-release.ps1 -ArtifactsPath E:\winappcli2\artifacts

# Explicit version
.\scripts\build-release.ps1 -ArtifactsPath .\artifacts -Version "0.3.0"

# Bundle and publish to GitHub Releases
.\scripts\build-release.ps1 -ArtifactsPath .\artifacts -Publish
```

The script will:
1. Validate WinApp CLI artifacts exist (win-x64 and/or win-arm64)
2. Copy WinApp CLI portable executables + required DLLs
3. Bundle with the plugin and install scripts into a zip
4. Optionally publish to GitHub Releases (with `-Publish`)

## Contributing

This project welcomes contributions and suggestions. Please see [SECURITY.md](SECURITY.md) for security policies.

### Adding a new Skill

1. Add a row to the Skill table in the `.github\plugin\agents\winui3-builder.agent.md` markdown file under the appropriate category group.
  - The first column is the _Name_ of the skill, this should be bolded (surrounded in `**` on both sides)
  - The second column is a description of when the skill should be used, including natural-language user intents (e.g., "Use when the user wants to...")
2. Create a new subfolder with the same **name** as the name of your new skill in the `.github/plugin/skills/winui3` folder.
3. Add a new markdown file named `SKILL.md` as the only file in that new subdirectory.
4. The Skill markdown file should be prefaced with YAML frontmatter that has the `name:` of the skill and a `description:` that includes both technical terms and natural-language user intents for better routing.
5. Follow the standard skill structure:

```markdown
## Quick Reference
- 3-5 most critical, actionable rules (always read first)
---
# Skill Title
## Detailed Rules
- Full rules with code examples
## Anti-Patterns
- Common mistakes to avoid
## Validation Checklist
- [ ] Verification steps before completing
```

6. **For large skills (>8 KB):** Use a `references/` subdirectory to store detailed content. Keep `SKILL.md` compact (~4-5 KB) with quick-reference tables and an overview, and put detailed docs in `references/*.md` that the agent loads only when needed. See `wpf-to-winui3` for an example of this pattern.
7. **Quality bar:** Every skill should have at minimum a Quick Reference section, at least 3 rules with code examples, an Anti-Patterns section, and a Validation Checklist.
