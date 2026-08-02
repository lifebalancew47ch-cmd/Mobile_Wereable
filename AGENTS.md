# LifeBalance - Mobile App (Flutter)
**AI Agent Context File**

This document provides a comprehensive overview of the LifeBalance mobile application architecture, stack, and current implementation details to help AI agents quickly onboard and contribute to the project.

## 1. Project Overview
- **Name**: LifeBalance
- **Platform**: Cross-platform mobile (primarily Android) built with Flutter.
- **Core Purpose**: A health and activity tracking application that monitors user movement (specifically inactivity) using device sensors and/or wearable integration, sending alerts when the user has been sedentary for too long (e.g., 45 minutes).
- **Backend API**: The app communicates with live REST APIs hosted on Render, communicating securely via HTTPS with Certificate Pinning.

## 2. Tech Stack & Dependencies
- **UI Framework**: Flutter (Dart 3.x)
- **State Management**: Riverpod (`flutter_riverpod`)
- **Routing**: `go_router`
- **Network & API**: `dio` with custom `RetryWithBackoffInterceptor` and strict SSL/TLS Certificate Pinning (`IOHttpClientAdapter`).
- **Local Storage / DB**: 
  - `sqflite_sqlcipher` (Encrypted SQLite database via `SecureDatabaseService`)
  - `flutter_secure_storage` (Secure key-value storage for credentials/tokens)
- **Background Execution**: `flutter_background_service` & `workmanager`
- **Sensors & Bluetooth**: `sensors_plus`, `flutter_blue_plus`
- **Security**: 
  - `flutter_jailbreak_detection` (app exits immediately if rooted/jailbroken)
  - `certificate_pinning.dart` (Fail-closed strict certificate pinning in Release mode).
- **Notifications**: `flutter_local_notifications`

## 3. Architecture
The project strictly follows **Clean Architecture** patterns separated by features.

### Directory Structure
```
lib/
├── core/             # Shared utilities, router config (app_router.dart), theme, fog_engine, security, network
├── data/             # Global data sources (e.g., secure_database_service.dart)
├── features/         # Feature-based modules (Clean Architecture)
│   ├── auth/         # Authentication Feature
│   ├── dashboard/    # Main app UI after login
│   ├── profile/      # User profile management
│   ├── notifications/# Notifications UI and logic
│   ├── wearable/     # Wearable sync UI
│   └── ...           # Other features (analytics, fog, settings, etc.)
├── models/           # Shared models
├── services/         # Device/Platform services (BackgroundService, WatchService, Notifications)
└── main.dart         # Entry point, initializes DB, env vars, permissions, and security checks.
```

### Feature Module Structure (Clean Architecture)
Inside each feature (e.g., `features/auth/`), the structure is:
- **`data/`**: API Services (`Datasources`), Repositories Implementation.
- **`domain/`**: Entities (Models), abstract Repositories, Use Cases.
- **`presentation/`**: Riverpod Providers (State Notifiers), Screens, and Widgets.

## 4. Key Components

### 4.1 Authentication Flow & Network (`features/auth`, `core/network`)
- **Strict Rule**: No mocked data. All authentication and profile data must be fetched from the live API.
- **Providers**: `loginProvider`, `registerProvider`, `forgotPasswordProvider` manage state and coordinate with Use Cases.
- **Network Resilience**: `api_client.dart` uses a `RetryWithBackoffInterceptor` for 500/502/503/429 errors.
- **Certificate Pinning**: `certificate_pinning.dart` enforces pinning using `PINNED_CERT_SHA256` from `.env.production`. It is disabled in debug/profile modes for easier development but fails closed in release.

### 4.2 Background Service (`services/background_service.dart`)
- Uses `flutter_background_service` to run continuously even when the app is killed.
- Manages the **FogEngine** and **WatchService**.
- Posts a persistent foreground notification to keep the OS from killing the process.

### 4.3 FogEngine (`core/fog_engine.dart`)
- **Core Algorithm**: Monitors accelerometer data (`sensors_plus`) to detect user inactivity.
- **Mechanism**:
  - Collects acceleration vector magnitudes.
  - Groups data into **30-second analysis windows**.
  - Calculates the statistical variance of the magnitudes in the window.
  - If variance < 0.05, the window is marked as "idle".
  - If 90 consecutive idle windows occur (45 minutes), it triggers an alert.
- **Alert Trigger**: Logs the alert to the secure database and fires a local notification.

### 4.4 Watch / Wearable Integration (`services/watch_service.dart`)
- Synchronizes data periodically (every 5 mins if active, every 30 mins if inactive).
- Communicates via `flutter_blue_plus`.

## 5. Coding Guidelines & AI Agent Rules
1. **No Mocks**: Do not use simulated/mocked data for API calls. If an endpoint fails, debug and fix the implementation or API structure.
2. **State Management**: Always use Riverpod (`ConsumerWidget`, `ConsumerStatefulWidget`, `ref.watch`, `ref.read`). Never use `setState` for global or complex business logic.
3. **Clean Architecture**: Respect the boundaries. UI (Presentation) -> Providers -> Use Cases (Domain) -> Repository Interfaces (Domain) -> Repository Implementation (Data) -> Data Sources (API/DB).
4. **Permissions**: Always check and request permissions (`PermissionHandler`) before accessing sensors, bluetooth, or background execution.
5. **Security First**: 
   - Ensure sensitive data (tokens, passwords, health data) is stored using `SecureDatabaseService` or `FlutterSecureStorage`.
   - Never disable Jailbreak detection or Certificate Pinning in production code.
6. **Environment Variables**: Use `flutter_dotenv`. Secrets and config change between `.env.development` and `.env.production`.
