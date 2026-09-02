<!-- BEGIN:flutter-agent-rules -->
# Flutter & Dart Engineering Rules — CodeMentorAI Mobile

This repository adheres to strict Flutter/Dart architecture, WCAG 2.1 AA accessibility, Jakob's Law UX principles, and design system parity with `codementorai-web`.
<!-- END:flutter-agent-rules -->

---

# CodeMentorAI Mobile — Agent Rules & Engineering Standards

> **Canonical reference for any AI agent or developer working on `codementorai-mobile`.**
> Follow these rules unconditionally. Do not deviate without explicit user approval.

---

## 1. Architecture Overview (Feature-First Clean Architecture)

The codebase follows a modular, feature-first clean architecture:

```
codementorai-mobile/
├── assets/
│   ├── images/               # Raster and vector graphics
│   └── icons/                # Static asset icons
├── lib/
│   ├── src/
│   │   ├── common_widgets/   # Reusable UI widgets across features (buttons, cards, toasts)
│   │   ├── constants/        # Design tokens (AppColors, AppTheme, AppSizes)
│   │   ├── routing/          # GoRouter configuration and route definitions (app_router.dart)
│   │   ├── theme/            # Dynamic theme switching controllers
│   │   ├── utils/            # Formatters, validators, extensions, platform helpers
│   │   └── features/         # Feature modules
│   │       ├── auth/         # Authentication (login, register, OTP, reset password)
│   │       │   ├── data/     # Repositories, Supabase data sources, DTOs
│   │       │   ├── domain/   # Entities, value objects, domain logic
│   │       │   └── presentation/ # Screens, controllers, widgets
│   │       ├── onboarding/   # Walkthrough & initial user flow
│   │       ├── profile/      # User profile & settings
│   │       ├── dashboard/    # Main shell, navigation, learner home
│   │       └── mentor/       # Mentor portal mobile views
│   ├── main.dart             # App entry point, initialization (Supabase, Dotenv)
│   └── AGENTS.md             # This canonical standards file
├── analysis_options.yaml     # Strict Dart linter rules
├── pubspec.yaml              # Dependencies and asset declarations
└── .env.example              # Environment variables template
```

### Key Dependencies & Tools

| Dependency | Purpose |
|---|---|
| `flutter` (Dart 3.x) | UI Framework with Material 3 |
| `go_router` | Declarative URL-based routing & deep linking |
| `supabase_flutter` | Auth, PostgREST database, and real-time subscription |
| `flutter_dotenv` | Environment variable management |
| `google_fonts` | Typography (Plus Jakarta Sans & JetBrains Mono) |
| `font_awesome_flutter` | Icon library (strictly used instead of emoji) |
| `lottie` | Smooth, micro-interaction vector animations |
| `shared_preferences` | Lightweight local key-value persistence |

---

## 2. Design System & Web Parity

The mobile application **must maintain 100% visual parity and aesthetic consistency** with `codementorai-web`.

### 2.1 Typography Separation (MANDATORY)

This is the foundational design rule. **Violating it breaks brand consistency.**

| Use Case | Font Family | Flutter Implementation |
|---|---|---|
| **Body text, titles, headings, descriptions, buttons, labels** | Plus Jakarta Sans / Inter | `GoogleFonts.plusJakartaSans(...)` or `Theme.of(context).textTheme` |
| **Numeric metrics, KPIs, code blocks, timestamps, percentages** | JetBrains Mono | `GoogleFonts.jetbrainsMono(...)` |

#### Examples:
- ✅ **Correct Label**: `Text('Active Modules', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w600))`
- ✅ **Correct KPI Number**: `Text('94.8%', style: GoogleFonts.jetbrainsMono(fontSize: 24, fontWeight: FontWeight.bold))`
- ❌ **WRONG**: Monospace on UI labels or section titles.
- ❌ **WRONG**: Standard sans-serif for numbers, percentages, or code snippets.

---

### 2.2 Color Tokens & Semantic Hierarchy

