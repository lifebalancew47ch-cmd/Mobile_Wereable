# LifeBalance Mobile App

LifeBalance is a comprehensive health and activity tracking application built with Flutter. It monitors user movement and inactivity using device sensors and wearable integration, providing timely alerts to prevent prolonged sedentary behavior. It follows a **Fog Computing** architecture: the phone acts as a Fog node that analyzes sensor data locally and persists results to an encrypted database.

## 🌟 Features

*   **Activity Monitoring (FogEngine):** Analyzes accelerometer magnitude variance in 30-second windows. Triggers alerts after 90 consecutive idle windows (45 minutes of inactivity).
*   **Wear OS Integration:** A companion native Wear OS app (`android/wear/`) batches accelerometer readings every 5 seconds and streams them to the phone over the Wearable Data Layer.
*   **Executive Dashboard:** KPI summaries from the live Dashboard service (activity sessions, vital signs, alerts) plus admin summary, analytics (performance analysis + heatmap), FAQ/video support, and profile screens.
*   **Secure Authentication:** Live REST API (Render) for login, registration, password recovery, and profile management.
*   **Background Execution:** Continues monitoring activity even when the app is closed using a persistent foreground service (`flutter_background_service`) with adaptive polling (5 min active / 30 min idle).
*   **Biometric Authentication:** `local_auth` for profile-level security.
*   **High Security:**
    *   **Encrypted Local Data:** `sqflite_sqlcipher` (AES-256, key stored in `flutter_secure_storage`).
    *   **Jailbreak/Root Detection:** The app refuses to run on compromised devices.
    *   **Certificate Pinning:** Fail-closed SSL/TLS pinning in production to prevent Man-in-the-Middle (MitM) attacks.

## 🏗 Architecture

The application strictly adheres to **Clean Architecture** principles and is modularized by feature.

*   **Presentation Layer:** Flutter UI components, Screens, and state management using **Riverpod**.
*   **Domain Layer:** Entities, Use Cases, and Repository Interfaces containing the core business rules.
*   **Data Layer:** API Services (using `dio`), Local Database interactions, and Repository implementations.

### Data Flow: Watch → Fog → Local DB (Cloud pending)

```
Wear OS (SensorService.kt)
  └─ 5s hardware batching → Wearable MessageClient → "/lifebalance/sensors"
        │
        ▼
Phone (WearMessageListenerService → WearDataBus → EventChannel)
        │
        ▼
Dart: wearable_communication_service.dart (batch decode)
        │
        ▼
FogEngine (30s windows, variance < 0.05 = idle, 90 windows = alert)
        │
        ▼
Secure SQLite (activity_sessions, vital_signs, alerts_log)
        │
        ▼
Cloud sync (syncLocalDataToCloud): ⏳ NOT IMPLEMENTED YET — placeholder stub
```

## 🛠 Tech Stack

*   **Framework:** Flutter (Dart ^3.9.2)
*   **State Management:** Riverpod (`flutter_riverpod`)
*   **Navigation:** `go_router` (StatefulShellRoute with 5 bottom-nav tabs)
*   **Networking:** `dio` (custom retry interceptor with backoff + certificate pinning)
*   **Storage:** `sqflite_sqlcipher`, `flutter_secure_storage`, `shared_preferences`
*   **Background Tasks:** `flutter_background_service`, `workmanager`
*   **Sensors & Bluetooth:** `sensors_plus`, `flutter_blue_plus`
*   **Health Data:** `health` (Health Connect), `timezone`, `rxdart`
*   **Security:** `flutter_jailbreak_detection`, `local_auth`
*   **Notifications:** `flutter_local_notifications`
*   **Firebase:** `firebase_core`, `firebase_crashlytics`, `firebase_auth`, `cloud_firestore` (installed; not yet wired)
*   **Dev / Tooling:** `flutter_lints`, `dart_code_metrics`, `mocktail`, `flutter_launcher_icons`

## 🚀 Getting Started

### Prerequisites

*   Flutter SDK (^3.9.2)
*   Android Studio / Xcode
*   A connected physical device (Sensors, Bluetooth, and Wear OS functionality require a real device, not an emulator).

### Installation

1.  **Clone the repository.**
2.  **Install dependencies:**
    ```bash
    flutter pub get
    ```
3.  **Environment Setup:**
    Ensure you have the environment files (`.env.development` and `.env.production`) at the root of the project. These files define the API URLs (`API_URL`, `DASHBOARD_API_URL`, `NOTIFICATIONS_API_URL`) and the `PINNED_CERT_SHA256` for certificate pinning.
4.  **Run the app (Development):**
    Certificate pinning is automatically disabled in debug mode to facilitate development.
    ```bash
    flutter run
    ```
5.  **Build for Production:**
    ```bash
    flutter build apk --release
    ```

### Backend Services (Render)

The app consumes three independent REST microservices:

| Service | Env var | Default URL |
|---|---|---|
| Auth | `API_URL` | `https://lifebalance-auth-service.onrender.com/api/v1` |
| Dashboard | `DASHBOARD_API_URL` | `https://lifebalance-dashboard-service.onrender.com/api/v1` |
| Notifications | `NOTIFICATIONS_API_URL` | `https://lifebalance-notifications-api.onrender.com/api/v1` |

## 🔒 Security Notes

*   **Certificate Pinning:** In release builds, the app will reject all network connections if the `PINNED_CERT_SHA256` in `.env.production` does not match the server's TLS certificate. Ensure this hash is updated when the server's certificate rotates.
*   **Root Detection:** The app will exit immediately on launch if it detects a rooted or jailbroken environment.
*   **Network Resilience:** Retries (max 3, linear backoff) only on 500/502/503/429 and network timeouts. TLS/certificate failures are never retried and the channel is never downgraded.

## ⚠️ Current Status & Roadmap

*   **Implemented:** Watch → phone sensor streaming, FogEngine inactivity detection & alerts, encrypted local persistence, auth/dashboard/notifications APIs, background monitoring, biometrics.
*   **Not implemented:** Cloud upload (batching to the cloud). `SyncService.syncLocalDataToCloud()` is an empty placeholder; the `synced_to_cloud` column exists in the DB schema but is never flipped. This will be implemented when the team's backend API is deployed. **Do not implement or mock cloud uploads until the backend exists.**

## 📜 License

[Insert License Here]
