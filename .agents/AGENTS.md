# Project Rules & Coding Standards

This document specifies mandatory rules, coding standards, and architectural guidelines for `codementorai_mobile`. Agents MUST read and follow these rules before writing or modifying any code.

---

## 0. Application Overview & Domain Context (CodeMentor AI)

**CodeMentor AI** is an AI-powered adaptive programming mentorship, code evaluation, and developer career preparation platform.

### Core Product Modules & Features:

1. **🤖 AI Mentor (`features/mentor`)**: Interactive real-time AI code review, debugging assistant, inline feedback, and pair programming chat.
2. **⚡ Practice & Sandbox (`features/practice`)**: Interactive coding challenges with real-time multi-language code execution via Judge0 backend, test case evaluations, and submission history.
3. **📊 Dashboard & Analytics (`features/dashboard`, `features/analytics`)**: User progress overview, daily streaks, skill radar charts (algorithms, backend, clean code), and growth metrics.
4. **🎓 Learning Paths (`features/learn`)**: Structured curriculum, interactive coding tutorials, and step-by-step career tracks.
5. **🛍️ Marketplace (`features/marketplace`)**: Community AI mentor personas, challenge packs, and prompt templates.
6. **👤 Profile & Settings (`features/profile`, `features/auth`)**: User authentication via Supabase Auth, user profile, badges, certifications, and settings.

---

## 1. Architectural Standards (Feature-First)

- **Architecture**: Follow **Feature-First Architecture** (`lib/src/features/<feature_name>/`).
- **Feature Layer Structure**:
  - `presentation/`: UI Screens, Widgets, and State Controllers.
  - `application/`: Business logic services coordinating between data and UI.
  - `domain/`: Immutable data models and entities.
  - `data/`: Repositories and API data sources (e.g., `SupabaseAuthRepository`).
- **Shared Code**:
  - `lib/src/common_widgets/`: Reusable UI components.
  - `lib/src/constants/`: App tokens (`AppColors`, `AppSizes`, theme).
  - `lib/src/utils/`: Helper formatters and functions.
  - `lib/src/routing/`: App navigation logic.

---

## 2. Dart & Flutter Code Quality Rules

- **Strict Type Safety**: Never use `dynamic` (or `any` style casting). Always use explicit return types and strict generic parameters.
- **Zero Console Logs**: `print()` is strictly forbidden (`avoid_print: true`). Use `developer.log()` or structured logging if needed.
- **UI Performance**: Always mark widgets and collections `const` whenever possible (`prefer_const_constructors`).
- **String Formatting**: Prefer single quotes `'...'` for strings.
- **Trailing Commas**: Require trailing commas in multi-line widget lists and parameter calls for clean diffs.

---

## 3. Git & Husky Commit Standards

- **Commit Message Prefixes**: ONLY 3 commit types are permitted:
  - `feat:` (New features)
  - `fix:` (Bug fixes)
  - `chore:` (Tooling, dependencies, maintenance)
- **Header Length Limit**: Maximum **72 characters**.
- **Pre-commit Checks**: All commits MUST pass `dart format` and `flutter analyze`.
- **Pre-push Checks**: All pushes MUST pass `flutter test`.

---

## 4. Backend & Environment Guidelines

- **Supabase Backend**: All backend API calls, database queries, and authentication MUST use the initialized Supabase client (`Supabase.instance.client`).
- **Environment Secrets**: Never hardcode API keys or secrets in Dart code. Always load from `.env` via `flutter_dotenv`.

---

## 5. UI Design & Aesthetic Guidelines (`flutter-minimal-ui` Skill)

- **Minimal Modern Aesthetics**: Create clean, modern, high-contrast UIs using dynamic Material 3 color tokens (`ColorScheme.fromSeed`), Bento grid cards, glassmorphism, and responsive `LayoutBuilder` layouts.
- **Motion & Micro-Animations**: Use implicit animations (`AnimatedContainer`, `AnimatedSwitcher`, `AnimatedCrossFade`) for fluid UI state transitions.
- **Component Decomposition**: Keep `build()` methods small (under 80 lines) by breaking screens down into focused, reusable components.
- **Design Tokens**: Always use `AppColors`, `AppSizes`, and `Theme.of(context)` instead of hardcoded raw pixels or inline colors.

---

## 6. Workspace Agent Skills (`.agents/skills/`)

Agents MUST load and follow the corresponding skill blueprint when performing specialized tasks:

1. **`flutter-minimal-ui`**: Minimal modern UI design system, Material 3, animations, and design tokens.
2. **`flutter-build-responsive-layout`**: Constraint-based responsive layouts using `LayoutBuilder` across mobile/tablet/web.
3. **`flutter-fix-layout-issues`**: Troubleshooting and fixing RenderFlex overflows and viewport constraint errors.
4. **`flutter-apply-architecture-best-practices`**: Layered Feature-First UI/Logic/Data decoupling and repository patterns.
5. **`flutter-lottie-animations`**: Vector Lottie JSON micro-animations for splash, onboarding, loading, and interactive UI states.
