# LifeBalance - Mobile App (Flutter)
**AI Agent Context File**

This document provides a comprehensive overview of the LifeBalance mobile application architecture, stack, and current implementation details to help AI agents quickly onboard and contribute to the project.

## 1. Project Overview
- **Name**: LifeBalance
- **Platform**: Cross-platform mobile (primarily Android) built with Flutter.
- **Core Purpose**: A health and activity tracking application that monitors user movement (specifically inactivity) using device sensors and/or wearable integration, sending alerts when the user has been sedentary for too long (e.g., 45 minutes).
- **Backend API**: The app communicates with a live REST API hosted at `https://lifebalance-auth-service.onrender.com/api/v1` for authentication and profile management, and other microservices (`lifebalance-dashboard-service.onrender.com`, etc.).

## 2. Tech Stack & Dependencies
- **UI Framework**: Flutter (Dart)
- **State Management**: Riverpod (`flutter_riverpod`)
- **Routing**: go_router
- **Local Storage / DB**: 
  - `sqflite_sqlcipher` (Encrypted SQLite database via `SecureDatabaseService`)
  - `flutter_secure_storage` (Secure key-value storage for credentials/tokens)
- **Background Execution**: `flutter_background_service` & `workmanager`
- **Sensors & Bluetooth**: `sensors_plus`, `flutter_blue_plus`
- **Security**: `flutter_jailbreak_detection` (app exits immediately if rooted/jailbroken)
- **Notifications**: `flutter_local_notifications`

## 3. Architecture
The project strictly follows **Clean Architecture** patterns separated by features.

### Directory Structure
```
lib/
├── core/             # Shared utilities, router config (app_router.dart), theme, fog_engine
├── data/             # Global data sources (e.g., secure_database_service.dart)
├── features/         # Feature-based modules (Clean Architecture)
│   ├── auth/         # Authentication Feature
│   │   ├── data/         # API Services (AuthApiService), Repositories Implementation
│   │   ├── domain/       # Entities (UserModel), abstract Repositories, Use Cases
│   │   └── presentation/ # Riverpod Providers (login_provider), Screens (Login, Register)
│   └── dashboard/    # Main app UI after login
├── models/           # Shared models (e.g., FogState)
└── services/         # Device/Platform services (BackgroundService, WatchService, Notifications)
```

## 4. Key Components

### 4.1 Authentication Flow (`features/auth`)
- **API Base URL**: `https://lifebalance-auth-service.onrender.com/api/v1`
- **Strict Rule**: No mocked data. All authentication and profile data must be fetched from the live API.
- **Providers**: `loginProvider`, `registerProvider`, `forgotPasswordProvider` manage state and coordinate with Use Cases.
- **Remember Me**: Credentials (email/password) are saved via `flutter_secure_storage` on successful login if checked.

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
5. **Security**: Ensure sensitive data (tokens, passwords, health data) is stored using `SecureDatabaseService` or `FlutterSecureStorage`.
