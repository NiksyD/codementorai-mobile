---
name: flutter-lottie-animations
description: Guidelines and best practices for incorporating smooth vector Lottie animations (from LottieFiles or local assets) into Flutter screens, splash, onboarding, loading states, and micro-interactions.
---

# Flutter Lottie Animations & Vector Micro-Interactions

Use this skill whenever integrating Lottie JSON animations (`package:lottie`) into Flutter screens, onboarding carousels, splash screens, empty states, and interactive feedback widgets.

---

## 🎨 Core Guidelines

1. **Asset & Network Flexibility**:
   - Use `Lottie.network()` for online CDN Lottie JSONs with a smooth custom `frameBuilder` or loading placeholder to prevent blank screen pop-in.
   - Use `Lottie.asset()` for local bundled JSON files in `assets/animations/`.

2. **Performance Optimizations**:
   - Wrap Lottie widgets in `SizedBox` or explicit constraint containers to prevent unexpected layout overflow during asset parsing.
   - Set `repeat: true` for continuous background loaders/splash animations, and `repeat: false` for one-time success or completion triggers.
   - Provide custom `AnimationController` when scrubbing or syncing Lottie animations with user swipes (e.g. `PageView` on onboarding screens).

3. **Fallback & Error Handling**:
   - Always supply an `errorBuilder` callback so that network failures or missing assets gracefully fall back to custom styled vector icons/widgets.

---

## 🛠️ Example Patterns

### Onboarding Lottie Page View Item

```dart
Widget buildLottieHeader(String url, IconData fallbackIcon) {
  return Lottie.network(
    url,
    height: 220,
    fit: BoxFit.contain,
    errorBuilder: (context, error, stackTrace) => Icon(fallbackIcon, size: 80),
    frameBuilder: (context, child, composition) {
      if (composition == null) {
        return const SizedBox(
          height: 220,
          child: Center(child: CircularProgressIndicator.adaptive()),
        );
      }
      return child;
    },
  );
}
```
