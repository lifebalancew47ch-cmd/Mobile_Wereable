# LifeBalance - Mobile App (Flutter)
**AI Agent Context File**

This document provides a comprehensive overview of the LifeBalance mobile application architecture, stack, and current implementation details to help AI agents quickly onboard and contribute to the project.

## 1. Project Overview
- **Name**: LifeBalance
- **Platform**: Cross-platform mobile (primarily Android) built with Flutter (Dart SDK ^3.9.2). Includes a companion **Wear OS** native app in `android/wear/`.
- **Core Purpose**: A health and activity tracking application that monitors user movement (specifically inactivity) using device sensors and wearable integration, sending alerts when the user has been sedentary for too long (45 minutes = 90 idle windows).
- **Architecture Pattern**: Fog Computing. The phone acts as a Fog node: it receives batched sensor data from the watch, analyzes it locally (FogEngine), and persists results to an encrypted local database. Cloud synchronization is planned but **not yet implemented** (placeholder in `SyncService`).
- **Backend API**: The app communicates with live REST APIs hosted on Render (three microservices), securely via HTTPS with Certificate Pinning.

## 2. Tech Stack & Dependencies
- **UI Framework**: Flutter (Dart 3.x)
- **State Management**: Riverpod (`flutter_riverpod`)
- **Routing**: `go_router` (StatefulShellRoute with 5 bottom-nav tabs)
- **Network & API**: `dio` with custom `RetryWithBackoffInterceptor` and strict SSL/TLS Certificate Pinning (`IOHttpClientAdapter`).
- **Local Storage / DB**:
  - `sqflite_sqlcipher` (Encrypted SQLite via `SecureDatabaseService`, AES-256 key from secure storage)
  - `flutter_secure_storage` (Secure key-value storage for credentials/tokens)
  - `shared_preferences` (lightweight preferences)
- **Background Execution**: `flutter_background_service` (foreground service with persistent notification) & `workmanager`
- **Sensors & Bluetooth**: `sensors_plus`, `flutter_blue_plus`
- **Health Data**: `health` (Health Connect), `timezone`, `rxdart`
- **Security**:
  - `flutter_jailbreak_detection` (app exits immediately if rooted/jailbroken)
  - `certificate_pinning.dart` (Fail-closed strict certificate pinning in Release mode)
  - `local_auth` (biometric profile authentication)
- **Notifications**: `flutter_local_notifications`
- **Firebase**: `firebase_core`, `firebase_crashlytics`, `firebase_auth`, `cloud_firestore` (dependencies installed; intended for future Cloud layer)
- **Dev / Tooling**: `flutter_lints`, `dart_code_metrics`, `mocktail`, `flutter_launcher_icons`

## 3. Architecture
The project follows **Clean Architecture** patterns separated by features.

### Directory Structure
```
lib/
├── core/             # Shared utilities
│   ├── fog_engine.dart        # FogEngine (real implementation)
│   ├── network/api_client.dart # Dio clients + retry interceptor + pinning
│   ├── routes/app_router.dart # go_router configuration (all routes)
│   ├── security/              # certificate_pinning, encryption_service, token_service, auth_gate
│   └── theme/                 # app_theme, theme_provider (light/dark)
├── data/datasources/ # secure_database_service.dart (encrypted SQLite singleton)
├── features/         # Feature-based modules (Clean Architecture)
│   ├── auth/         # Authentication (CURRENT, Clean Architecture)
│   ├── authentication/  # LEGACY duplicate screens (splash, login, register) - see caveats
│   ├── admin/       # Admin summary
│   ├── analytics/   # Performance analysis + heatmap
│   ├── bluetooth/   # Bluetooth screen
│   ├── dashboard/   # Main app UI after login (executive dashboard)
│   ├── fog/         # Fog status screen + providers
│   ├── gamification/ # Gamification screen
│   ├── notifications/# Notifications UI and logic
│   ├── profile/     # User profile, biometric, activity history
│   ├── settings/    # Settings + alert configuration
│   ├── support/     # FAQ + video explanation
│   └── wearable/    # Wearable sync UI (device scan/manage, watch alert/progress)
├── models/           # Shared models (fog_state, vital_sign)
├── presentation/     # Global screens (watch_dashboard)
├── services/         # Platform services (BackgroundService, WatchService, SyncService, NotificationService, WearableCommunicationService, SensorService, BluetoothService)
├── shared/widgets/   # main_navigation_shell (bottom nav)
└── main.dart         # Entry point: env vars, jailbreak check, DB init, permissions, background service
```

### Feature Module Structure (Clean Architecture)
Inside each feature (e.g., `features/auth/`), the structure is:
- **`data/`**: API Services (`Datasources`), Repositories Implementation.
- **`domain/`**: Entities (Models), abstract Repositories, Use Cases.
- **`presentation/`**: Riverpod Providers (State Notifiers), Screens, and Widgets.

