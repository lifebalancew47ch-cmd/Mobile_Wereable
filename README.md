# 🌿 LifeBalance

![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?style=for-the-badge&logo=flutter)
![Android](https://img.shields.io/badge/Android-Mobile-3DDC84?style=for-the-badge&logo=android)
![Wear OS](https://img.shields.io/badge/Wear_OS-Watch-3DDC84?style=for-the-badge&logo=google-fit)
![Security](https://img.shields.io/badge/Security-DevSecOps-red?style=for-the-badge&logo=security)

**LifeBalance** es una aplicación integral orientada al monitoreo y mejora de la salud y el bienestar del usuario, mediante una arquitectura híbrida conformada por una aplicación móvil (Smartphone) y una aplicación para relojes inteligentes (Wear OS).

La aplicación destaca por su enfoque en el procesamiento de datos médicos mediante algoritmos locales (Fog Computing) y prácticas de DevSecOps, priorizando en todo momento la seguridad y privacidad del usuario.

## ✨ Características Principales

*   ⌚ **Integración Mobile & Wearable:** Comunicación Bluetooth Low Energy (BLE) en tiempo real entre la aplicación del smartphone y relojes Wear OS (ej. Samsung Galaxy Watch).
*   🧠 **Fog Computing (Motor Local):** Capacidad de procesar métricas en el propio dispositivo (Edge Computing) a través de un algoritmo de sedentarismo sin depender constantemente de la nube.
*   ❤️ **Monitoreo de Salud:** Rastreo continuo de métricas vitales clave, como ritmo cardíaco, pasos, horas de sueño y calorías quemadas.
*   🔒 **Seguridad y Privacidad:** 
    *   Almacenamiento de datos en una base de datos local encriptada (`SQLCipher`).
    *   Arquitectura basada en un pipeline riguroso de DevSecOps que ejecuta análisis estáticos de vulnerabilidades.
*   ⚙️ **Servicios en Segundo Plano:** Ejecución constante, eficiente e invisible (`flutter_background_service`) para recopilar sensores, respetando estrictamente los permisos del usuario.

## 🛠️ Tecnologías y Arquitectura

*   **Framework:** Flutter (Dart) para UI y lógica compartida.
*   **Plataforma Nativa:** Kotlin y XML para integraciones específicas en Android y Wear OS (servicios persistentes).
*   **Base de datos:** `sqflite_sqlcipher` (Base de datos SQLite cifrada).
*   **Hardware / IoT:** `flutter_blue_plus` para conexión BLE, `permission_handler` para gestión de sensores biológicos (`BODY_SENSORS`).
*   **CI/CD (DevSecOps):** GitHub Actions configurado con:
    *   `Gitleaks` (Escaneo de Secretos).
    *   `Trivy` (Análisis de CVEs en dependencias).
    *   Linting estricto de Dart/Flutter.
    *   Análisis estático de Kotlin/Android.

## 🚀 Empezando

### Prerrequisitos

*   Flutter SDK instalado (canal `stable`).
*   Android Studio instalado con emuladores para dispositivos móviles y Wear OS (API 30+ recomendada).
*   Un dispositivo físico Wear OS para pruebas Bluetooth (recomendado).

### Instalación

1. Clona el repositorio:
   ```bash
   git clone https://github.com/lifebalancew47ch-cmd/Mobile_Wereable.git
   cd Mobile_Wereable
   ```
2. Obtén las dependencias del proyecto:
   ```bash
   flutter pub get
   ```
3. Ejecuta la aplicación móvil:
   ```bash
   flutter run
   ```
4. Para instalar la versión del reloj (Wear OS), abre la carpeta `android` en Android Studio y ejecuta el módulo `:wear`.

## 🧪 Pruebas (Testing)

El proyecto cuenta con un entorno de pruebas robusto para validar su estabilidad:

```bash
# Ejecutar todas las pruebas unitarias y de widgets
flutter test
```

## 🛡️ Pipeline DevSecOps

Cada *push* o *pull request* a la rama `main` dispara la canalización DevSecOps automatizada que valida:
1. Filtrado de secretos o llaves.
2. Análisis estático (Dart y Kotlin).
3. Vulnerabilidades en paquetes (SCA).
4. Pruebas unitarias de Flutter.
5. Compilación segura de APKs para Móvil y Reloj.
