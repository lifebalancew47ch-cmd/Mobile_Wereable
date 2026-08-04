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
- **Notifications**: `flutter_local_notifications`, `firebase_messaging` (FCM push)
- **Firebase**: `firebase_core`, `firebase_crashlytics`, `firebase_messaging` (integrado); `firebase_auth`, `cloud_firestore` (dependencies installed; intended for future Cloud layer)
- **Dev / Tooling**: `flutter_lints`, `mocktail`, `flutter_launcher_icons`

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
│   ├── authentication/  # LEGACY: solo SplashScreen (token check) - ver caveats
│   ├── admin/       # Admin summary
│   ├── analytics/   # Performance analysis + heatmap
│   ├── dashboard/   # Main app UI after login (executive dashboard)
│   ├── fog/         # Fog status screen + providers
│   ├── gamification/ # Gamification screen (logros y medallas)
│   ├── notifications/# Notifications UI and logic
│   ├── profile/     # User profile, biometric, activity history
│   ├── settings/    # Settings + alert configuration (persistida localmente)
│   ├── support/     # FAQ + explanation screen
│   └── wearable/    # Wearable sync UI (device scan/manage)
├── models/           # Shared models (fog_state, vital_sign)
├── services/         # Platform services (BackgroundService, WatchService, SyncService, NotificationService, WearableCommunicationService, SensorService, BluetoothService, OfflineSyncService, ConnectivityMonitor, DeviceIdentityService, DeviceRegistrationService, LocationService)
├── shared/widgets/   # main_navigation_shell (bottom nav)
└── main.dart         # Entry point: env vars, jailbreak check, DB init, permissions, background service
```

### Feature Module Structure (Clean Architecture)
Inside each feature (e.g., `features/auth/`), the structure is:
- **`data/`**: API Services (`Datasources`), Repositories Implementation.
- **`domain/`**: Entities (Models), abstract Repositories, Use Cases.
- **`presentation/`**: Riverpod Providers (State Notifiers), Screens, and Widgets.

### Navigation (go_router)
- Top-level routes: `/splash`, `/login`, `/auth/register`, `/auth/forgot-password`, `/fog`
- StatefulShellRoute with 5 tabs: `/dashboard` (notifications subroute), `/analytics` (heatmap subroute), `/admin` (accesible vía FAB `+`), `/support` (video subroute), `/profile` (biometric, gamification, settings, history, wearable-scan, wearable-manage subroutes)
- **Sesión**: `app_router.dart` usa `redirect` + `refreshListenable` (escucha `sessionChangeNotifier` de `token_service.dart`) para expulsar a `/login` cuando el token expira o en un 401. `hasValidToken()` verifica el claim `exp` del JWT.
- Las pantallas de reloj (`/watch`, `/watch/alert`, `/watch/progress`) fueron ELIMINADAS del móvil: la UI del wearable vive en la app Wear OS nativa (`android/wear`), donde `MainActivity.kt` implementa un dashboard propio que analiza localmente la varianza del acelerómetro en ventanas de 30s (mismo criterio que el FogEngine) y muestra estado Activo/Inactivo, minutos inactivos y alerta de sedentarismo a los 45 min (90 ventanas), con botón "Pausa activa" que reinicia el contador local.

## 4. Data Flow: Wearable → Fog → Local DB → Cloud

```
Wear OS (android/wear/.../SensorService.kt)
  ├─ Hardware batching: accelerometer/gyroscope/stepCounter/heartRate
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
  ├─ accelerometerStream: expand(batch) → individual AccelerometerData
  └─ sensorStream: expand(batch) → WearableSensorSample (accel+gyro+steps+HR)
        │
        ▼
FogEngine (lib/core/fog_engine.dart)
  ├─ 30s Timer → _analyzeWindow() → variance < 0.05 ⇒ idle (variance via `compute`)
  ├─ ClinicalStateClassifier: reposo/sueño verificados pausan o congelan el timer
  ├─ 90 idle windows (45 min) ⇒ alert → local notification + GPS ping
  └─ SecureDatabaseService: insertActivitySession / logAlert / insertActiveBreak
        │
        ▼