### Navigation (go_router)
- Top-level routes: `/splash`, `/login`, `/auth/register`, `/auth/forgot-password`, `/watch`, `/watch/alert`, `/watch/progress`, `/fog`
- StatefulShellRoute with 5 tabs: `/dashboard` (notifications subroute), `/analytics` (heatmap subroute), `/admin`, `/support` (video subroute), `/profile` (biometric, settings, history, wearable-scan, wearable-manage subroutes)

## 4. Data Flow: Wearable → Fog → Local DB (→ Cloud planned)

```
Wear OS (android/wear/.../SensorService.kt)
  ├─ Hardware batching: accelerometer registered with 5s maxReportLatencyUs
  ├─ readingsBuffer (ArrayDeque, cap 50) accumulates JSON readings
  ├─ flushBuffer() every BATCH_INTERVAL_MS = 5_000 ms (also on off-body / sensor flush)
  └─ sendBatch() → Wearable MessageClient → path "/lifebalance/sensors"
        │
        ▼
Phone app (android/app/.../WearMessageListenerService.kt)
  ├─ onMessageReceived → WearDataBus.emit(jsonString)
  ├─ WearDataBus throttles to EventChannel (EMIT_THROTTLE_MS = 5s)
  └─ MainActivity.kt: EventChannel "com.example.lifebalance/wearable_sensors"
        │
        ▼
Dart (lib/services/wearable_communication_service.dart)
  └─ accelerometerStream: expand(batch) → individual AccelerometerData
        │
        ▼
FogEngine (lib/core/fog_engine.dart)
  ├─ 30s Timer → _analyzeWindow() → variance < 0.05 ⇒ idle
  ├─ 90 idle windows (45 min) ⇒ alert → local notification
  └─ SecureDatabaseService: insertActivitySession / logAlert (LOCAL ONLY)
        │
        ▼
Cloud: NOT YET IMPLEMENTED. SyncService.syncLocalDataToCloud() is an empty
placeholder stub (pending team API). DB tables already have synced_to_cloud column.
```

## 5. Key Components

### 5.1 Authentication Flow & Network (`features/auth`, `core/network`)
- **Strict Rule**: No mocked data. All authentication and profile data must be fetched from the live API.
- **Providers**: `loginProvider`, `registerProvider`, `forgotPasswordProvider`, `profileProvider` manage state and coordinate with Use Cases (`LoginUseCase`, `RegisterUseCase`, `ForgotPasswordUseCase`, `GetProfileUseCase`, `LogoutUseCase`).
- **API clients** (3 independent Dio instances in `api_client.dart`):
  - `apiClientProvider` → Auth service (`API_URL`, default `https://lifebalance-auth-service.onrender.com/api/v1`)
  - `dashboardApiClientProvider` → Dashboard service (`DASHBOARD_API_URL`, default `https://lifebalance-dashboard-service.onrender.com/api/v1`)
  - `notificationsApiClientProvider` → Notifications service (`NOTIFICATIONS_API_URL`, default `https://lifebalance-notifications-api.onrender.com/api/v1`)
- **Network Resilience**: `RetryWithBackoffInterceptor` retries 500/502/503/429 and network timeouts, max 3 attempts, linear backoff. TLS/certificate failures and cancellations are NEVER retried.
- **Auth Header**: Bearer token attached via interceptor from `TokenService`; on 401 tokens are cleared.
- **Certificate Pinning**: `certificate_pinning.dart` enforces pinning using `PINNED_CERT_SHA256` from env. Fail-closed (no pins → reject). Disabled in debug/profile for development.

### 5.2 Background Service (`services/background_service.dart`)
- Uses `flutter_background_service` to run even when the app is killed.
- Foreground mode with persistent notification (channel `inactivity_alert_channel`, id 888).
- `onStart` (isolate): initializes `NotificationService`, starts `FogEngine`, starts `WatchService` periodic sync, and adapts polling (5 min active / 30 min idle based on last sensor data).

### 5.3 FogEngine (`core/fog_engine.dart`)
- **Core Algorithm**: Monitors accelerometer data to detect user inactivity.
- **Mechanism**:
  - Collects acceleration vector magnitudes (sqrt(x²+y²+z²)), discards non-finite samples.
  - Groups data into **30-second analysis windows** (`Timer.periodic`).
  - Calculates the statistical variance of the magnitudes in the window.
  - If variance < 0.05, the window is marked as "idle".
  - If 90 consecutive idle windows occur (45 minutes), it triggers an alert.
- **Alert Trigger**: Logs the alert to the secure database (`alerts_log`) and fires a local notification.
- NOTE: `lib/services/fog_engine.dart` is a DEAD abstract `IFogEngine` stub — do not use it; the real engine is `lib/core/fog_engine.dart`.

### 5.4 Wearable Communication (`services/wearable_communication_service.dart`)
- `EventChannel('com.example.lifebalance/wearable_sensors')` receives JSON batches from the watch.
- `accelerometerStream`: decodes each batch (list of `{x, y, z, timestamp}`) into individual `AccelerometerData` via `expand()`.
- `accelerometerStreamThrottled`: RxDart `throttleTime(5s)` variant for UI.