**Never hardcode hex colors in widget trees.** Always consume tokens from `AppColors` or `Theme.of(context).colorScheme`:

| Semantic Token | Dark Mode (`0xFF`) | Light Mode (`0xFF`) | Usage |
|---|---|---|---|
| `primary` | `#3ECF8E` (Emerald Mint) | `#3ECF8E` | Primary actions, key CTAs, highlights |
| `primaryVariant` | `#059669` | `#059669` | Gradients, active states |
| `surface` / `card` | `#151922` / `#1A1F2C` | `#FFFFFF` / `#F0F4F9` | Screen cards, dialogs, sheets |
| `background` | `#0E1118` | `#F8F9FA` | Scaffold background |
| `border` | `#222733` | `#E1E7F0` | Dividers, card outlines, input borders |
| `textPrimary` | `#F4F5F7` | `#1F1F1F` | High-emphasis text & titles |
| `textSecondary` | `#C4C7C5` | `#44474F` | Medium-emphasis labels, subtitles |
| `error` | `#EF4444` | `#DC2626` | Destructive actions, validation errors |
| `success` | `#10B981` | `#059669` | Successful submissions, active indicators |

---

## 3. WCAG 2.1 / 2.2 AA Accessibility (MANDATORY)

Every screen and widget must pass WCAG 2.1 AA compliance:

1. **Touch Target Size (WCAG 2.5.5 / 2.5.8)**:
   - Every tappable control (buttons, icon buttons, list tiles, checkboxes) must have a minimum interactive bounding box of **`48x48 dp`** (use `IconButton(constraints: BoxConstraints(minWidth: 48, minHeight: 48))` or `kMinInteractiveDimension`).
2. **Color Contrast Ratio (WCAG 1.4.3)**:
   - Text vs. Background: Minimum **`4.5:1`** for standard text, **`3.0:1`** for large text (18pt+ / 24sp+ bold).
   - Never use opacity below `0.70` for readable text (e.g., avoid `color.withOpacity(0.3)` on copy).
3. **Typography Minimums**:
   - Minimum visible font size: **`12sp`** (`AppSizes.p12`). Never use sub-12sp text for user-readable content.
4. **Non-Text Contrast & Meaning**:
   - Never use color as the sole indicator of state or error. Always pair color with an icon and clear helper text.
5. **Screen Reader & Semantics**:
   - Wrap custom gestures and icons with `Semantics(label: '...', button: true, child: ...)` or use standard semantic widgets (`Tooltip`, `ElevatedButton`).
6. **Dynamic Scaling**:
   - Layouts must tolerate text scaling up to 1.5x (`MediaQuery.textScalerOf(context)`) without vertical pixel overflow (`A RenderFlex overflowed by ... pixels`). Always wrap variable text containers in `SingleChildScrollView` or use flexible layouts.

---

## 4. Jakob's Law & Industry-Standard Mobile UX

> **Jakob's Law**: Users spend most of their time on other apps. Your app should operate with the conventions, gestures, and patterns users already expect.

### 4.1 Navigation & Screen Architecture
- **Bottom Navigation Shell**: For primary navigation tabs. Icons must have active/inactive states and clear labels.
- **Predictable Back Behavior**: Top-left back button (`Icons.arrow_back_ios_new` / `Icons.arrow_back`) on nested routes; support Android system back navigation and iOS edge-swipe back gestures.
- **Reachability (Thumb Zone)**: Place primary action buttons (Submit, Continue, Next) in the bottom thumb-friendly zone of the screen, pinned above the bottom safe area.

### 4.2 Forms & Input UX
- **Keyboard Optimization**: Always specify appropriate `TextInputType` (`emailAddress`, `phone`, `number`, `visiblePassword`).
- **Autofill & Action Buttons**: Set `autofillHints: const [AutofillHints.email]`, `textInputAction: TextInputAction.next` and `TextInputAction.done`.
- **Dismiss Keyboard**: Tapping outside inputs should dismiss the virtual keyboard (`GestureDetector(onTap: () => FocusScope.of(context).unfocus())`).
- **Inline Error Feedback**: Display validation errors directly beneath the relevant input field, in red (`AppColors.error`), with immediate error clearing upon user correction.

