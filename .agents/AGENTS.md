# Project Rules & Coding Standards

This document specifies mandatory rules, coding standards, and architectural guidelines for `codementorai_mobile`. Agents MUST read and follow these rules before writing or modifying any code.

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