Secure SQLite (activity_sessions, vital_signs, alerts_log, active_breaks)
  └─ columnas synced_to_cloud marcan pendientes de envío
        │
        ▼
OfflineSyncService (lib/services/offline_sync_service.dart)
  ├─ flush cada 15 min (+ en reconexión) con cola SQLite offline-first
  ├─ DeviceRegistrationService: registerDevice (FCM no-op seguro)
  └─ POST /api/v1/ingestion/sync (ClientBatchId, DeviceId, VitalSigns,
        ActivitySessions, Alerts) → marca synced_to_cloud=1
```

## 4.5 Onboarding & UI/UX (Splash, Welcome, Wearable)

### 4.5.1 Splash con video
- Al abrir la app se reproduce `assets/videos/SplashScreenLB.mp4` a pantalla completa (`video_player`), con fondo negro y `FittedBox(BoxFit.cover)`.
- `lib/features/authentication/presentation/splash_screen.dart`: al terminar el video (listener de `VideoPlayerController`) navega a `/dashboard` si hay token válido o a `/landing` si no. Fallback a navegación si el video falla (nunca bloquear al usuario).

### 4.5.2 Pantalla de bienvenida (`/landing`, `features/authentication/presentation/landing_screen.dart`)
Diseño mobile-first (NO página web) previa al login para usuarios sin sesión:
- **Saludo según hora**: "Buenos días / Buenas tardes / Buenas noches" (según `DateTime.now().hour`).
- **Cabecera de marca**: nombre "LifeBalance" centrado arriba y logo circular debajo, animados con `FadeTransition` + `ScaleTransition` (curva `easeOutBack`) al entrar.
- **Propuesta de valor**: card corta y directa con gradiente verde y sensación de calma.
- **Carrusel de beneficios**: `PageView.builder` con `viewportFraction: 0.82` (la tarjeta siguiente queda recortada como pista de que hay más contenido), indicador de puntos animado (`AnimatedContainer`) y texto conciso. Cada tarjeta tiene una **ilustración vectorial** propia (corredor+cronómetro, corazón+reloj, gráfica+alerta) en lugar de iconos genéricos.
- **Fondo orgánico**: `_OrganicBackground` con círculos difuminados que rompen la monotonía del blanco (fluidez / bienestar).
- **Jerarquía de acciones**: "Iniciar sesión" = botón primario sólido; "Crear cuenta en la web" = botón outline secundario que abre `https://lifebalance-adv3.onrender.com/register` con `url_launcher` (el registro ES SOLO WEB; no hay pantalla de registro en la app).
- **Rutas públicas** en `app_router.dart`: `/splash`, `/landing`, `/login`, `/auth/forgot-password`. El login tiene flecha de regreso al landing.

### 4.5.3 Estilo visual replicado en el reloj (`android/wear`)
- El dashboard nativo Wear OS (`MainActivity.kt` + `activity_main.xml`) usa la misma paleta LifeBalance (verde `#3E6F58`, menta `#E9F1EC`, verde oscuro `#0F1512`) y tarjetas con bordes redondeados, en coherencia con el onboarding del móvil.

## 5. Key Components

### 5.1 Authentication Flow & Network (`features/auth`, `core/network`)
- **Strict Rule**: No mocked data. All authentication and profile data must be fetched from the live API.
- **Providers**: `loginProvider`, `registerProvider`, `forgotPasswordProvider`, `profileProvider` manage state and coordinate with Use Cases (`LoginUseCase`, `RegisterUseCase`, `ForgotPasswordUseCase`, `GetProfileUseCase`, `LogoutUseCase`).
- **API clients** (8 independent Dio instances in `api_client.dart`):
  - `apiClientProvider` → Auth service (`API_URL`, default `https://lifebalance-auth-service.onrender.com/api/v1`)
  - `dashboardApiClientProvider` → Dashboard service (`DASHBOARD_API_URL`, default `https://lifebalance-dashboard-service.onrender.com/api/v1`)
  - `notificationsApiClientProvider` → Notifications service (`NOTIFICATIONS_API_URL`, default `https://lifebalance-notifications-api.onrender.com/api/v1`)
  - `ingestionApiClientProvider` → Ingestion service (`INGESTION_API_URL`, default `https://ingestion-service-fouo.onrender.com/api/v1`)
  - `gamificationApiClientProvider` → Gamification service (`GAMIFICATION_API_URL`, default `https://gamification-service-9o3z.onrender.com/api/v1`)
  - `sedentaryApiClientProvider` → Sedentary engine (`SEDENTARY_API_URL`, default `https://sedentary-engine-service.onrender.com/api/v1`)
  - `medicalApiClientProvider` → Medical service (`MEDICAL_API_URL`, default `https://medical-service-hb0v.onrender.com/api/v1`)
  - `mlApiClientProvider` → ML prediction (`ML_API_URL`, default `https://ml-prediction-service-0sqa.onrender.com/api/v1`)
