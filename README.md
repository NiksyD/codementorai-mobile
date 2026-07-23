# CodeMentor AI Mobile - Flutter Template

A production-ready, feature-first Flutter starter template pre-configured with strict linting, automated Git hooks, environment management, and GitHub Actions CI.

---

## 🏗️ Architecture & Project Structure

This project follows the **Feature-First Architecture** recommended for scalable Flutter applications:

```text
lib/
├── src/
│   ├── features/          # Feature modules (e.g. auth, home, profile)
│   │   └── auth/          # Authentication module
│   │       ├── presentation/ # UI screens, widgets, controllers
│   │       ├── application/  # Business logic services
│   │       ├── domain/       # Immutable models & entities
│   │       └── data/         # Repositories & API data sources
│   ├── common_widgets/    # Shared UI components across features
│   ├── constants/         # App constants (AppColors, AppSizes, Theme)
│   ├── utils/             # Helper formatters & utility functions
│   └── routing/           # App navigation & route definitions
└── main.dart              # Application entrypoint
```

---

## 🛠️ Setup & Local Development

### 1. Prerequisites
- [Flutter SDK](https://docs.flutter.dev/get-started/install) (3.x+)
- [Node.js](https://nodejs.org/) (v18+) for Husky Git hooks

### 2. Installation
```bash
# Install Node dependencies for Git hooks
npm install

# Install Flutter dependencies
flutter pub get
```

### 3. Environment Variables
Copy `.env.example` to create your local `.env` file:
```bash
cp .env.example .env
```

---

## 🐶 Automated Git Hooks (Husky & Commitlint)

This repository enforces strict code quality and commit standards via **Husky**:

- **Pre-commit**: Automatically runs `dart format` & `flutter analyze`.
- **Pre-push**: Automatically runs `flutter test`.
- **Commit Message (`commitlint`)**: Enforces strictly 3 commit types (`feat`, `fix`, `chore`) with a **72-character limit**:
  - `feat: add user login screen`
  - `fix: resolve auth validation bug`
  - `chore: update dependencies`


---

## 🧪 Testing & Analysis

```bash
# Run static analysis
flutter analyze

# Run unit & widget tests
flutter test

# Check code formatting
dart format --output=none --set-exit-if-changed lib test
```
