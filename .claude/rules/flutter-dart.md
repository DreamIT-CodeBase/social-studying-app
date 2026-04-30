---
globs: "flutter_app/**/*.dart"
---

# Flutter / Dart Rules

## Ethos: Boil the Lake
Every widget gets tested. Every state edge case gets handled. Loading states, error states, empty states — all three, every screen, no exceptions. "It works on the happy path" means it's 30% done. The marginal cost of handling the error and empty states is near-zero.

## Ethos: Anti-Slop
No placeholder widgets (`Container()` with a TODO). No unnamed colors — use the theme system. No hardcoded strings — use constants or l10n. No `setState()` in anything larger than a trivially simple widget — use Riverpod. No `print()` — use `debugPrint()` or a proper logger. No `dynamic` types. No `!` null assertions without a comment explaining why it's safe.

## Architecture: Feature-First with Riverpod
```
lib/
  core/             — app-wide: theme, routing, DI, constants, extensions
  features/
    auth/           — login, signup, invite code redemption
      data/         — repositories, data sources, DTOs
      domain/       — entities, repository interfaces
      presentation/ — screens, widgets, controllers (Riverpod notifiers)
    home/
    questions/
    flashcards/
    gamification/
    admin/
      documents/
      workspace/
      users/
      taxonomy/
      moderation/
      settings/
  shared/           — reusable widgets, models, services used across features
```

## State Management: Riverpod 2.x
Use `@riverpod` annotation (riverpod_generator) for all providers. AsyncNotifier for async state with loading/error/data. NotifierProvider for synchronous state that needs methods. Use `ref.watch` in widgets, `ref.read` in callbacks and event handlers. Never store widget-local ephemeral state (text field focus, animation progress) in Riverpod — that's `useState` or local state. Use Freezed for immutable state classes and union types.

## Navigation: GoRouter
All routes defined in `core/routing/`. Use typed route parameters via code generation. Route guards for auth state (redirect unauthenticated users to login). Nested navigation for admin tabs and student bottom nav.

## Networking: Dio
Single Dio instance configured in DI with: base URL from environment config, auth interceptor that attaches JWT and handles token refresh transparently, error interceptor that maps HTTP errors to typed app exceptions, logging interceptor (debug only). Response models generated from backend Pydantic schemas — keep frontend and backend models in sync. Use Freezed + json_serializable for all API models.

## UI Conventions
Use Material 3 with a custom ColorScheme — define in `core/theme/`. Support light and dark mode from day one via `ThemeData` switching. Use `context.textTheme` and `context.colorScheme` extensions — never hardcode TextStyle or Color. All spacing via a spacing scale constant (4, 8, 12, 16, 24, 32, 48). Responsive: use LayoutBuilder or MediaQuery for tablet/phone adaptation. Haptic feedback on: correct/incorrect answers, badge unlocks, streak milestones. Animations: use `AnimatedSwitcher`, `Hero`, and implicit animations. No `Future.delayed` for fake loading states.

## Flavor System (Admin vs Student)
Two entry points: `main_admin.dart` and `main_student.dart`. Shared core, features gated by flavor config injected via Riverpod. Build commands: `flutter run --flavor admin -t lib/main_admin.dart` and `flutter run --flavor student -t lib/main_student.dart`. Feature flags in `core/config/app_flavor.dart` determine which routes and features are available.

## Testing
Widget tests for every screen (happy path, loading, error, empty). Unit tests for every Notifier/Controller. Integration tests for critical flows (login, answer question, earn XP). Use `ProviderScope.overrides` for dependency injection in tests. Use `mocktail` for mocking — not `mockito`. Golden tests for design-critical screens (optional but encouraged). Test file mirrors source: `lib/features/auth/presentation/login_screen.dart` → `test/features/auth/presentation/login_screen_test.dart`.

## Confusion Protocol
If a design decision is ambiguous (should this be a bottom sheet or a new page? should this state be local or global?), STOP and ask. Don't guess at UX patterns. The cost of asking is one message. The cost of building the wrong interaction pattern is a rewrite and user confusion.
