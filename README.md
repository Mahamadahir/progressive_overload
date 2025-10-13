# Fitness Tracker

Progressive overload training companion that blends workout planning, nutrition logging, and Health Connect / Apple Health insights in a single Flutter app.

> Release: **Muscle Groups Drift** (completed) - adds hierarchical muscle targeting, inactivity alerts, enriched trends, and dark mode.

## Overview
- Build progressive overload workout plans that stay in sync with your primary exercises and target muscle groups.
- Log sessions, track strength progression, and push workouts to Health Connect / Apple Health with automatic calorie estimates.
- Monitor nutrition, activity, steps, and weight trends in a calendar view that highlights goal adherence.
- Configure reminders, default training parameters, and theme preferences from the Targets hub.
- Receive muscle inactivity notifications when targeted groups have not been trained within your defined window.

## Feature Highlights
- **Dashboard:** Quick metrics, dark-mode toggle, inactivity alerts, and shortcuts into workout, nutrition, and analytics flows.
- **Muscle-aware planning:** Create plans by selecting exercises and target muscle groups with automatic descendant selection and inactivity coverage checks.
- **Session logging:** Progressive overload logic adjusts weight/reps, syncs data to Drift/Hive, and writes workouts + calories to Health data stores.
- **Nutrition tracking:** Maintain reusable meal templates, log intake, and surface net calorie balances per day.
- **Trends calendar:** Month view that blends calorie balance, workouts, steps, and weight alongside meal details.
- **Targets & reminders:** Manage calorie deficit goals, daily step targets, weigh-in/workout reminders, and default progression settings.
- **Health diagnostics:** Dedicated screen to test permissions, prompt rationale flows, and inspect Health Connect readiness.

## Tech Stack
- Flutter (Material 3, Dart 3.8)
- Hive for offline-first storage of plans, meals, logs, and user settings
- Drift for relational analytics (workouts, muscle groups, exercise metadata)
- `health` plugin plus a custom MethodChannel bridge for Health Connect history permissions
- Flutter Local Notifications with timezone support
- Device Apps + URL launcher for Health Connect deep links

## Getting Started

### Prerequisites
- Flutter stable (commit `a402d9a4` or newer) with Dart 3.8 SDK
- Android Studio / Xcode for platform builds
- Android 13+ physical device or emulator with the [Health Connect](https://play.google.com/store/apps/details?id=com.google.android.apps.healthdata) app installed
- (Optional) iOS device configured for Apple Health testing

Run `flutter doctor` and resolve any reported issues before continuing.

### Install dependencies
```bash
flutter pub get
flutter pub run build_runner build --delete-conflicting-outputs
```
Regenerate code whenever Drift tables, Hive adapters, or model annotations change. Use `flutter pub run build_runner watch` during iterative schema work.

### Run the app
```bash
flutter run
```
Specify a device with `-d <device-id>` if multiple simulators/emulators are available. The default entry point is `lib/main.dart` which wires up app initialization, Hive boxes, and services.

### Quality checks
```bash
dart analyze
flutter test
```
Unit tests for Drift repositories and services live under `test/`. Add coverage alongside new features, especially when expanding workout progression or data access logic.

## Health Data Integration

### Android (Health Connect)
1. Install the Health Connect app and open it at least once.
2. Build and launch the app on an Android 13+ device or emulator.
3. From the dashboard diagnostics, request the required permissions:
   - Workout read/write
   - Total calories read/write
   - Weight read
   - Steps read
   - History access (`READ_HEALTH_DATA_HISTORY`) via the in-app MethodChannel bridge.
4. Accept the permission prompts from Health Connect. If a prompt does not appear, open the Diagnostics screen to retry or view rationale.

### iOS (Apple Health)
Permissions are requested at runtime. Accept workout, calorie, step, and weight read/write prompts when the system sheet appears.

### Data flow
- Session logs write strength workouts with total calories burned to the native health store.
- The trends calendar batches health data (steps, calories, weight) per day and caches historical values in Hive for faster reloads.
- Meal intake is aggregated locally and combined with Health data to compute daily net calorie balance.

## Notifications and Reminders
- `NotificationService` initializes local notifications, requests Android 13+ runtime permission, and schedules weigh-in/workout reminders defined on the Targets page.
- Muscle inactivity checks run when the dashboard loads and trigger instant notifications if a target group has been idle past the configured threshold.
- Cancel or reschedule reminders via the Targets screen; ongoing schedules use timezone-aware triggers.

## Project Structure
- `lib/app.dart`: MaterialApp configuration, routes, and theme handling.
- `lib/screens/`: UI flows (dashboard, plans, sessions, nutrition, trends, diagnostics).
- `lib/services/`: Domain services for workouts, health, meals, notifications, permissions, and background logic.
- `lib/database/`: Drift database, DAOs, and schema definitions (generated code in `app_database.g.dart`).
- `lib/models/`: Hive type adapters and serializable models.
- `android/` / `ios/`: Platform integrations, including Health Connect permission bridge (see `MainActivity.kt`).
- `test/`: Unit tests for Drift repositories and services.

## Troubleshooting
- **Health permissions keep failing:** Open Health Connect manually, revoke the app, then relaunch and request permissions from the Diagnostics screen.
- **Missing generated files:** Run `flutter pub run build_runner build --delete-conflicting-outputs` and ensure generated `.g.dart` files are checked into version control.
- **Notifications do not fire:** Confirm the POST_NOTIFICATIONS permission is granted (Android 13+) and the device's notification channel is enabled.
- **Workout logging errors:** Validate that the default exercise is set for the plan and that Health workout write permissions were approved.

## Contributing
1. Fork and clone the repository.
2. Branch from the latest `main` (e.g., `git checkout -b feature/<topic>`).
3. Make changes, add/update tests, and run `dart analyze` plus `flutter test`.
4. Commit with conventional messages and submit a pull request.
5. For schema updates, include regenerated Drift/Hive artifacts and note any migration steps in the PR description.

## Release Workflow
- Merge feature branches (e.g., `feature/muscle-groups-drift`) into `main` via PR once tests are green.
- Tag releases after `main` is updated and the app builds cleanly on CI.
- Document notable changes in this README or a dedicated `CHANGELOG.md` before publishing builds.

---

Questions or ideas? Open an issue or reach out via your preferred channel.