### 4.3 Feedback & State Handling
- **State Triad**: Every async data screen **must handle 4 states**:
  1. **Loading**: Use shimmering skeleton loaders, not just raw centered spinners where layout preview is possible.
  2. **Success / Content**: Render cleanly with pull-to-refresh (`RefreshIndicator`).
  3. **Empty State**: Clear illustration/icon, descriptive title, and a direct call-to-action button.
  4. **Error State**: Non-cryptic user message with a "Retry" CTA button.
- **Haptic Feedback**: Trigger subtle haptics on critical user events (`HapticFeedback.lightImpact()` on tap, `HapticFeedback.mediumImpact()` on success).

---

## 5. Coding Standards & Dart Best Practices

### 5.1 Strict Dart Analyzer Rules
- Adhere to `analysis_options.yaml` (strict casts, strict inference, strict raw types).
- **Zero Warnings**: Code must compile cleanly with `flutter analyze` without any errors or linter warnings.
- **Use `const` Constructors Everywhere Possible**: Every stateless widget and fixed value must be prefixed with `const` to minimize rebuild cost.
- **Always Add Trailing Commas**: Ensure all argument lists, parameter lists, and widget trees end with a trailing comma `,` for clean automatic formatting.

### 5.2 Widget Architecture & State
- **Single Responsibility**: Keep widget files small and modular (< 250 lines). Extract reusable sub-widgets into `src/common_widgets/` or private sub-widgets in the same file.
- **No Business Logic in Views**: Move validation, API calls, and domain transformations into dedicated Repository / Service classes in `src/features/<feature>/data/`.
- **Avoid Global Variables**: Encapsulate controllers and services; pass dependencies cleanly.

### 5.3 Asynchronous Code & Error Handling
- Always use `try-catch` blocks when handling Supabase or network calls.
- Check `if (!mounted) return;` after any `await` before updating state in a `StatefulWidget` or navigating.
- Never use `print(...)` in production code — use `debugPrint(...)` or structured logging.

---

## 6. Anti-Patterns & Strict Prohibitions

> [!CAUTION]
> The following anti-patterns are **STRICTLY PROHIBITED**:

- ❌ **NO Emojis in UI Headings or Titles** (no `👋`, `🚀`, `✨` in rendered app titles or headings). Use FontAwesome or Phosphor vector icons.
- ❌ **NO "AI Slop" Visuals** (no generic glowing magic wands or "AI Generated" badges without functional meaning).
- ❌ **NO Hardcoded Dimensions or Colors** (never write `Color(0xFF...)` inline in screen files; use `AppColors` and `AppSizes`).
- ❌ **NO Monospace Font on General UI Copy** (reserve `JetBrains Mono` strictly for metrics, numbers, code, and timestamps).
- ❌ **NO Unsafe Area Overlaps** (always wrap top/bottom content with `SafeArea`).
- ❌ **NO Hardcoded Secret Keys** in code (all API keys, Supabase URLs, and endpoints must be sourced from `.env` via `flutter_dotenv`).
- ❌ **NO Unchecked Async Context Calls** (never use `context` after an `await` without checking `if (mounted)`).

---

## 7. Git & Development Workflow

1. **Branch Naming**:
   - `feat/<feature-name>` (e.g., `feat/auth-login`, `feat/mentor-dashboard`)
   - `fix/<issue-name>` (e.g., `fix/token-refresh`, `fix/overflow-profile`)
2. **Commit Messages**: Follow Conventional Commits:
   - `feat(auth): implement Google and GitHub OAuth flow`
   - `fix(theme): correct dark mode contrast for form labels`
3. **Pre-Push Verification Checklist**:
   - [ ] `flutter analyze` passes with 0 issues.
   - [ ] Code is formatted with `dart format .`.
   - [ ] No secrets or `.env` committed.