### 5.5 Watch / Wearable Integration (`services/watch_service.dart`)
- `WatchService` listens to `accelerometerStream` and builds `VitalSign` records (heart_rate/hrv/spo2/steps are currently **placeholders = 0**).
- `startPeriodicSync({interval = 5 min})`: inserts latest `VitalSign` into `SecureDatabaseService` (delegates low-power persistence). Adaptive interval handled by `BackgroundService` (5 min active / 30 min idle).
- `services/sync_service.dart`: `SyncService` orchestrates Health Connect → local DB; `performSync()` every 5 min. **`SyncService` is currently NOT instantiated anywhere.**

### 5.6 Secure Local Database (`data/datasources/secure_database_service.dart`)
- Singleton `SecureDatabaseService.instance`, encrypted with `sqflite_sqlcipher` using an AES-256 key from `EncryptionService` (stored in `FlutterSecureStorage`).
- Tables:
  - `activity_sessions(id, start_time UNIQUE, end_time, type, duration_minutes, synced_to_cloud DEFAULT 0)`
  - `vital_signs(id, timestamp UNIQUE, heart_rate, hrv, spo2, steps, synced_to_cloud DEFAULT 0)`
  - `alerts_log(id, timestamp, type, duration_minutes, acknowledged)`
- Query helpers: counts for today (sessions/vitals/alerts), last session, sessions per day, all sessions, sessions for last N days.

### 5.7 Cloud Sync (PLACEHOLDER — do not assume it works)
- `lib/services/sync_service.dart:62-68` — `syncLocalDataToCloud()` is an **empty stub** with a TODO for Firebase.
- The `synced_to_cloud` column exists in the schema but no code reads or flips it.
- **Status**: The team's API is not deployed yet; cloud batching will be implemented later. Do not implement or mock cloud uploads until the backend exists.

## 6. Security
1. **Jailbreak/Root Detection**: `main.dart` calls `FlutterJailbreakDetection.jailbroken`; if compromised → `exit(0)` immediately.
2. **Certificate Pinning**: fail-closed TLS validation in release; pins from `PINNED_CERT_SHA256` env var (hex, comma-separated). Generate pin with `openssl` (see `certificate_pinning.dart` header).
3. **Encrypted Storage**: all sensitive data via `SecureDatabaseService` (SQLCipher) or `FlutterSecureStorage` (tokens via `TokenService`).
4. **Biometrics**: `local_auth` on `BiometricProfileScreen`.
5. **No HTTP downgrade ever**: retry interceptor never retries TLS errors and never degrades the channel.

## 7. Environment Variables (`flutter_dotenv`)
- Loaded in `main.dart` via `--dart-define=ENV_FILE` (default `.env.development`).
- `API_URL`, `DASHBOARD_API_URL`, `NOTIFICATIONS_API_URL`, `PINNED_CERT_SHA256`.
- Files `.env.development` and `.env.production` are committed to the repo and registered as assets in `pubspec.yaml`.

## 8. Known Caveats & Legacy Code
1. **Duplicate auth features**: `features/auth/` (current, Clean Architecture) vs `features/authentication/` (legacy screens: splash/login/register). `app_router.dart` currently imports the legacy `SplashScreen` and the new auth screens.
2. **Two FogEngines**: `lib/core/fog_engine.dart` (real, used by `BackgroundService` and `fog_providers.dart`) vs `lib/services/fog_engine.dart` (dead `IFogEngine` stub).
3. **`MockAuthDataSource`** exists in `features/auth/data/datasources/auth_datasource.dart` but is NOT used by the live repository (violates the No Mocks rule if reactivated).
4. **Placeholders**: `WatchService` vital signs (heart rate, HRV, SpO2, steps) are hardcoded to 0 pending Health Connect integration.
5. **Firebase dependencies** (`firebase_auth`, `cloud_firestore`) are declared but not wired into the app flow yet.
6. **Cloud upload is NOT implemented** (see 5.7).

## 9. Coding Guidelines & AI Agent Rules
1. **No Mocks**: Do not use simulated/mocked data for API calls. If an endpoint fails, debug and fix the implementation or API structure.
2. **State Management**: Always use Riverpod (`ConsumerWidget`, `ConsumerStatefulWidget`, `ref.watch`, `ref.read`). Never use `setState` for global or complex business logic.
3. **Clean Architecture**: Respect the boundaries. UI (Presentation) -> Providers -> Use Cases (Domain) -> Repository Interfaces (Domain) -> Repository Implementation (Data) -> Data Sources (API/DB).
4. **Permissions**: Always check and request permissions (`permission_handler`) before accessing sensors, bluetooth, or background execution (`Notification`, `ignoreBatteryOptimizations`, `sensors`, bluetooth, etc.).
5. **Security First**:
   - Ensure sensitive data (tokens, passwords, health data) is stored using `SecureDatabaseService` or `FlutterSecureStorage`.
   - Never disable Jailbreak detection or Certificate Pinning in production code.
6. **Environment Variables**: Use `flutter_dotenv`. Secrets and config change between `.env.development` and `.env.production`.
7. **Do not implement Cloud sync**: The backend API for fog/vitals upload is not deployed yet. Leave `syncLocalDataToCloud()` as-is until the team provides the endpoint.
