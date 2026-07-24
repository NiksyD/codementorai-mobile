---
name: flutter-minimal-ui
description: Guidelines and design system standards for building modern, minimal, high-aesthetic Flutter interfaces with clean code quality and Feature-First architecture.
---

# Flutter Minimal Modern Design & Code Standards

Use this skill whenever creating or refining Flutter user interfaces, widgets, and feature modules. It enforces modern minimal UI aesthetics, fluid micro-animations, clean layout patterns, and strict Dart/Flutter coding standards.

---

## 🎨 1. Design Aesthetics & Visual Excellence

### Core Philosophy
Minimal design is **purposeful, expressive, and refined**—never basic or raw. Every screen should feel premium, responsive, and alive.

### Color Palette & Theme Tokens
- **Avoid Plain Defaults**: Never use default raw red, green, or blue. Use curated harmonious color tokens.
- **Dynamic HSL/HCT Palettes**: Configure Material 3 `ColorScheme.fromSeed` with tailored surface, background, primary, and container tones.
- **Dark & Light Harmony**:
  - Dark Mode: Rich slate/charcoal backgrounds (`Color(0xFF0F172A)` or `Color(0xFF121212)`) with subtle surface elevation contrast.
  - Light Mode: Clean off-white/alabaster surfaces (`Color(0xFFF8FAFC)`).

### Modern UI Layout Trends
1. **Bento Grid Layouts**: Structure content-rich dashboards and cards into modular bento grids using `GridView` or `Row`/`Column` with flexible ratios.
2. **Glassmorphism & Depth**: Use subtle translucent containers with thin borders (`Color(0x1AFFFFFF)` or `Color(0x0F000000)`) and `BackdropFilter` for depth.
3. **Typography Hierarchy**: Use modern sans-serif typefaces (e.g., *Inter*, *Plus Jakarta Sans*, *Outfit*) with distinct font weight hierarchy (Headline: 700/800, Subtitle: 600, Body: 400).

### Micro-Animations & Motion
- **Implicit Animations**: Wrap state transitions in `AnimatedContainer`, `AnimatedSwitcher`, `AnimatedCrossFade`, or `AnimatedOpacity`.
- **Interactive Feedback**: Add subtle scale transitions (`AnimatedScale`) or opacity changes on button press/tap.
- **Smooth Duration**: Use consistent animation curves (`Curves.easeInOutCubic` or `Curves.fastOutSlowIn`) with 200ms–350ms durations.

---

## 📐 2. Responsive & Adaptive Layouts

- **Use `LayoutBuilder`**: Calculate component sizing and responsive column counts based on available parent constraints instead of hardcoding static pixel widths.
- **Flexible Spacing**: Use standardized spacing tokens (`AppSizes.p8`, `AppSizes.p16`, `AppSizes.p24`, `AppSizes.gapH16`).

---

## 🏗️ 3. Feature-First Architecture & Component Standards

### Feature Layer Decomposition
Organize every feature inside `lib/src/features/<feature_name>/`:
```text
lib/src/features/<feature_name>/
├── presentation/     # Screens, custom widgets, state controllers
├── application/      # Business logic services
├── domain/           # Immutable data models & entities
└── data/             # Repositories & API data sources
```

### Component Quality Rules
1. **Decompose Widgets**: Keep `build()` methods under 80 lines. Split complex UI sections into smaller, focused private or shared `StatelessWidget`s.
2. **Strict `const` Usage**: Mark all static widgets and constructors with `const` for render tree caching and maximum FPS performance.
3. **Design Tokens**: Retrieve colors and dimensions from `AppColors`, `AppSizes`, or `Theme.of(context)`—never hardcode raw pixel constants or inline colors in widgets.

---

## ⚡ 4. Code Standards & Lint Compliance

- **Zero `print()` Statements**: Never use `print()`. Use `developer.log()` or structured logging.
- **Strict Typing**: Zero `dynamic` types or untyped lists. Use explicit type declarations and return types.
- **Single Quotes & Trailing Commas**: Enforce single quotes `'...'` for strings and trailing commas on multi-line parameter lists.