- All clients are built with `buildSecureDio(...)` (non-Riverpod factory) which applies pinning, `RetryWithBackoffInterceptor` and the Bearer token interceptor. URLs for the background isolate come from `_urlFromEnv` (env not available off-isolate → deployed defaults).
- **Network Resilience**: `RetryWithBackoffInterceptor` retries 500/502/503/429 and network timeouts, max 3 attempts, linear backoff. TLS/certificate failures and cancellations are NEVER retried.
- **Auth Header**: Bearer token attached via interceptor from `TokenService`; on 401 tokens are cleared (`sessionChangeNotifier` dispara un refresh del router que redirige a `/login`).
- **Recordar sesión**: el login guarda solo el email (NUNCA la contraseña) en `FlutterSecureStorage`.
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
  - Calculates the statistical variance of the magnitudes in the window via `compute` (Isolate).
  - If variance < 0.05, the window is marked as "idle".
  - If 90 consecutive idle windows occur (45 minutes), it triggers an alert (and resets `_inactiveWindows`).
  - El umbral es **configurable** (`setAlertThreshold(minutes)`) y se sincroniza con la configuración de alertas persistida (`AlertSettings`).
- **Clinical State Filter** (`core/filters/clinical_state_classifier.dart`): `ClinicalStateClassifier` ingiere muestras (`feedClinicalSample`) e infiere reposo/sueño verificados:
  - **Reposo verificado**: FC 60-100 lpm + steady-state sentado 5-10 min o recostado 20-30 min (estado `reposo`). Pausa el temporizador de sedentarismo.
  - **Sueño**: FC < 60 con HRV ≥ 30 y orientación horizontal prolongada (estado `sueño`). Congela el temporizador.
  - Exposición: `fog_state.dart` (`ClinicalState`, `clinicalState`, `reposoVerificado`, `restMinutes`).
- **Alert Trigger**: Logs the alert to the secure database (`alerts_log`) and fires a local notification + GPS ping (`LocationService`).
- **Configuración de alertas**: `features/settings/` persiste en `SharedPreferences` el intervalo (30/45/60/90 min), horario de operación, días activos, notificaciones críticas y sonido (`AlertSettingsStore`).
- NOTE: `lib/services/fog_engine.dart` is a DEAD abstract `IFogEngine` stub — do not use it; the real engine is `lib/core/fog_engine.dart`.

### 5.4 Wearable Communication (`services/wearable_communication_service.dart`)
- `EventChannel('com.example.lifebalance/wearable_sensors')` receives JSON batches from the watch.
- `accelerometerStream`: decodes each batch (list of `{x, y, z, timestamp}`) into individual `AccelerometerData` via `expand()`.
- `accelerometerStreamThrottled`: RxDart `throttleTime(5s)` variant for UI.
- `sensorStream` / `sensorStreamThrottled`: decode batches into `WearableSensorSample` (accel + gyro + steps + heartRate) for the clinical classifier and vital-sign persistence.

### 5.5 Watch / Wearable Integration (`services/watch_service.dart`)
- `WatchService` listens to `accelerometerStream` and builds `VitalSign` records (heart_rate/hrv/spo2/steps are currently **placeholders = 0**).
- `startPeriodicSync({interval = 5 min})`: inserts latest `VitalSign` into `SecureDatabaseService` (delegates low-power persistence). Adaptive interval handled by `BackgroundService` (5 min active / 30 min idle).
- `services/sync_service.dart`: `SyncService` orchestrates Health Connect → local DB; `performSync()` every 5 min. **`SyncService` is currently NOT instantiated anywhere.**

