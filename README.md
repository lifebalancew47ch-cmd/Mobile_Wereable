# LifeBalance Mobile App

LifeBalance is a comprehensive health and activity tracking application built with Flutter. It monitors user movement and inactivity using device sensors and wearable integration, providing timely alerts to prevent prolonged sedentary behavior. It follows a **Fog Computing** architecture: the phone acts as a Fog node that analyzes sensor data locally and persists results to an encrypted database.

## 🌟 Features

*   **Activity Monitoring (FogEngine):** Analyzes accelerometer magnitude variance in 30-second windows. Triggers alerts after 90 consecutive idle windows (45 minutes of inactivity). Includes a **clinical-state filter** that pauses/freezes the timer during verified rest and sleep.
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

### Data Flow: Watch → Fog → Local DB → Cloud

```
Wear OS (SensorService.kt)
  └─ 5s hardware batching (accel + gyro + steps + HR) → Wearable MessageClient → "/lifebalance/sensors"
        │
        ▼
Phone (WearMessageListenerService → WearDataBus → EventChannel)
        │
        ▼
Dart: wearable_communication_service.dart (batch decode)
        │
        ▼
FogEngine (30s windows, variance, clinical-state filter, 90 windows = alert)
        │
        ▼
Secure SQLite (activity_sessions, vital_signs, alerts_log, active_breaks)
        │
        ▼
OfflineSyncService (15-min flush, offline-first queue, reconnection)
        │
        ▼
POST /api/v1/ingestion/sync  (ClientBatchId, VitalSigns, ActivitySessions, Alerts)
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
*   **Notifications:** `flutter_local_notifications`, `firebase_messaging`
*   **Firebase:** `firebase_core`, `firebase_crashlytics`, `firebase_auth`, `cloud_firestore` (installed; auth/firestore not yet wired)
*   **Dev / Tooling:** `flutter_lints`, `mocktail`, `flutter_launcher_icons`

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
    Ensure you have the environment files (`.env.development` and `.env.production`) at the root of the project. These files define the API URLs (`API_URL`, `DASHBOARD_API_URL`, `NOTIFICATIONS_API_URL`, etc.) and the `PINNED_CERT_SHA256` for certificate pinning.
4.  **Firebase (FCM push, opcional):**
    Drop your `google-services.json` (package `com.example.lifebalance`) into `android/app/`. The Google Services Gradle plugin activates automatically when the file exists; without it the app runs with local notifications only.
5.  **Run the app (Development):**
    Certificate pinning is automatically disabled in debug mode to facilitate development.
    ```bash
    flutter run
    ```
6.  **Build for Production:**
    ```bash
    flutter build apk --release
    ```

### Backend Services (Render)

The app consumes a set of independent REST microservices hosted on Render:

| Service | Env var | Default URL |
|---|---|---|
| Auth | `API_URL` | `https://lifebalance-auth-service.onrender.com/api/v1` |
| Dashboard | `DASHBOARD_API_URL` | `https://lifebalance-dashboard-service.onrender.com/api/v1` |
| Notifications | `NOTIFICATIONS_API_URL` | `https://lifebalance-notifications-api.onrender.com/api/v1` |
| Organization (SaaS) | `ORGANIZATION_API_URL` | `https://lifebalance-organization-saas.onrender.com/api/v1` |
| Administration | `ADMINISTRATION_API_URL` | `https://lifebalance-administration-service.onrender.com/api/v1` |
| API Gateway | `API_GATEWAY_URL` | `https://lifebalance-api-gateway.onrender.com/api/v1` |
| Sedentary engine | `SEDENTARY_API_URL` | `https://sedentary-engine-service.onrender.com/api/v1` |
| ML prediction | `ML_API_URL` | `https://ml-prediction-service-0sqa.onrender.com/api/v1` |
| Gamification | `GAMIFICATION_API_URL` | `https://gamification-service-9o3z.onrender.com/api/v1` |
| Medical | `MEDICAL_API_URL` | `https://medical-service-hb0v.onrender.com/api/v1` |
| Ingestion | `INGESTION_API_URL` | `https://ingestion-service-fouo.onrender.com/api/v1` |

## 🔒 Security Notes

*   **Certificate Pinning:** In release builds, the app will reject all network connections if the `PINNED_CERT_SHA256` in `.env.production` does not match the server's TLS certificate. Ensure this hash is updated when the server's certificate rotates.
*   **Root Detection:** The app will exit immediately on launch if it detects a rooted or jailbroken environment.
*   **Network Resilience:** Retries (max 3, linear backoff) only on 500/502/503/429 and network timeouts. TLS/certificate failures are never retried and the channel is never downgraded.

## ⚠️ Current Status & Roadmap

*   **Implemented:** Watch → phone sensor streaming (accel/gyro/steps/HR), FogEngine inactivity detection with clinical-state filter, encrypted local persistence, auth/dashboard/notifications APIs, background monitoring, biometrics, offline-first cloud sync to `POST /api/v1/ingestion/sync`, device registration + FCM push (activado con `android/app/google-services.json`), active-break gamification scoring, and API clients for the sedentary, ML, gamification, medical and ingestion microservices.
*   **Pending:** wiring `firebase_auth`/`cloud_firestore` into the app flow, and full UI for leaderboards/rewards against the new gamification endpoints.

## 📜 License

[Insert License Here]
