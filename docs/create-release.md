# Building a release (maintainers)

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

1. Create a new subfolder with the skill name in the `.github/plugin/skills/winui3` folder.
2. Add a new markdown file named `SKILL.md` as the only file in that new subdirectory.
3. The Skill markdown file should be prefaced with YAML frontmatter that has the `name:` of the skill and a `description:` that includes both technical terms and natural-language user intents for better routing.
4. Follow the standard skill structure:

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

5. **For large skills (>8 KB):** Use a `references/` subdirectory to store detailed content. Keep `SKILL.md` compact (~4-5 KB) with quick-reference tables and an overview, and put detailed docs in `references/*.md` that the agent loads only when needed. See `wpf-migration` for an example of this pattern.
6. **Quality bar:** Every skill should have at minimum a Quick Reference section, at least 3 rules with code examples, an Anti-Patterns section, and a Validation Checklist.
7. **For orchestration:** If the skill is used by a specialist agent in the orchestration pipeline, update the relevant knowledge bundle in `skills/winui3/orchestration/references/` and the inline-vs-link table in `agents/winui3.agent.md`.
