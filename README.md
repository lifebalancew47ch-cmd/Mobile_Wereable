# LifeBalance Mobile App

LifeBalance is a comprehensive health and activity tracking application built with Flutter. It monitors user movement and inactivity using device sensors and wearable integration, providing timely alerts to prevent prolonged sedentary behavior.

## 🌟 Features

*   **Activity Monitoring (FogEngine):** Uses device accelerometers to analyze movement variance in 30-second windows. Triggers alerts if inactivity exceeds a threshold (e.g., 45 minutes).
*   **Wearable Integration:** Connects with smartwatches via Bluetooth (`flutter_blue_plus`) to synchronize health data.
*   **Secure Authentication:** Connects to a live .NET backend for secure login and registration.
*   **Background Execution:** Continues monitoring activity even when the app is closed using persistent background services.
*   **High Security:**
    *   **Encrypted Local Data:** Uses `sqflite_sqlcipher` for database encryption and `flutter_secure_storage` for credentials.
    *   **Jailbreak/Root Detection:** The app refuses to run on compromised devices.
    *   **Certificate Pinning:** Enforces strict SSL/TLS pinning in production to prevent Man-in-the-Middle (MitM) attacks.

## 🏗 Architecture

The application strictly adheres to **Clean Architecture** principles and is modularized by feature.

*   **Presentation Layer:** Flutter UI components, Screens, and state management using **Riverpod**.
*   **Domain Layer:** Entities, Use Cases, and Repository Interfaces containing the core business rules.
*   **Data Layer:** API Services (using `dio`), Local Database interactions, and Repository implementations.

## 🛠 Tech Stack

*   **Framework:** Flutter (Dart)
*   **State Management:** Riverpod (`flutter_riverpod`)
*   **Navigation:** `go_router`
*   **Networking:** `dio` (with custom retry interceptors)
*   **Storage:** `sqflite_sqlcipher`, `flutter_secure_storage`
*   **Background Tasks:** `flutter_background_service`, `workmanager`
*   **Sensors & Bluetooth:** `sensors_plus`, `flutter_blue_plus`

## 🚀 Getting Started

### Prerequisites

*   Flutter SDK (^3.9.2)
*   Android Studio / Xcode
*   A connected physical device (Sensors and Bluetooth functionality require a real device, not an emulator).

### Installation

1.  **Clone the repository.**
2.  **Install dependencies:**
    ```bash
    flutter pub get
    ```
3.  **Environment Setup:**
    Ensure you have the environment files (`.env.development` and `.env.production`) at the root of the project. These files define the API URLs and the `PINNED_CERT_SHA256` for certificate pinning.
4.  **Run the app (Development):**
    Certificate pinning is automatically disabled in debug mode to facilitate development.
    ```bash
    flutter run
    ```
5.  **Build for Production:**
    ```bash
    flutter build apk --release
    ```

## 🔒 Security Notes

*   **Certificate Pinning:** In release builds, the app will reject all network connections if the `PINNED_CERT_SHA256` in `.env.production` does not match the server's TLS certificate. Ensure this hash is updated when the server's certificate rotates.
*   **Root Detection:** The app will exit immediately on launch if it detects a rooted or jailbroken environment.

## 📜 License

[Insert License Here]
