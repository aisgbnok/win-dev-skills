---
name: fluent-design
description: 'Fluent Design System for WinUI 3 apps — type ramp, spacing, colors, iconography, materials, corner radius, and motion. Use when designing UI layouts, choosing controls, or applying visual polish.'
---

## Quick Reference

- **Use built-in `TextBlockStyle` resources** — never hardcode `FontSize` or `FontWeight`. Use `SubtitleTextBlockStyle`, `BodyTextBlockStyle`, etc.
- **All spacing must be multiples of 4px** — Margin, Padding, Spacing values on the 4px grid (4, 8, 12, 16, 24, 36, 48).
- **Never hardcode colors** — use `{ThemeResource}` brushes (e.g., `TextFillColorPrimaryBrush`, `CardBackgroundFillColorDefaultBrush`) for Light/Dark/High Contrast support.
- **Use `ControlCornerRadius` (4px) or `OverlayCornerRadius` (8px)** — never hardcode `CornerRadius` values.
- **Use `MicaBackdrop` for main window, `DesktopAcrylicBackdrop` for transient surfaces** — materials fall back to solid color automatically.

---

# Fluent Design

These rules apply to **every feature and change**. They are not optional add-ons.

---

## Rules

### Typography

- Use **built-in `TextBlockStyle` resources** (`SubtitleTextBlockStyle`, `BodyTextBlockStyle`, `CaptionTextBlockStyle`, etc.).
- The type ramp uses **Segoe UI Variable** and scales across displays.
- **Minimum readable size:** 12px.

### Spacing

- All spacing values must be **multiples of 4px** (4, 8, 12, 16, 24, 36, 48).
- Common values: 8px between controls, 16px card padding, 24px section spacing, 36px page margins.

For the complete type ramp and spacing grid, see [Typography and Spacing](./references/typography-and-spacing.md).

### Colors

- Always use `{ThemeResource}` brushes for Light/Dark/High Contrast support.
- Key text brushes: `TextFillColorPrimaryBrush`, `TextFillColorSecondaryBrush`, `AccentTextFillColorPrimaryBrush`.
- Key background brushes: `CardBackgroundFillColorDefaultBrush`, `LayerFillColorDefaultBrush`.

### Materials

- **Mica** (`MicaBackdrop`) — main window background; samples desktop wallpaper.
- **Acrylic** (`DesktopAcrylicBackdrop`) — transient surfaces (flyouts, menus, sidebars).
- Materials fall back to solid color on unsupported systems automatically.

For all color token tables and material configuration details, see [Colors and Materials](./references/colors-and-materials.md).

### Iconography

- Use `SymbolIcon` for standard icons, `FontIcon` with `SymbolThemeFontFamily` for specific glyphs.
- Standard sizes: 16px (compact), 20px (default), 24px (emphasis), 32px (large), 48px (hero).
- Avoid custom icon fonts or PNGs for standard platform actions.

### Corner Radius

- Use `ControlCornerRadius` (4px) for in-page controls, `OverlayCornerRadius` (8px) for top-level containers.
- Never hardcode `CornerRadius` values — always use theme resources.

For icon type reference, corner radius details, and motion/transition examples, see [Iconography and Motion](./references/iconography-and-motion.md).

### Motion & Transitions

- Use built-in theme transitions (`ScalarTransition`, `NavigationThemeTransition`) — they respect "reduce motion" settings.
- Use connected animations for list-to-detail page transitions.
- Use composition animations (via **composition-graphics** skill) only when built-in transitions are insufficient.

---

## Anti-patterns

- **Hardcoded font properties** (`FontSize="20"`) → use `TextBlockStyle` resources
- **Non-grid spacing** (`Margin="15"`, `Padding="10"`) → use multiples of 4px
- **Hardcoded colors** (`Background="#FFFFFF"`) → use `{ThemeResource}` brushes
- **Hardcoded corner radius** (`CornerRadius="6"`) → use `ControlCornerRadius` or `OverlayCornerRadius`
- **Custom icon fonts** for standard actions → use `SymbolIcon` or `FontIcon`
- **Storyboard** for simple property changes → use `ScalarTransition`
- **Custom window background** → use `MicaBackdrop` or `DesktopAcrylicBackdrop`

---

## Validation

- [ ] Text uses `TextBlockStyle` resources — no hardcoded `FontSize`/`FontWeight`
- [ ] Spacing values are multiples of 4px — search XAML for odd values
- [ ] Colors use `{ThemeResource}` brushes — search for `="#` to find violations
- [ ] Icons use `SymbolIcon`/`FontIcon` with `SymbolThemeFontFamily`
- [ ] `CornerRadius` uses `ControlCornerRadius` (4px) or `OverlayCornerRadius` (8px)
- [ ] Window uses `MicaBackdrop` or `DesktopAcrylicBackdrop`
- [ ] UI renders correctly in Light, Dark, and High Contrast themes

---

## Must Read & Research

> **Agent Rule:** Before designing any UI layout, choosing colors, or applying visual polish, you **must** fetch and review these references using `fetch_webpage`. Apply what you learn.

| Reference | When to consult |
|---|---|
| [WinUI 3 Gallery](https://github.com/microsoft/WinUI-Gallery) | Any visual design decision |
| [Typography](https://learn.microsoft.com/windows/apps/design/style/typography) | Text styles, font sizes, type hierarchy |
| [Spacing and sizes](https://learn.microsoft.com/windows/apps/design/style/spacing) | Margins, padding, layout spacing |
| [Color](https://learn.microsoft.com/windows/apps/design/style/color) | Theme resources, accent colors |
| [Segoe Fluent Icons](https://learn.microsoft.com/windows/apps/design/style/segoe-fluent-icons-font) | Icon glyphs for FontIcon |
| [Materials (Mica)](https://learn.microsoft.com/windows/apps/design/style/mica) | Mica or Acrylic backdrops |
| [Rounded corners](https://learn.microsoft.com/windows/apps/design/style/rounded-corner) | Corner radius values |