### 5.6 Secure Local Database (`data/datasources/secure_database_service.dart`)
- Singleton `SecureDatabaseService.instance`, encrypted with `sqflite_sqlcipher` using an AES-256 key from `EncryptionService` (stored in `FlutterSecureStorage`).
- Tables:
  - `activity_sessions(id, start_time UNIQUE, end_time, type, duration_minutes, synced_to_cloud DEFAULT 0)`
  - `vital_signs(id, timestamp UNIQUE, heart_rate, hrv, spo2, steps, synced_to_cloud DEFAULT 0)`
  - `alerts_log(id, timestamp, type, duration_minutes, acknowledged, synced_to_cloud DEFAULT 0)`
  - `active_breaks(id, timestamp, type, steps, duration_minutes, points, synced_to_cloud DEFAULT 0)`
- Query helpers: counts for today (sessions/vitals/alerts), last session, sessions per day, all sessions, sessions for last N days, plus `getUnsynced*` / `mark*Synced` helpers for the offline-first sync queue.

### 5.7 Cloud Sync (IMPLEMENTED)
- `lib/services/offline_sync_service.dart`: offline-first queue backed by SQLite (`synced_to_cloud` flags). Flushes pending batches every 15 min (`Timer.periodic`) and on connectivity restore, then `POST /api/v1/ingestion/sync` with `ClientBatchId`, `DeviceId`, `VitalSigns`, `ActivitySessions`, `Alerts`. On success it marks rows `synced_to_cloud=1`; failures remain queued.
- `lib/features/ingestion/data/ingestion_api_service.dart` implements the real backend contract (`SyncBatchRequest`/`SyncBatchResponse`) from `backapi-main` (IngestionController).
- `lib/services/device_identity_service.dart`: stable per-install UUID. `lib/services/device_registration_service.dart`: `registerDevice` via notifications API + re-registro en `onTokenRefresh`. El token lo provee `FirebaseMessagingFcmTokenProvider` (firebase_messaging); sin `google-services.json` degrada a `null` → no-op seguro.
- `lib/services/connectivity_monitor.dart`: connectivity status stream to gate sync. `lib/services/location_service.dart`: GPS ping on alert.
- **Gamification**: `lib/features/gamification/data/gamification_api_service.dart` (profile/events/rewards) and `lib/features/gamification/data/active_break_service.dart` (rutinas Tipo A: 2 min → 50 pts; Tipo B: 200 pasos → 100 pts, persistidas como `active_breaks`).

### 5.8 Wearable Telemetry, FogEngine & UI Polish (Recent Updates)
- **Wearable Communication Singleton**: `WearableCommunicationService` uses a singleton pattern for `EventChannel` listening with safe JSON parsing and a 15-second disconnection watchdog timer in `WearableNotifier`.
- **Table Off-Body Guard & Active Sessions**: `FogEngine` guards against false idle alerts when the watch is on a table (`variance < 0.0001` with no HR) and records active movement sessions (`type: 'active'`) into SQLite (`activity_sessions`), populating active movement stats on the dashboard.
- **Render Cold-Start & Auth Handling**: Increased Dio `connectTimeout` & `receiveTimeout` to 45 seconds to accommodate Render free-tier cold starts. `SyncStatusScreen` validates session JWT before sync with clear UI feedback.
- **Navigation & UI Polish**: `MainNavigationShell` redesigned using `BottomAppBar` with `CircularNotchedRectangle` for seamless FAB integration. Fixed card vertical overflow errors and removed mock avatar images.

## 6. Security
1. **Jailbreak/Root Detection**: `main.dart` calls `FlutterJailbreakDetection.jailbroken`; if compromised → `exit(0)` immediately.
2. **Certificate Pinning**: fail-closed TLS validation in release; pins from `PINNED_CERT_SHA256` env var (hex, comma-separated). Generate pin with `openssl` (see `certificate_pinning.dart` header).
3. **Encrypted Storage**: all sensitive data via `SecureDatabaseService` (SQLCipher) or `FlutterSecureStorage` (tokens via `TokenService`).
4. **Biometrics**: `local_auth` on `BiometricProfileScreen`.
5. **No HTTP downgrade ever**: retry interceptor never retries TLS errors and never degrades the channel.

## 7. Environment Variables (`flutter_dotenv`)
- Loaded in `main.dart` via `--dart-define=ENV_FILE` (default `.env.development`).
- `API_URL`, `DASHBOARD_API_URL`, `NOTIFICATIONS_API_URL`, `INGESTION_API_URL`, `GAMIFICATION_API_URL`, `SEDENTARY_API_URL`, `MEDICAL_API_URL`, `ML_API_URL`, `API_GATEWAY_URL`, `PINNED_CERT_SHA256`.
- Files `.env.development` and `.env.production` are **NOT committed** (gitignored via `.env.*`). They are registered as assets in `pubspec.yaml`:88-91, so any Flutter build/Gradle task that bundles assets REQUIRES the files to exist. Each DevOps CI job creates empty placeholders (`touch .env.development .env.production`); the app falls back to defaults via `?? onClick` and `_envBaseUrl`/`dotenv.isInitialized` guards when loaded from an empty env.

## 8. Known Caveats & Legacy Code
1. **Auth features**: `features/auth/` (current, Clean Architecture) es la única fuente de login/registro. `features/authentication/` conserva solo `SplashScreen` (chequeo de token); las pantallas login/register/forgot legacy duplicadas fueron ELIMINADAS.
2. **Two FogEngines**: `lib/core/fog_engine.dart` (real, used by `BackgroundService` and `fog_providers.dart`) vs `lib/services/fog_engine.dart` (dead `IFogEngine` stub).
3. **`MockAuthDataSource`** exists in `features/auth/data/datasources/auth_datasource.dart` but is NOT used by the live repository (violates the No Mocks rule if reactivated).
4. **Placeholders**: `WatchService` vital signs (heart rate, HRV, SpO2, steps) are hardcoded to 0 pending Health Connect integration.
5. **Firebase dependencies** (`firebase_auth`, `cloud_firestore`) are declared but not wired into the app flow yet.
6. **Cloud sync IS implemented** (see 5.7) — replaced the old placeholder. **FCM push** está integrado y activado: `firebase_messaging` (`FirebaseMessagingFcmTokenProvider` + re-registro en `onTokenRefresh`), `firebase_core.initializeApp()` en `main.dart` (no-bloqueante), y el plugin de Gradle `google-services` se aplica condicionalmente (solo si `android/app/google-services.json` existe, package `com.example.lifebalance`). `google-services.json` está en `.gitignore`; el APK ya construye con él.

## 9. Coding Guidelines & AI Agent Rules
1. **No Mocks**: Do not use simulated/mocked data for API calls. If an endpoint fails, debug and fix the implementation or API structure.
2. **State Management**: Always use Riverpod (`ConsumerWidget`, `ConsumerStatefulWidget`, `ref.watch`, `ref.read`). Never use `setState` for global or complex business logic.
3. **Clean Architecture**: Respect the boundaries. UI (Presentation) -> Providers -> Use Cases (Domain) -> Repository Interfaces (Domain) -> Repository Implementation (Data) -> Data Sources (API/DB).
4. **Permissions**: Always check and request permissions (`permission_handler`) before accessing sensors, bluetooth, or background execution (`Notification`, `ignoreBatteryOptimizations`, `sensors`, bluetooth, etc.).
5. **Security First**:
   - Ensure sensitive data (tokens, passwords, health data) is stored using `SecureDatabaseService` or `FlutterSecureStorage`.
   - Never disable Jailbreak detection or Certificate Pinning in production code.
6. **Environment Variables**: Use `flutter_dotenv`. Secrets and config change between `.env.development` and `.env.production`.
7. **Cloud sync is implemented**: The offline-first sync queue (`OfflineSyncService`) posts batches to `POST /api/v1/ingestion/sync` using the real `backapi-main` contract. Do not stub or mock it; keep the `synced_to_cloud` flags in sync with actual uploads.
