# Auditoría técnica — LifeBalance

**Fecha:** 6 de agosto de 2026
**Alcance:** `lib/` (Flutter), `android/app`, `android/wear`, manifiestos, Gradle, dependencias, tests, y los **contratos OpenAPI públicos de los 12 microservicios**.
**Método:** revisión estática de código + lectura de los documentos OpenAPI publicados por cada servicio + **sondeo activo no autenticado** (solo peticiones `GET` sin token, ninguna escritura, sobre infraestructura propia del cliente). No se hizo fuzzing, ni pruebas de bypass de autorización con cuentas reales, ni acceso a datos de terceros. Los resultados del sondeo están en la **sección 7.3**. Los hallazgos que aún dependen de credenciales se marcan *"requiere verificación con token"*.
**Marcos de referencia:** OWASP MASVS v2 / Mobile Top 10 (2024), OWASP API Security Top 10 (2023), OWASP ASVS v4.

---

## Resumen ejecutivo

LifeBalance procesa **datos de salud identificables** (frecuencia cardíaca, HRV, SpO₂, pasos, peso, altura, edad, sexo y GPS). Eso lo coloca bajo un estándar de protección alto (LFPDPPP en México — datos personales sensibles, art. 3 fr. VI; GDPR art. 9 si aplica a UE; HIPAA si hay convenio con un ente cubierto).

El proyecto tiene **buena arquitectura de intención**: Clean Architecture por feature, SQLCipher para la base local, `flutter_secure_storage` para tokens, detección de root/jailbreak, `cleartextTrafficPermitted="false"`, y una batería de tests etiquetados MASVS. El problema no es la ausencia de controles sino que **varios controles críticos están escritos pero desactivados en tiempo de ejecución**, y los tests que deberían detectarlo prueban una función auxiliar en lugar del camino real.

Con los contratos del backend a la vista, el diagnóstico se refina: **el problema principal no está en la app móvil, está en la superficie de API**. La documentación completa de los 12 servicios —incluido el de administración, que se autodescribe como *"Acceso exclusivo para SUPERADMIN"*— está publicada en internet sin autenticación, y buena parte de los endpoints reciben `userId`, `companyId` o `familyId` como parámetro en lugar de derivarlos del JWT.

**Resultado de las pruebas (6/08/2026, sin token y con token de cuenta de prueba):** la autorización del backend salió **mucho mejor de lo que el contrato hacía temer**. Sin token, todo lo sensible responde 401 (autenticación correcta). Con un token de rol `USER` pidiendo objetos ajenos, **6 de 7 endpoints devuelven 403** y **los 5 endpoints de administración devuelven 403** — es decir, la autorización a nivel de objeto y de rol **sí está implementada**. Esto **refuta en gran parte el hallazgo BOLA (S-02)**, que era la segunda preocupación del informe.

Queda **una excepción concreta y confirmada**: `GET /history/organization/{organizationId}` responde 200 a una organización ajena mientras todos sus hermanos dan 403 (**S-20**, corregido). El problema de exposición del Swagger público en 10 servicios (**S-01**) también quedó corregido el 6/08/2026, pendiente de deploy. Detalle de las pruebas en 7.3 y 7.4.

**Conteo de hallazgos:** 7 críticos · 14 altos · 16 medios · 12 bajos.
*(Ajustado tras las pruebas: S-02 refutado; S-03 bajó de crítico a medio; S-20 confirmado como BOLA estructural (alto), fuga en vivo no reproducida; S-16 retirado; S-19 añadido. El detalle vive en 7.4.)*

### Top 7 a resolver primero

| # | Hallazgo | Impacto |
|---|----------|---------|
| C-01 | ✅ Corregido — el certificate pinning **no se aplicaba nunca**: los `.env` están vacíos y el código hacía fail-**open** | MITM sobre datos de salud y tokens |
| C-02 | ✅ Corregido — el isolate de segundo plano no cargaba `dotenv` → sync de salud sin pinning | MITM sobre el 100% del tráfico de sync |
| S-20 | ✅ Corregido — `history/organization/{id}` deriva `organization_id` del token JWT | Un usuario podría leer los broadcasts de otra organización |
| S-01 | ✅ Corregido — **Swagger público en 10 de 12 servicios**, incluido el de administración | Facilitaba el reconocimiento (aunque la autz salió sólida en pruebas) |
| C-03 | ✅ Corregido — el APK de release se firmaba con la **keystore de debug** | Distribución no confiable, clave pública conocida |
| C-04 | ✅ Corregido — Se enviaba `null` en lugar de **fabricar valores clínicos** (60 lpm / 40 ms / 98 % SpO₂) | Datos médicos falsos en el expediente |

> **Actualización tras las pruebas:** S-02 (BOLA generalizado) y el peor escenario de S-03/S-07 (rol) quedaron **refutados** — el backend aplica bien autorización por objeto y por rol en 6 de 7 endpoints y en todo el servicio de administración. La excepción es **S-20**: se probó a fondo con dos cuentas y quedó demostrado que `history/organization/{id}` filtra por el `organizationId` del path **sin verificar la pertenencia** (200 en vez de 403 cross-tenant). No se extrajeron datos de un tercero solo por ausencia de datos org-scoped en las orgs probadas, no por un control que bloquee. El resto del riesgo se concentra en el **cliente** (C-01…C-05) y en la **exposición** (S-01).

Los hallazgos de cliente (`C-*`, `A-*`, `M-*`, `B-*`) están en las secciones 1-4. Los de la plataforma de servicios (`S-*`) en la **sección 7**.

---

## 1. Vulnerabilidades

### C-01 · Certificate pinning inoperante (fail-open) — ✅ CORREGIDO (6/08/2026)
**MASVS-NETWORK-2 · OWASP M5 (Insecure Communication)**

`lib/core/security/certificate_pinning.dart:51-57`

```dart
static bool validateCertificate(X509Certificate? certificate, String host, int port) {
  // En debug/profile o si no hay pins configurados en .env: permitir CA raíz del SO.
  if (kDebugMode || kProfileMode || !isConfigured) return true;
  ...
}
```

El encabezado del archivo (líneas 7-12) promete comportamiento **fail-closed**: *"Si no hay pins configurados → rechazar (nunca degradar)"*. La implementación real hace lo contrario: si `PINNED_CERT_SHA256` está vacío, **acepta cualquier certificado firmado por cualquier CA del sistema**, incluidas CAs instaladas por el usuario o por un MDM.

Y no es hipotético:

- `.env.production` — **archivo vacío** (0 bytes).
- `.env.development` — **archivo vacío** (0 bytes).
- `.gitignore:18` — `.env.*` está ignorado, así que en CI ni siquiera existirá contenido.

Resultado: `isConfigured == false` en todos los builds actuales → **pinning completamente desactivado en producción**.

**Agravante — los tests no lo detectan.** `test/security/masvs/network_tls_test.dart` prueba `validatePinnedCertificate()` (el núcleo aislado, que sí es fail-closed) pero **nunca** invoca `validateCertificate()` con `isConfigured == false` fuera de debug. El test de la línea 163 se titula *"Sin pins configurables → rechazo fail-closed (núcleo)"* y solo verifica el núcleo. La suite da luz verde a una configuración insegura.

**Bug adicional de pinning.** El comentario (líneas 17-20) indica generar el pin con:

```
openssl x509 -pubkey -noout | openssl pkey -pubin -outform der | openssl dgst -sha256
```

Eso produce el hash del **SPKI (clave pública)**. Pero el código (línea 62) calcula `sha256.convert(certificate.der)` — el hash del **certificado completo**. Un pin generado siguiendo las instrucciones **nunca coincidirá**, y como el fallo es silencioso alguien terminará "arreglándolo" volviendo a vaciar la variable.

> Nota: el pinning SPKI es preferible al de certificado hoja: sobrevive a la renovación del certificado mientras se conserve la clave. Con Render (renovación automática de Let's Encrypt cada 90 días) el pinning de hoja **romperá la app cada trimestre**.

**Corregido.** `validateCertificate` ya no cae en `!isConfigured => true`: fuera de debug/profile, la ausencia de pins ahora **rechaza** la conexión (fail-closed real). Además se resolvió el bug del hash: se añadió `lib/core/security/spki_extractor.dart` (parser DER mínimo, sin dependencias externas) para aislar el `SubjectPublicKeyInfo` del certificado, y el pin ahora se calcula como `sha256(SPKI)` — coincidente con las instrucciones de `openssl` del propio archivo — en vez de `sha256(certificado completo)`. Esto también hace el pinning resistente a la renovación automática de Let's Encrypt en Render (sobrevive mientras no cambie la clave). Se añadió `test/security/spki_extractor_test.dart` cubriendo extracción con y sin el campo `version` opcional, y rechazo (`null`) ante DER vacío, truncado o con longitud inconsistente.

> Nota de verificación: este entorno no tuvo acceso a un toolchain de Dart/Flutter para compilar ni correr `flutter test` sobre este cambio — el parser ASN.1 se verificó a mano byte a byte contra los vectores de prueba, pero se recomienda correr la suite (`flutter test test/security/`) antes de publicar el release.

Pendiente (no bloqueante): pins de respaldo (backup pins) para rotación de clave sin romper la app, y un test adicional que ejercite `validateCertificate` completo en modo no-debug (hoy `kDebugMode` es una constante de compilación que no se puede apagar fácilmente desde `flutter test`; la cobertura fail-closed vive en el núcleo `validatePinnedCertificate`, ya probado).

---

### C-02 · El isolate de background sincronizaba datos de salud sin pinning — ✅ CORREGIDO (6/08/2026)
**MASVS-NETWORK-2 · OWASP M5**

`lib/services/background_service.dart` (antes líneas 162-164)

```dart
/// El aislado de segundo plano no tiene acceso a `dotenv` (cargado en el
/// aislado principal), por lo que usa las URLs desplegadas por defecto.
static String _urlFromEnv(String fallback) => fallback;
```

`CertificatePinning._loadPins()` lee `dotenv.isInitialized`. En este isolate siempre era `false` → pins vacíos → `isConfigured == false` → (por C-01) **se aceptaba cualquier certificado**.

Este isolate es precisamente el que envía el grueso de los datos: `IngestionApiService`, `MedicalApiService`, `SedentaryApiService`, `GamificationApiService` y el registro de dispositivo FCM — todo con el `Authorization: Bearer` del usuario adjunto.

**Corregido.** `onStart` ahora llama a `dotenv.load(fileName: String.fromEnvironment('ENV_FILE', ...))` al arrancar el isolate, con el mismo archivo que usa `main.dart`, antes de construir los clientes Dio. `_urlFromEnv` dejó de ser un stub que siempre devolvía el fallback: ahora lee la clave real de `dotenv.env` igual que `api_client.dart`. Con esto, el pinning (ya fail-closed por C-01) queda activo también en background — antes, incluso corregido C-01, este isolate específico habría seguido rechazando *todo* por no tener pins cargados; ahora los carga y valida correctamente.

---

### C-03 · Release firmado con la keystore de debug — ✅ CORREGIDO (6/08/2026)
**MASVS-RESILIENCE · OWASP M7 (Insufficient Binary Protection)**

`android/app/build.gradle.kts:43-48`

```kotlin
release {
    isMinifyEnabled = true
    isShrinkResources = true
    proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"))
    signingConfig = signingConfigs.getByName("debug")   // ← keystore de debug
}
```

La keystore de debug (`~/.android/debug.keystore`) tiene contraseña pública conocida (`android`). Cualquiera puede firmar un APK modificado que el sistema aceptará como actualización legítima. Además Google Play **rechaza** APKs firmados en debug.

Relacionado: `applicationId = "com.example.lifebalance"` — `com.example.*` está bloqueado en Play Store.

**Corregido.** Se reemplazó el `applicationId` por `com.lifebalance.app` en `android/app/build.gradle.kts` **y** en `android/wear/build.gradle.kts` (deben coincidir: el mecanismo `wearApp(project(":wear"))` empaqueta el Wear OS app dentro del APK del teléfono y exige el mismo package name). `namespace` se dejó igual (`com.example.lifebalance`) a propósito — es solo el paquete Kotlin del código generado (R/BuildConfig), no la identidad de publicación, y cambiarlo habría implicado mover ~10 archivos Kotlin y su estructura de carpetas sin poder compilar para verificarlo en este entorno.

El `signingConfig = signingConfigs.getByName("debug")` se eliminó por completo: ahora existe un `signingConfigs.create("release")` real que lee `android/key.properties` (plantilla en `android/key.properties.example`, `.gitignore` ya lo cubría). Deliberadamente **no** se lanza una excepción en tiempo de configuración si falta el archivo — eso rompería `flutter run` en debug para cualquiera que aún no haya generado su keystore — pero el `release` ya nunca puede caer de vuelta a la keystore de debug: sin `key.properties`, `assembleRelease`/`bundleRelease` fallan explícitamente en tiempo de firma.

> Pendiente para el usuario (no puedo generarlo yo — es una credencial que solo debe existir en tu máquina/CI): correr `keytool -genkey -v -keystore ~/lifebalance-release.jks -keyalg RSA -keysize 2048 -validity 10000 -alias lifebalance`, copiar `android/key.properties.example` a `android/key.properties` y completarlo. Guarda la keystore y su contraseña fuera del repo — perderla significa no poder volver a actualizar la app ya publicada con la misma firma.
>
> También pendiente: el bundle ID de iOS/macOS sigue en `com.example.lifebalance` (no forma parte del alcance Android/Wear de esta ronda de fixes) y el `namespace` interno de Kotlin — ninguno bloquea el release de Android.

---

### C-04 · Se fabrican valores clínicos antes de enviarlos al servicio médico — ✅ CORREGIDO (6/08/2026)
**Integridad de datos · riesgo regulatorio**

`lib/services/offline_sync_service.dart:329-336` (y el gemelo en `_toVitalItem`, 383-390)

```dart
final validHr = hrRaw < 1 ? 60.0 : hrRaw.clamp(1, 260).toDouble();
final validHrv = hrvRaw < 1.0 ? 40.0 : hrvRaw.clamp(1.0, 300.0);
final validSpo2 = spo2Raw < 1.0 ? 98.0 : spo2Raw.clamp(1.0, 100.0);
```

Cuando el reloj no obtuvo una lectura válida, en lugar de omitir el campo se **inventa un valor fisiológicamente plausible** y se sube a `POST /medical/readings/batch` como si fuera una medición real.

El caso de SpO₂ es el más grave: `SensorService.kt:57-64` documenta que **el SpO₂ nunca se mide** (Wear OS no expone la API), así que siempre llega en 0 → **siempre se sustituye por 98 %**. Toda la serie de SpO₂ en el expediente médico es sintética.

Un modelo de ML entrenado sobre estos datos, o un profesional de salud consultando el historial, están viendo mediciones que nunca ocurrieron.

**Corrección:** enviar `null` (u omitir el campo) cuando no hay dato. Si el backend exige el campo, añadir una bandera `dataQuality: 'unavailable'`. Nunca rellenar con valores clínicos plausibles.

---

### C-05 · El logout no borra los datos de salud locales — ✅ CORREGIDO (6/08/2026)
**MASVS-STORAGE-2 · OWASP M9 (Insecure Data Storage)**

`lib/features/auth/data/datasources/auth_api_service.dart:116-125` y `TokenService.clearTokens()` (`token_service.dart:56-61`) solo borran tres claves del secure storage.

Quedan intactos tras cerrar sesión:

| Dato | Ubicación | Cifrado |
|---|---|---|
| Signos vitales, sesiones, alertas, pausas activas | `lifebalance_secure.db` (SQLCipher) | Sí, pero la clave sigue en el keystore |
| Sexo, altura, peso, edad | `SharedPreferences` (`biometric_*`) | **No** |
| Último lote del wearable (FC, HRV, GPS) | `SharedPreferences` (`flutter.latest_wear_json`) | **No** |
| Estado del motor sedentario | `SharedPreferences` (`native_fog_prefs`) | **No** |
| Email guardado | `saved_email` en secure storage | Sí |

En un dispositivo compartido (kiosco, equipo corporativo rotativo, teléfono familiar), el usuario B ve el historial de salud del usuario A. La base no está particionada por `userId`.

**Corrección:** un `SessionWiper` invocado en logout y ante 401 que borre la BD (`deleteDatabase`), purgue las claves de `SharedPreferences` con prefijo conocido y regenere `db_encryption_key`. Idealmente, añadir columna `user_id` a todas las tablas.

---

### C-06 · Datos de salud en SharedPreferences en claro — ✅ CORREGIDO (6/08/2026)
**MASVS-STORAGE-1 · OWASP M9**

Tres rutas escriben datos personales sensibles a `SharedPreferences`, que en Android es un **XML en texto plano** en `/data/data/<pkg>/shared_prefs/` (extraíble con root, con `adb backup`, o desde una copia de seguridad en la nube):

1. `biometric_profile_screen.dart:57-61` — sexo, altura, peso, edad.
2. `WearMessageListenerService.kt:18-19` — el lote JSON completo del reloj con FC y HRV.
3. `background_service.dart:120-121` — lo lee de ahí.

Agravado por **`android:allowBackup`**: el manifiesto del wear lo pone explícitamente en `true` (`android/wear/src/main/AndroidManifest.xml:17`) y el de la app **no lo declara**, por lo que hereda el default `true`. `adb backup` extrae todo esto sin root.

**Corrección:**

```xml
<application
    android:allowBackup="false"
    android:fullBackupContent="false"
    android:dataExtractionRules="@xml/data_extraction_rules">
```

y mover los datos biométricos a la BD SQLCipher (ya existe) o a `flutter_secure_storage`. Para el puente wear→background, usar un archivo cifrado o insertar directo en SQLCipher desde Kotlin.

---

### A-01 · Sin control de acceso por rol — ALTO
**OWASP M1 (Improper Credential Usage) / Broken Access Control**

`UserModel` declara `role` (`user_model.dart:8, 28`) y lo parsea del backend, pero **`role` no se lee en ningún punto del código**. Verificado con `grep -r "\.role"` → una sola coincidencia, la propia declaración.

Consecuencias:

- `/admin` (`AdminSummaryScreen`) es la pestaña central del `BottomAppBar`, con FAB destacado, visible para **todos** los usuarios (`app_router.dart:147-154`, `main_navigation_shell.dart:96-106`).
- `/dashboard` renderiza `ExecutiveDashboardScreen` para todos, sin distinción de perfil (`app_router.dart:97`).

Hoy el impacto real está acotado porque `AdminSummaryScreen` solo lee la BD local del propio usuario — pero la UI promete capacidades administrativas que no están gobernadas, y en cuanto se conecte a un endpoint de organización se convierte en una fuga entre inquilinos.

**Corrección:** un `redirect` en go_router que consulte el rol del perfil, y ocultar la rama según rol. **La autorización real debe vivir en el backend**; el control cliente es solo UX.

---

### A-02 · `debugPrint` / `Log.d` con datos de salud en builds de producción — ALTO
**MASVS-STORAGE-3 · OWASP M9**

Contrario a la creencia habitual, **`debugPrint` no se elimina en release** — escribe a stdout/logcat siempre. Hay 76 llamadas de logging en el proyecto. Las sensibles:

| Archivo:línea | Contenido registrado |
|---|---|
| `offline_sync_service.dart:267` | `e.response?.data` — cuerpo completo de la respuesta de Ingestion (puede traer PHI y el eco del payload) |
| `SensorService.kt:238` | `"Heart rate event: $lastHeartRate bpm"` |
| `SensorService.kt:227` | conteo de pasos |
| `SensorService.kt:497` | varianza, ventanas de inactividad |
| `NativeFogEngine.kt:122,130,138` | estado de inactividad y minutos |
| `WearMessageListenerService.kt:12` | tamaño del lote de sensores |

En Android 11+ logcat está restringido a apps del sistema, pero sigue accesible por `adb`, por apps con `READ_LOGS` en dispositivos rooteados y por herramientas de diagnóstico de OEM.

Existe `test/security/audit/pii_log_audit_test.dart`, lo cual indica que el equipo ya identificó el riesgo — conviene revisar por qué no cubre estos casos.

**Corrección:** un wrapper `AppLog.d()` que sea no-op salvo en `kDebugMode`, y en Kotlin envolver con `if (BuildConfig.DEBUG)`. Añadir a ProGuard:

```proguard
-assumenosideeffects class android.util.Log {
    public static *** d(...);
    public static *** v(...);
    public static *** i(...);
}
```

---

### A-03 · Sin validación de entrada en los formularios de autenticación — ALTO
**OWASP ASVS V5 · OWASP M4 (Insufficient Input/Output Validation)**

`login_screen.dart:186-212` usa `TextField` crudos, sin `Form`, sin `validator`, sin `inputFormatters`, sin `maxLength`:

```dart
TextField(
  controller: _emailController,
  decoration: const InputDecoration(labelText: 'Correo Electrónico', ...),
  keyboardType: TextInputType.emailAddress,   // solo sugerencia de teclado
),
```

La única comprobación es `email.isEmpty || password.isEmpty` en `login_provider.dart:40`. `keyboardType` **no restringe** la entrada: pegar desde el portapapeles, un teclado físico o un teclado de terceros introducen cualquier carácter, de cualquier longitud.

Consecuencias concretas:

- Sin `maxLength`, un pegado de 10 MB va al backend → DoS de ancho de banda y de parsing.
- Sin `.trim()`, `" user@x.com "` falla el login sin explicación útil.
- Sin validación de formato, cada error tipográfico cuesta un round-trip a la red.
- Sin `autofillHints`, no funcionan los gestores de contraseñas (y eso empuja a contraseñas débiles).
- Sin `enableSuggestions: false` / `autocorrect: false` en el campo de contraseña, el teclado puede aprender fragmentos de la contraseña en su diccionario personal.

Lo mismo en `forgot_password_screen.dart:39-46`.

**Contraste:** `settings_screen.dart:69-107` **sí** usa `Form` + `GlobalKey<FormState>` + `validator` en el diálogo de cambio de contraseña, y `alert_settings_screen.dart:67-79` valida el rango 1-120. El patrón correcto ya existe en el proyecto — falta aplicarlo de forma consistente.

**Corrección de referencia:**

```dart
final _formKey = GlobalKey<FormState>();

Form(
  key: _formKey,
  autovalidateMode: AutovalidateMode.onUserInteraction,
  child: Column(children: [
    TextFormField(
      controller: _emailController,
      keyboardType: TextInputType.emailAddress,
      textInputAction: TextInputAction.next,
      autofillHints: const [AutofillHints.username],
      maxLength: 254,                                  // RFC 5321
      inputFormatters: [
        FilteringTextInputFormatter.deny(RegExp(r'\s')),
        LengthLimitingTextInputFormatter(254),
      ],
      validator: Validators.email,
    ),
    TextFormField(
      controller: _passwordController,
      obscureText: !_isPasswordVisible,
      autocorrect: false,
      enableSuggestions: false,
      autofillHints: const [AutofillHints.password],
      maxLength: 128,
      validator: Validators.passwordRequired,
    ),
  ]),
)
```

Y centralizar en `lib/core/validation/validators.dart`:

```dart
class Validators {
  static final _email = RegExp(r"^[\w.+-]+@[\w-]+(\.[\w-]+)+$");

  static String? email(String? v) {
    final s = v?.trim() ?? '';
    if (s.isEmpty) return 'Ingresa tu correo';
    if (s.length > 254) return 'Correo demasiado largo';
    if (!_email.hasMatch(s)) return 'Formato de correo no válido';
    return null;
  }

  static String? intInRange(String? v, {required int min, required int max, required String label}) {
    final s = v?.trim() ?? '';
    if (s.isEmpty) return '$label es obligatorio';
    final n = int.tryParse(s);
    if (n == null) return '$label debe ser un número entero';
    if (n < min || n > max) return '$label debe estar entre $min y $max';
    return null;
  }
}
```

> El regex de email es deliberadamente simple y **acotado** (sin cuantificadores anidados). Evita patrones tipo `(a+)+@` que abren la puerta a ReDoS.

---

### A-04 · Datos biométricos sin validación de rango — ALTO
**OWASP M4 · integridad de datos clínicos**

`biometric_profile_screen.dart:398-401`:

```dart
TextField(
  controller: controller,
  keyboardType: TextInputType.number,   // sin inputFormatters, sin maxLength
  ...
)
```

`_save()` (líneas 64-81) hace `double.tryParse` y solo comprueba `> 0`. Se acepta y se envía a `POST /medical/readings`:

- altura `999999` cm
- peso `0.001` kg
- edad `-5` (el signo pasa por `TextInputType.number` en varios teclados)
- `1e308` (notación científica: `double.tryParse` la acepta)

Estos valores contaminan el cálculo del *Sedentary Score* y el expediente médico.

**Corrección:**

```dart
TextFormField(
  keyboardType: const TextInputType.numberWithOptions(decimal: true),
  inputFormatters: [
    FilteringTextInputFormatter.allow(RegExp(r'^\d{0,3}([.,]\d{0,1})?')),
  ],
  validator: (v) => Validators.doubleInRange(v, min: 50, max: 260, label: 'Altura'),
)
```

Rangos sugeridos: altura 50-260 cm · peso 2-500 kg · edad 1-120 años. Replicar la validación en el backend — **la validación cliente nunca es un control de seguridad**, solo de usabilidad.

---

### A-05 · `TextEditingController` de contraseñas nunca liberados — ALTO
**MASVS-STORAGE-2 · OWASP M9**

`settings_screen.dart:60-62`:

```dart
final currentCtrl = TextEditingController();
final newCtrl = TextEditingController();
final confirmCtrl = TextEditingController();
```

Se crean dentro de `_showChangePasswordDialog()` y **nunca se llama `.dispose()`**. Además de la fuga de memoria (detectada por `flutter_lints`), las tres contraseñas quedan como `String` en el heap de Dart hasta que el GC decida actuar — sin control sobre cuándo. Un volcado de memoria del proceso las expone en claro.

**Corrección:** convertir el diálogo en un `StatefulWidget` con `dispose()`, o envolver en `try/finally` con `.clear()` + `.dispose()`.

---

### A-06 · `RetryWithBackoffInterceptor`: contador compartido entre peticiones — ALTO
**Bug funcional**

`api_client.dart:23, 41-53`

```dart
int _attempts = 0;   // estado de instancia, compartido por TODAS las peticiones del Dio
```

El interceptor es único por instancia de `Dio`, pero `_attempts` es global a esa instancia. Con peticiones concurrentes (el dashboard lanza varias en paralelo):

- Tres fallos simultáneos consumen los 3 intentos entre las tres → cada una reintenta una sola vez.
- El primer éxito hace `_attempts = 0` (línea 53) → las demás pueden reintentar indefinidamente.

Además, el reintento (líneas 43-50) crea un `Future.delayed` **sin await**: `onError` retorna inmediatamente y el `handler` se resuelve fuera del flujo del interceptor. Con `maxAttempts` agotado el `handler.next(err)` puede llamarse dos veces → `StateError`.

**Corrección:** guardar el contador en `err.requestOptions.extra['retry_count']`, que sí es por petición:

```dart
@override
void onError(DioException err, ErrorInterceptorHandler handler) async {
  final count = (err.requestOptions.extra['_retry'] as int?) ?? 0;
  if (count >= maxAttempts || !_isRetryable(err)) return handler.next(err);
  err.requestOptions.extra['_retry'] = count + 1;
  await Future<void>.delayed(baseDelay * (1 << count));   // backoff exponencial real
  try {
    handler.resolve(await _dio.fetch<dynamic>(err.requestOptions));
  } on DioException catch (e) {
    handler.next(e);
  }
}
```

> `baseDelay * _attempts` (línea 43) es backoff **lineal**, no exponencial pese al nombre de la clase. Y falta *jitter*: sin él, todos los clientes reintentan sincronizados y amplifican la caída del backend (efecto manada).

---

### A-07 · Sin refresh token: la sesión muere en silencio — ALTO
**Funcional + UX**

`TokenService` guarda `refresh_token` (línea 32) y expone `getRefreshToken()` (52-54), pero **nadie lo usa**. El interceptor de 401 (`api_client.dart:98-100`) simplemente borra la sesión:

```dart
if (e.response?.statusCode == 401) {
  await tokenService.clearTokens();
}
```

El usuario es expulsado al login cada vez que expira el access token — durante una sincronización en background, sin aviso, perdiendo el estado de la pantalla en la que estaba.

**Corrección:** un `QueuedInterceptor` que ante 401 (y solo una vez, con un `Completer` compartido para evitar la estampida) llame a `POST /auth/refresh`, reintente la petición original y solo si el refresh falla haga `clearTokens()`.

---

### A-08 · `SensorService` exportado sin permiso, e `intent-filter` inoperante — ALTO
**MASVS-PLATFORM-1 · OWASP M8 (Security Misconfiguration)**

`android/wear/src/main/AndroidManifest.xml:37-45`

```xml
<service android:name=".SensorService" android:exported="true"
         android:foregroundServiceType="connectedDevice|health">
    <intent-filter>
        <action android:name="com.google.android.gms.wearable.MESSAGE_RECEIVED" />
        ...
```

Dos problemas:

1. **`exported="true"` sin `android:permission`** → cualquier app instalada en el reloj puede lanzar el servicio (`startService`), activando la recolección de sensores y el wake lock de 4 horas. Vector de agotamiento de batería y de activación no consentida de sensores corporales.
2. El `intent-filter` de `MESSAGE_RECEIVED` **no hace nada**: Google Play Services entrega esos eventos únicamente a subclases de `WearableListenerService` mediante binding, y `SensorService` es un `android.app.Service` plano cuyo `onBind` retorna `null` (línea 183). Configuración muerta que solo suma superficie de ataque.

Lo mismo aplica a `BootReceiver` (línea 60): `BOOT_COMPLETED` es una acción protegida del sistema, no necesita `exported="true"`.

**Corrección:** `android:exported="false"` en ambos y eliminar el `intent-filter` inservible del `SensorService`.

---

### A-09 · `WearMessageListenerService` no verifica el emisor — ALTO
**MASVS-PLATFORM-2**

`WearMessageListenerService.kt:9-25` procesa cualquier mensaje que llegue a `/lifebalance/sensors` sin comprobar `messageEvent.sourceNodeId` contra los nodos conocidos ni validar el esquema del JSON antes de reenviarlo a `NativeFogEngine.processBatchJson()` y de escribirlo a `SharedPreferences`.

El riesgo real está acotado (la Wearable API exige que ambos APKs compartan firma), pero un JSON malformado o gigantesco de un nodo comprometido se persiste sin límite de tamaño y se parsea sin cota.

**Corrección:** validar `sourceNodeId` contra `NodeClient.connectedNodes`, imponer un tamaño máximo al payload (p. ej. 256 KB) y validar el esquema antes de persistir.

---

### M-01 · `hasValidToken()` acepta tokens sin `exp` — MEDIO

`token_service.dart:63-69`

```dart
final expiry = _extractExpiry(token);
if (expiry == null) return true;   // ← token sin exp = válido para siempre
```

Un token opaco, truncado o corrupto pasa el guard del router (`app_router.dart:52`) y el usuario entra a la app; solo falla en la primera llamada a la API. Peor: el `catch` de `_extractExpiry` (línea 85) devuelve `null` ante cualquier error de decodificación, así que un JWT con firma inválida también "pasa".

Además falta *clock skew*: `DateTime.now().isBefore(expiry)` sin margen provoca 401 en el límite exacto.

**Corrección:** `if (expiry == null) return false;` más un margen de 30-60 s.

---

### M-02 · `flutter_secure_storage` sin `AndroidOptions` — MEDIO
**MASVS-STORAGE-1**

Todas las instancias se crean con el constructor por defecto (`token_service.dart:8, 66`; `encryption_service.dart:6`; `login_screen.dart:20`). En la v9.x el default de `encryptedSharedPreferences` es `false`, lo que usa el modo heredado en lugar de `EncryptedSharedPreferences` de Jetpack Security.

**Corrección:**

```dart
const FlutterSecureStorage(
  aOptions: AndroidOptions(encryptedSharedPreferences: true),
);
```

Nota: cambiar esta opción **invalida los datos ya guardados**. Hace falta una migración o forzar re-login en la versión que lo introduzca.

---

### M-03 · Sin `FLAG_SECURE`: capturas y previsualización del multitarea — MEDIO
**MASVS-PLATFORM-3**

No hay ninguna llamada a `FLAG_SECURE` en el proyecto. En las pantallas con datos de salud (dashboards, perfil biométrico, historial médico) el sistema genera miniaturas para el conmutador de apps y cualquier app con permiso de captura puede grabar la pantalla.

**Corrección:** en `MainActivity.onCreate()`, o selectivamente con un `SecureScreen` wrapper vía MethodChannel en las rutas sensibles.

---

### M-04 · El bloqueo biométrico está implementado pero desconectado — MEDIO

`auth_gate.dart` implementa un app-lock completo y correcto con `local_auth`: `authenticate()` con `stickyAuth`, manejo de `PlatformException`, botón de reintento y redirección a `/dashboard` al validar. Es el único consumidor de la dependencia `local_auth` (`pubspec.yaml:45`).

Pero **`AuthGate` nunca se instancia** — ni en `main.dart` ni en `app_router.dart` ni en ningún otro sitio (ver sección 2). El trabajo está hecho y no está en uso: una app de datos de salud sin desbloqueo al reabrir.

Caso análogo: `firebase_crashlytics` (`pubspec.yaml:49`) está declarado pero `main.dart` nunca conecta `FlutterError.onError` ni `PlatformDispatcher.instance.onError`, así que no se reporta ningún crash.

**Corrección:** cablear `AuthGate` como ruta intermedia entre `/splash` y `/dashboard` (activable desde ajustes, con opción de desactivarlo). Y cablear Crashlytics:

```dart
FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
PlatformDispatcher.instance.onError = (error, stack) {
  FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
  return true;
};
```

---

### M-05 · `exit(0)` ante root: hostil y trivial de evadir — MEDIO

`main.dart:45-48`

```dart
bool jailbroken = await FlutterJailbreakDetection.jailbroken;
if (jailbroken) exit(0);
```

La app se cierra sin explicación — el usuario ve un crash. Y un solo hook de Frida sobre ese método anula el control. Como defensa aislada aporta poco; como *señal* para el backend aporta bastante.

**Corrección:** mostrar una pantalla explicativa, permitir modo de solo lectura, y **reportar la señal al servidor** para que decida (attestation con Play Integrity API sería el control robusto).

---

### M-06 · `_extractErrorMessage` no se aplica en todas las rutas → crash — MEDIO
**Bug**

`auth_api_service.dart` tiene un helper defensivo `_extractErrorMessage` (líneas 46-66) usado en `register` y `changePassword`, pero tres métodos siguen accediendo al mapa a ciegas:

```dart
// línea 39  (login)
final message = e.response?.data['message'] ?? 'Error de servidor';
// línea 112 (forgotPassword)
throw Exception(e.response?.data['message'] ?? 'Error de servidor');
// línea 136 (getProfile)
throw Exception(e.response?.data['message'] ?? 'Error al obtener perfil');
```

Si el backend devuelve HTML (502 de Render, página de mantenimiento) o texto plano, `data` es un `String` y `data['message']` lanza `NoSuchMethodError` **desde dentro del `catch`** — no lo captura nadie, y la app crashea en lugar de mostrar "Error de conexión".

Render, que es donde están desplegados los ocho microservicios, devuelve HTML en los cold starts. Esto pasará.

**Corrección:** usar `_extractErrorMessage` en las tres.

---

### M-07 · Estado obsoleto en `ForgotPasswordScreen` — MEDIO
**Bug**

`forgot_password_screen.dart:24, 59-62`

```dart
final forgotPasswordState = ref.watch(forgotPasswordProvider);   // captura en build
...
final success = await ref.read(...).sendInstructions(...);
if (!context.mounted) return;
if (success) { ... }
else if (forgotPasswordState.errorMessage != null) {   // ← valor de ANTES de la llamada
```

`forgotPasswordState` se capturó al construir el widget. Tras el `await` el provider ya cambió, pero la variable local no. En el primer error, `errorMessage` sigue siendo `null` y **no se muestra ningún mensaje**: el usuario pulsa el botón y no pasa nada.

**Corrección:** releer con `ref.read(forgotPasswordProvider).errorMessage` después del `await`, o usar `ref.listen` como hace `login_screen.dart:97`.

---

### M-08 · Pérdida masiva de datos del wearable — MEDIO
**Bug de arquitectura**

Tres puntos donde se descartan lecturas:

1. `WearMessageListenerService.kt:19` — `putString("flutter.latest_wear_json", ...)` **sobrescribe** la clave en cada mensaje. El reloj envía un lote cada 5 s (`SensorService.kt:72`).
2. `background_service.dart:118-125` — el poller lee esa clave **cada 5 minutos** y de todo el lote se queda solo con `batch.last`.

Resultado: de ~60 lotes generados en 5 minutos se persiste **1 lectura**. El resto se pierde.

3. `SensorService.kt:375-380` — `onSendFailed()` descarta el lote entero (*"for now we drop it to avoid memory bounds issues"*). Contradice la promesa de *offline-first sin pérdida de datos* documentada en `offline_sync_service.dart:14-20`.

**Corrección:** que Kotlin acumule en una cola con tope (o inserte directo en SQLCipher vía un canal), y que el reloj mantenga un buffer circular en disco en lugar de descartar.

---

### M-09 · `_lastMedicalSync` no se persiste → reenvío completo en cada arranque — MEDIO

`offline_sync_service.dart:41`

```dart
DateTime _lastMedicalSync = DateTime.fromMillisecondsSinceEpoch(0);
```

El cursor es un campo de instancia. Cada reinicio de la app o del isolate vuelve a epoch → `getVitalSignsAfter(epoch)` devuelve **toda la tabla** y se reenvía completa a `/medical/readings/batch`. Duplicados en el expediente médico y consumo de datos creciente sin cota.

Contrasta con `_lastReportedActivityDay`, que sí se persiste en `SharedPreferences` (líneas 46-56). El patrón correcto ya está en el archivo.

**Corrección:** persistir el cursor igual que `_lastReportedActivityDay`.

---

### M-10 · Los ajustes de notificaciones no hacen nada — MEDIO
**Bug funcional**

Dos grupos de preferencias se guardan y nunca se leen:

| Preferencia | Se escribe en | Se lee en |
|---|---|---|
| `settings_push_enabled` | `settings_screen.dart:44` | **ningún sitio** |
| `settings_sedentary_alerts_enabled` | `settings_screen.dart:53` | **ningún sitio** |
| `alertSound` | `alert_settings_store.dart:37` | **ningún sitio** |
| `criticalNotifications` | `alert_settings_store.dart:36` | **ningún sitio** |
| `startHour` / `endHour` / `activeDays` | `alert_settings_store.dart:32-35` | **ningún sitio** |

`NotificationService.showInactivityAlert` acepta `enableSound` y `critical` (líneas 31-35), pero `fog_engine.dart:305` la invoca sin ellos:

```dart
_notificationService.showInactivityAlert(minutes);   // usa los defaults
```

El usuario configura horario laboral 9-18 de lunes a viernes y desactiva el sonido — y sigue recibiendo alertas sonoras un domingo a las 3 de la mañana. Solo `intervalMinutes` tiene efecto real (`alert_settings_screen.dart:94`).

**Corrección:** que `FogEngine._triggerAlert` lea `alertSettingsProvider` y respete horario, días activos, sonido y modo crítico antes de notificar.

---

### M-11 · Wake lock parcial de 4 horas en el reloj — MEDIO

`SensorService.kt:125-128`

```kotlin
wakeLock = powerManager.newWakeLock(PARTIAL_WAKE_LOCK, "LifeBalance:SensorServiceWakeLock")
    .apply { setReferenceCounted(false); acquire(4 * 60 * 60 * 1000L) }
```

Y se vuelve a adquirir en cada `onStartCommand` (líneas 175-179). Un `PARTIAL_WAKE_LOCK` sostenido 4 h impide que la CPU del reloj entre en suspensión — en una batería de smartwatch (~300 mAh) eso es la diferencia entre un día y unas pocas horas.

Además `retryIntervalMs` (líneas 78, 377, 383) se calcula con backoff exponencial pero **nunca se usa para programar nada** — variable muerta.

**Corrección:** un `ForegroundService` con `foregroundServiceType="health"` ya mantiene el proceso vivo sin wake lock. Para el muestreo periódico, usar el batching por hardware del `SensorManager` (ya se usa en la línea 145) y dejar que el sistema despierte la CPU.

---

## 2. Vistas, rutas y código muerto

### Pantallas y componentes sin uso

| Elemento | Ubicación | Estado |
|---|---|---|
| `AuthGate` | `lib/core/security/auth_gate.dart` | **Huérfana, pero funcional.** App-lock biométrico completo (`local_auth`), nunca instanciado. No la sustituye el `redirect` de `app_router.dart:46-55`, que solo valida el token — son controles distintos. Recuperarla, no borrarla (ver M-04). |
| `IndividualDashboardScreen` | `lib/features/dashboard/presentation/screens/` | **Ruta huérfana.** `/dashboard/individual` está registrada (`app_router.dart:105-108`) pero ningún `context.go`/`push` navega hacia ella. Solo alcanzable por deep link manual. |
| `RegisterUseCase` + `registerProvider` + `RegisterNotifier` | `auth/domain/usecases/register_use_case.dart`, `auth/presentation/providers/register_provider.dart` | **Muertos.** No existe pantalla de registro: `login_screen.dart:250` abre el registro en el navegador web (`lifebalance-adv3.onrender.com/register`). Toda la cadena (use case, provider, `RegisterState`, `AuthApiService.register`) está sin consumidor. |
| `AuthRepository.register` | `auth/domain/repositories/auth_repository.dart` | Interfaz sin llamador. |

**Nota:** `AlertsScreen` y `NotificationPreferencesScreen` **sí se usan** — se montan desde `notifications_screen.dart:23,39`, no desde el router. No son huérfanas.

### Configuración muerta

- `intent-filter` de `MESSAGE_RECEIVED` en `SensorService` (ver A-08).
- `retryIntervalMs` en `SensorService.kt` (ver M-11).
- Preferencias de alertas nunca consumidas (ver M-10).
- `firebase_crashlytics` declarado sin cablear (ver M-04). Conviene verificar también si `health`, `flutter_blue_plus` y `workmanager` tienen consumidores reales.

**Acción sugerida:** eliminar la cadena de registro (o dejar un `// TODO` explícito si el registro nativo está planeado); **conservar y cablear** `AuthGate`. Para `IndividualDashboardScreen`, decidir: enlazarla desde el dashboard ejecutivo o quitar la ruta.

---

## 3. Diseño y experiencia de usuario

### D-01 · El tema existe pero la mitad de las pantallas lo ignoran — ALTO

`app_theme.dart` define dos temas completos y bien construidos (*Green Harmony* / *Midnight Executive*) con M3, tipografía Oswald y radios consistentes. Pero:

- **114 ocurrencias** de `Color(0xFF3E6F58)` hardcodeado en **16 archivos** (`performance_analysis_screen.dart` 19 veces, `heatmap_screen.dart` 14, `executive_dashboard_screen.dart` 14, `admin_summary_screen.dart` 12).
- `backgroundColor: Colors.white` fijo en `biometric_profile_screen.dart:113,115` y `executive_dashboard_screen.dart`.
- `Color(0xFFE9F1EC)`, `Color(0xFFEDF2EE)`, `Colors.black87`, `Colors.grey.shade300`… dispersos por toda la UI.

**Consecuencia:** el modo oscuro está roto en buena parte de la app. `BiometricProfileScreen` renderiza fondo blanco con texto verde oscuro incluso con `ThemeMode.dark` activo, mientras el `BottomAppBar` que la rodea sí se oscurece.

Además el `darkTheme` **no define `inputDecorationTheme`** (el `lightTheme` sí, líneas 96-107), así que los campos de texto cambian de aspecto entre temas.

**Corrección:** sustituir por `Theme.of(context).colorScheme.primary` / `.surface` / `.onSurface`, y extender `ColorScheme` con un `ThemeExtension` para los colores de marca que no encajan en el esquema M3:

```dart
@immutable
class BrandColors extends ThemeExtension<BrandColors> {
  final Color mint, cardBg, successGreen;
  // ...
}
```

Un `dart fix` no lo resuelve; conviene hacerlo pantalla por pantalla empezando por las cuatro con más ocurrencias.

### D-02 · El control de tema está enterrado en una subpantalla — MEDIO

El único conmutador claro/oscuro está en el `AppBar` de `AlertSettingsScreen` (`alert_settings_screen.dart:132-138`), a la que se llega por Perfil → Configuración → Configuración de alertas. Es el sitio menos descubrible posible para un ajuste global. `SettingsScreen` no lo ofrece.

**Corrección:** moverlo a `SettingsScreen` como `SwitchListTile` o selector de tres estados (Claro / Oscuro / Sistema), y ofrecer `ThemeMode.system` como default.

### D-03 · Sin estado vacío en varias listas — MEDIO

`ProfileScreen`, `ActivityHistoryScreen`, `GamificationScreen` y `AdminSummaryScreen` manejan `loading` y `error`, pero cuando la lista viene vacía muestran un espacio en blanco. En una app nueva sin datos del reloj —el caso de todo usuario en su primer día— la app parece rota.

**Corrección:** un widget `EmptyState(icon, title, message, action)` reutilizable, con CTA hacia "Emparejar wearable" cuando el vacío se deba a falta de dispositivo.

### D-04 · Errores crudos expuestos al usuario — MEDIO

`profile_screen.dart:90` → `Text('Error: $error')` imprime la excepción completa, incluidos detalles de `DioException` (URL, código, a veces fragmentos del cuerpo). Malo para la UX y una fuga menor de información sobre la infraestructura.

**Corrección:** mapear a mensajes accionables ("No pudimos cargar tu perfil. Revisa tu conexión.") y registrar el detalle técnico solo en Crashlytics.

### D-05 · Accesibilidad: bien en la navegación, ausente en el resto — MEDIO

`MainNavigationShell` está bien hecho: `Semantics(button:, selected:, label:)`, `ConstrainedBox(minHeight: 48)`, `HapticFeedback`. Ese cuidado no se replica:

- `_GenderCard` (`biometric_profile_screen.dart:346`) usa `GestureDetector` sin `Semantics` ni rol de botón → un lector de pantalla no lo anuncia como seleccionable, y no hay feedback táctil de pulsación.
- Los selectores de día (`alert_settings_screen.dart:233`) y los chips de intervalo (línea 338) usan `GestureDetector` de 36×36 px — por debajo del mínimo de 48×48 de las WCAG y de las Material Guidelines.
- Textos de 9-10 px (`alert_settings_screen.dart:319, 372`; `biometric_profile_screen.dart:267`) están por debajo del mínimo legible y no escalan con `textScaleFactor`.
- Contraste: `Colors.grey` sobre `Colors.white` (`profile_screen.dart:36`) da ~2.8:1, por debajo del 4.5:1 exigido por WCAG AA.

**Corrección:** usar `InkWell`/`FilterChip` en lugar de `GestureDetector`, elevar los objetivos táctiles a 48 px, subir la tipografía mínima a 12 px y verificar contrastes.

### D-06 · Sin *pull-to-refresh* ni desactivación de reintentos — BAJO

Los dashboards cargan en `initState` y no ofrecen `RefreshIndicator`. La única forma de refrescar es salir y volver a entrar en la pestaña.

### D-07 · Búsqueda del panel admin sin *debounce* — BAJO

`admin_summary_screen.dart:62-75` filtra hasta 1000 sesiones dentro de un `setState` **en cada pulsación de tecla**. En gama baja se nota. Falta también `maxLength`.

**Corrección:** `debounce` de 250-300 ms y `maxLength: 64`.

### D-08 · Sin borrado de cuenta ni exportación de datos — MEDIO
**Cumplimiento normativo**

No existe ninguna ruta para que el usuario ejerza sus derechos ARCO (LFPDPPP art. 22) / derecho de supresión y portabilidad (GDPR art. 17 y 20). Para una app de datos de salud es un requisito legal, no una mejora.

**Corrección:** en `SettingsScreen`, "Descargar mis datos" (JSON/CSV desde la BD local + endpoint de exportación) y "Eliminar mi cuenta" con doble confirmación.

---

## 4. Hallazgos menores

| ID | Hallazgo | Ubicación |
|---|---|---|
| B-01 | `pubspec.yaml:2` — `description: "A new Flutter project."` sin personalizar | `pubspec.yaml` |
| B-02 | `ref.refresh(profileProvider)` con resultado ignorado → lint `unused_result`; debería ser `ref.invalidate()` | `profile_screen.dart:92` |
| B-03 | `_addColumnIfMissing` interpola el nombre de tabla en `PRAGMA table_info($table)`. Hoy no es explotable (todos los valores son literales del código) pero es un patrón a evitar | `secure_database_service.dart:77` |
| B-04 | El comentario de `validateCertificate` dice *"Callback usado por dio (badCertificateCallback)"* — es incorrecto, se registra como `IOHttpClientAdapter.validateCertificate`, que se invoca en **todas** las conexiones, no solo en las que fallan la validación de CA | `certificate_pinning.dart:44-46` |
| B-05 | `NativeFogEngine` calcula los minutos como `idleWindows / 2` asumiendo ventanas exactas de 30 s, pero `analyzeWindow()` solo se dispara cuando llega un lote (`processBatchJson:90`). Si el reloj se desconecta, el conteo se congela y los minutos reportados quedan por debajo del tiempo real | `NativeFogEngine.kt:117,137` |
| B-06 | `DeviceIdentityService` guarda el device ID en `SharedPreferences` sin cifrar. Es un pseudoidentificador persistente ligado a datos de salud → conviene tratarlo como dato personal | `device_identity_service.dart:12-17` |
| B-07 | `dotenv.load` usa `defaultValue: '.env.development'`. Un build de release sin `--dart-define=ENV_FILE=.env.production` carga la configuración de desarrollo en silencio | `main.dart:39` |
| B-08 | Los ocho servicios están en el plan gratuito de Render (dominios `*.onrender.com`), que suspende instancias inactivas. Los cold starts de 30-50 s superan el `connectTimeout` de 45 s de `api_client.dart:69` de forma marginal | `api_client.dart:113-175` |

---

## 5. Lo que está bien resuelto

Vale la pena dejarlo por escrito, porque son decisiones acertadas que conviene no perder en la refactorización:

- **Arquitectura por features** con separación `data`/`domain`/`presentation` consistente y bien aplicada.
- **SQLCipher** (`sqflite_sqlcipher`) con clave AES-256 generada por `Random.secure()` y custodiada en el keystore del sistema — el enfoque correcto (`encryption_service.dart:21-25`).
- **Migraciones de BD idempotentes**: `_addColumnIfMissing` (`secure_database_service.dart:71-82`) previene el fallo permanente de apertura por `duplicate column`, con el razonamiento documentado. Poco común y muy sensato.
- **Suite de tests de seguridad** organizada por control MASVS (`test/security/masvs/`, `test/security/audit/pii_log_audit_test.dart`) — la intención de gobierno está ahí; falta corregir la cobertura señalada en C-01.
- **Filtro clínico de falsos positivos** (`SensorService.kt:403-483`): distinguir sueño (FC < 60 + reclinado), reposo verificado (FC 60-100 sostenida) y trabajo sedentario, con protección off-body, es un diseño de dominio serio y bien comentado.
- **Accesibilidad del `MainNavigationShell`** (semántica, objetivos de 48 px, feedback háptico) — es el estándar al que deberían subir las demás pantallas.
- **Honestidad técnica en los comentarios**: `SensorService.kt:57-64` documenta explícitamente que el SpO₂ no es medible con la API pública de Wear OS, y `computeHrvProxyMs` (líneas 293-302) aclara que no es rMSSD clínico. Ese tipo de nota evita que alguien confunda un proxy con un dato diagnóstico.
- **El patrón correcto de API ya existe en la plataforma**: todas las rutas `/dashboard/individual/*`, `/medical/latest`, `/sedentary/score` y `/gamification/profile` derivan el usuario del JWT y no aceptan parámetros. S-02 no pide inventar nada nuevo — pide extender a las rutas de empresa y familia lo que las individuales ya hacen bien.
- **Validación ejemplar en Notifications**: `required` + `maxLength` + `minLength` + `format: email` en todos sus DTOs. Es el estándar que S-05 propone replicar en los demás servicios, no una práctica ajena al equipo.
- **`additionalProperties: false` en todos los esquemas**, lo que rechaza campos desconocidos y cierra la puerta a *mass assignment* (OWASP API3).

---

## 6. Plan de remediación sugerido

> **Reordenado tras las pruebas del 6/08.** La autorización del backend salió sólida (S-02 y el rol admin refutados), así que el trabajo pesado de "auditar BOLA en todos los endpoints" ya no es necesario — basta con cerrar la única grieta (S-20). El riesgo real se concentra ahora en el **cliente** y en **S-20 + S-01**.

### Esta semana

1. **S-20** — **fallo de autorización confirmado.** Derivar `organization_id` del claim del token en `history/organization/{id}` (o contrastarlo y exigir rol de admin de org) y devolver `403` cuando no procede. Barato y confirmado — no esperar. Añadir test de regresión. *(~2 h)*
2. **S-01** — desactivar Swagger en producción en los 10 servicios expuestos. *(~2 h, alto retorno: reduce reconocimiento)*
3. ✅ **C-03** — corregido 6/08/2026: `applicationId` real (`com.lifebalance.app`, phone + wear) y `signingConfig` de release leído de `key.properties` (ya no cae a debug). Pendiente para el usuario: generar la keystore real con `keytool` y completar `android/key.properties` antes de publicar.
4. ✅ **C-01 + C-02** — corregido 6/08/2026: fail-closed real, hash sobre SPKI (no certificado completo), `dotenv` cargado también en el isolate de background. *(Pendiente, no bloqueante: migrar la entrega de pins a `--dart-define` en vez de `.env` — hoy sigue vía dotenv, funciona igual en ambos isolates pero con un archivo bundleado en vez de un valor de compilación.)*

*(Los antiguos puntos S-02/S-03 como "crítico esta semana" se retiran: S-02 refutado, S-03 rebajado a medio. S-07 sigue **sin probar** —son POST, no hice escrituras— pero el rol admin se aplica en las lecturas, señal razonable; queda como verificación, punto 4 de 7.4. Vale revisar si S-07 comparte el mismo patrón de S-20: leer el `organizationId`/`userId` del body sin verificar pertenencia.)*

### Bloquear el release móvil hasta resolver

6. ✅ **C-01 + C-02** — corregido (ver detalle arriba). Pendiente opcional: backup pins para rotación y migrar a `--dart-define`. Ligado a **S-04**: si el tráfico pasa por el gateway, se pinea un dominio en vez de ocho.
7. **C-04 + S-05** — dejar de fabricar valores clínicos en el cliente **y** poner `[Range]` reales en el servidor. Van juntos: hoy el cliente inventa datos para pasar una validación que quizá no existe. *(~1 día)*
8. **C-05 + C-06** — `SessionWiper` en logout, `allowBackup=false`, mover biométricos a almacenamiento cifrado. *(~1 día)*
9. **A-02** — silenciar logs de PHI en release. *(~3 h)*

### Sprint siguiente

10. **S-04** — enrutar la app por el API Gateway y aplicar rate limiting en el borde (crítico para `/Auth/login`). *(~2-3 días)*
11. **S-06** — calcular los puntos de gamificación en el servidor. *(~1 día)*
12. **A-03 + A-04** — módulo `Validators` centralizado y migración de todos los `TextField` a `TextFormField` con `Form`. *(~2 días)*
13. **A-06 + A-07** — reintentos por petición con jitter, e interceptor de refresh token (el endpoint `/Auth/refresh-token` **ya existe**). *(~1 día)*
14. **S-08 + S-10** — arreglar el registro de dispositivos y alinear `UserModel` con `AuthUserResponseDto`. Desbloquean push remoto y RBAC. *(~1 día)*
15. **A-01** — gating por rol en el router usando `roles[]` (con el control real en backend). *(~1 día)*
16. **A-08 + A-09** — `exported=false` y validación del emisor en el puente wear. *(~3 h)*
17. **M-06 + M-07 + M-10 + S-09** — bugs funcionales visibles para el usuario; sincronizar preferencias completas con `/preferences`. *(~2 días)*

### Backlog

18. **S-11 + S-12** — tipar payloads, restringir `/ml/dataset` y los endpoints de configuración.
19. **D-01** — migración a tokens de tema (empezar por los 4 archivos con más color hardcodeado).
20. **M-08 + M-09** — rediseño del puente wear→BD y persistencia del cursor médico.
21. **D-08** — borrado de cuenta y exportación de datos (requisito legal; conviene no dejarlo al final).
22. **M-03 + M-04** — `FLAG_SECURE`, app-lock biométrico (`AuthGate` ya está escrito), Crashlytics cableado.
23. **S-14** — retirar los endpoints "Compatibility" si ya nadie los consume.
24. Limpieza de código muerto (sección 2).

---

## 7. Plataforma de microservicios

### 7.1 Inventario y exposición

Doce servicios en Render, plan gratuito, dominios `*.onrender.com`. Estado observado el 6/08/2026:

| Servicio | OpenAPI público | Consumido por la app |
|---|---|---|
| Auth & Profile | **Sí** | Sí (login, perfil, cambio de contraseña) |
| API Gateway | **Sí** (3 rutas) | **No** |
| Ingestion | **Sí** | Sí (sync de lotes) |
| Medical Data | **Sí** | Sí (lecturas y batch) |
| ML Prediction | **Sí** | Sí (predicción, riesgo, recomendaciones) |
| Notifications & Alerts | **Sí** | Sí (parcialmente — ver S-08) |
| Dashboard | **Sí** | Sí (solo rutas `/individual/*`) |
| Sedentary Engine | **Sí** | Sí (actividad diaria) |
| Gamification | **Sí** | Sí (eventos, leaderboard) |
| Administration | **Sí** | No |
| Organization SaaS | No (responde `/health`) | No |
| Reporting | No | No |

---

### S-01 · Documentación OpenAPI publicada en producción — ✅ CORREGIDO (6/08/2026)
**OWASP API9:2023 (Improper Inventory Management) · OWASP M8**

`GET /swagger/v1/swagger.json` respondía sin autenticación en **10 de los 12 servicios** — **confirmado activo el 6/08/2026** (ver 7.3). Cualquiera obtenía el mapa completo: rutas, verbos, esquemas de request, nombres de campos y enums.

**Corregido.** Se guardó `UseSwagger()`/`UseSwaggerUI()` (o su equivalente `UseXSwagger()`) tras `if (app.Environment.IsDevelopment())` en los 10 servicios: ApiGateway, SedentaryEngineService, MLPredictionService, IngestionService, GamificationService, MedicalDataService, Auth_Profile, NotificationsAndAlerts, AdministrationService y DashboardService. Reporting y Organization ya lo tenían bien (patrón "Rule 7" del propio equipo, usado como referencia). Caso aparte: en **DashboardService** el comentario del código ya decía *"Development only"* pero la llamada `app.UseDashboardSwagger()` no tenía ningún `if` real — quedaba expuesto pese a la intención original.

Pendiente de builds/deploy en Render para que el fix quede activo en producción; el código ya está corregido en los 2 repos.

El caso más serio es el **Administration Service**, cuya propia descripción dice:

> *"Gestiona configuración global, catálogos, parámetros del sistema, feature flags, auditoría, logs centralizados, supervisión de microservicios y modo mantenimiento. **Acceso exclusivo para SUPERADMIN y SYSTEMADMINISTRATOR**."*

Y publica sin credenciales el listado de sus endpoints privilegiados: `PUT /api/v1/Maintenance/status`, `PUT /api/v1/Settings`, `POST /api/v1/Settings/reset`, `PATCH /api/v1/feature-flags/{id}/enable`, `GET /api/v1/Logs` (logs centralizados con `userId`, `correlationId` y `stackTrace`), `GET /api/v1/Audit/by-user/{userId}`.

Exponer el contrato no es en sí una brecha —la autorización sigue siendo el control— pero convierte un ataque a ciegas en uno dirigido, y elimina la fase de reconocimiento.

**Que Organization y Reporting no lo expongan demuestra que el equipo sabe desactivarlo**; es una inconsistencia de configuración, no una limitación técnica.

**Corrección**

```csharp
if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI();
}
```

Si se necesita el contrato en producción (para clientes internos), servirlo tras autenticación o desde una red privada. Y revisar que Render no esté sirviendo también `/swagger/index.html` en los servicios donde ya se desactivó el JSON.

---

### S-02 · Endpoints que reciben identificadores ajenos como parámetro — ~~CRÍTICO~~ → REFUTADO EN PRUEBAS
**OWASP API1:2023 (Broken Object Level Authorization)**

> **Resultado de las pruebas (ver 7.4):** el sondeo autenticado con un token `USER` pidiendo objetos ajenos devolvió **403 en 6 de 7 endpoints** (medical, sedentary, ml/risk, ml/recommendations, dashboard/company de org ajena y de la propia). La autorización a nivel de objeto **sí está implementada**. Este hallazgo, planteado como crítico a partir del contrato, **queda refutado** salvo por una excepción: `history/organization/{id}`, que se documenta aparte en **S-20**. El análisis original se conserva abajo como contexto de por qué el patrón levantaba la sospecha.

La plataforma tiene dos estilos mezclados. La mayoría de rutas individuales derivan el usuario del JWT y **no aceptan parámetros** — ese es el patrón correcto y está bien aplicado:

```
GET /api/v1/dashboard/individual/biometrics     ← sin params, deriva del token ✓
GET /api/v1/medical/latest                      ← sin params ✓
GET /api/v1/sedentary/score                     ← sin params ✓
```

Pero conviven con un conjunto amplio que **sí acepta el identificador del objetivo**:

| Servicio | Endpoint | Dato expuesto |
|---|---|---|
| Medical | `GET /api/v1/medical/biometrics/{userId}` | Biometría de cualquier usuario |
| Medical | `GET /api/v1/medical/family/{familyId}` | Datos médicos de una familia |
| ML | `GET /api/v1/ml/risk/{userId}` · `/risk-trend/{userId}` · `/recommendations/{userId}` | Perfil de riesgo de salud |
| Sedentary | `GET /api/v1/sedentary/user/{userId}` | Actividad individual |
| Sedentary | `GET /api/v1/sedentary/company/{companyId}/adherence` | Adherencia de una empresa |
| Dashboard | `GET /api/v1/dashboard/company?companyId=` (+9 rutas `/company/*`) | KPIs, heatmap, ranking, licencias, departamentos |
| Dashboard | `GET /api/v1/dashboard/family?familyId=` (+7 rutas `/family/*`) | Métricas familiares |
| Gamification | `/gamification/user/{userId}/rewards` · `/family/{familyId}/challenges` · `/challenges/organizations/{tenantId}` · `/rankings/families/{familyId}` | Perfil y rankings |
| Notifications | `GET /api/v1/history/organization/{organizationId}` | Historial de notificaciones de una organización |
| Administration | `GET /api/v1/Audit/by-user/{userId}` | Rastro de auditoría de un usuario |

**Las pruebas confirmaron que estos endpoints SÍ validan la pertenencia** (403 al pedir objetos ajenos). El patrón seguía siendo digno de sospecha por dos razones —que ahora quedan como recordatorio de higiene, no como fallo—:

1. El servicio Dashboard **modela explícitamente la multi-tenencia** (`AuthUserResponseDto` incluye `roles[]`, `familyId`, `companyId`), y el JWT lleva `organization_id`/`tenant_id` firmados: la pertenencia es verificable y, en efecto, se verifica.
2. `companyId` y `familyId` viajan como **query string**; aunque aquí el filtro funciona, es el sitio que más fácil se olvida al añadir un endpoint nuevo — de ahí que S-20 se colara.

**La corrección ya no es urgente para estos endpoints** (están cubiertos), pero conviene endurecer el patrón para que la próxima ruta no repita el descuido de S-20: contrastar el identificador contra los claims del token antes de consultar, o derivarlo directamente del token.

```csharp
var callerCompany = User.FindFirst("companyId")?.Value;
var isAdmin = User.IsInRole("SUPERADMIN") || User.IsInRole("COMPANYADMIN");
if (!isAdmin && callerCompany != companyId) return Forbid();
```

Mejor aún: eliminar el parámetro y derivarlo del token, como ya hacen las rutas `/individual/*`. Y añadir un test de integración por endpoint que falle si un usuario ajeno recibe `200`.

---

### S-03 · `PUT /api/v1/Settings` concentra demasiado poder — CRÍTICO → rebajado a MEDIO tras pruebas
**OWASP API5:2023 (Broken Function Level Authorization)**

> **Resultado de las pruebas (ver 7.4):** un token `USER` recibe **403** en `GET /Settings`, `/Logs`, `/feature-flags`, `/Audit`. La autorización por rol del Administration Service **funciona**, así que el vector "usuario cualquiera toca la configuración" queda **refutado**. Lo que persiste es una objeción de **diseño**, no de control de acceso: concentrar `allowAnonymousAccess` y las credenciales SMTP en un único `PUT` es frágil ante un token de administrador comprometido o un admin malicioso. Por eso baja de crítico a medio, pero no desaparece.

`UpdateSettingsRequest` → `SystemSettingsDto.rules` → `SystemRulesSettingsDto` incluye:

```json
"allowAnonymousAccess": { "type": "boolean" }
```

Un solo `PUT` con un token administrativo comprometido podría —según cómo se consuma esa bandera— **desactivar la autenticación de la plataforma**. Es un interruptor de este calibre sin, aparentemente, doble confirmación ni segregación de funciones.

El mismo endpoint expone y modifica `EmailSettingsDto` (`smtpHost`, `smtpPort`, `fromEmail`, `requireSsl`). Un `GET /api/v1/Settings` devuelve la configuración SMTP; un `PUT` permite **redirigir el correo saliente de la plataforma a un servidor del atacante**, capturando enlaces de restablecimiento de contraseña.

**Corrección:**

- Quitar `allowAnonymousAccess` del modelo de configuración. Una decisión así debe ser un despliegue, no un toggle en caliente.
- Segregar `PUT /Settings` en endpoints granulares con permisos distintos (`settings:email:write`, `settings:rules:write`).
- Nunca devolver credenciales o host SMTP en un `GET`; enmascarar como `smtp.****.com`.
- Registrar en auditoría inmutable todo cambio de configuración, con actor y valor anterior.

---

### S-04 · La app no pasa por el API Gateway — ALTO

`api_client.dart:113-175` define ocho `Provider<Dio>`, uno por microservicio, apuntando **directamente** a cada dominio `*.onrender.com`. `lifebalance-api-gateway.onrender.com` no aparece en el cliente.

El gateway es donde normalmente viven el rate limiting, la terminación de autenticación, el WAF, la correlación de trazas y el pinning de un único certificado. Al saltárselo:

- No hay límite de peticiones centralizado → el endpoint de login queda expuesto a fuerza bruta y a *credential stuffing* salvo que cada servicio implemente el suyo.
- Cada servicio publica su propio dominio → **ocho certificados que pinear** en lugar de uno (ver C-01: por eso el pinning de hoja es aquí especialmente frágil).
- La superficie externa es 8 veces mayor de lo necesario.

Su propio Swagger declara solo tres rutas (`/health`, `/health/live`, `/api/v1/gateway/services`), así que hoy no parece enrutar nada.

**Corrección:** enrutar todo el tráfico móvil por el gateway (`https://lifebalance-api-gateway.onrender.com/api/v1/...`), dejar los servicios en red privada y aplicar rate limiting por IP y por usuario en el borde, con límites agresivos en `/Auth/login` y `/Auth/forgot-password`.

---

### S-05 · Validación de entrada inconsistente entre servicios — ALTO
**OWASP API en general · contradice un comentario del código**

El Notifications Service **sí declara validación completa**:

```json
"SendPushDto": {
  "required": ["body", "title", "userId"],
  "properties": {
    "title": { "maxLength": 200, "minLength": 1 },
    "body":  { "maxLength": 5000, "minLength": 1 },
    "payload": { "maxLength": 4000 }
  }
}
"SendEmailDto": { "to": { "format": "email", "minLength": 1 } }
```

Los demás servicios revisados —Auth, Ingestion, Medical, ML, Sedentary, Gamification, Administration— **no declaran ni un solo `required`, `maxLength`, `minLength`, `minimum` o `maximum`** en sus esquemas.

Que Notifications sí lo haga descarta que sea un artefacto de Swashbuckle: cuando hay DataAnnotations, aparecen. La ausencia apunta a ausencia real.

Esto contradice directamente un comentario del cliente:

```dart
// offline_sync_service.dart:194-197
// El backend valida con [Range] estrictos (HeartRate 1-260, Spo2 1-100,
// DurationMinutes 1-1440).
```

`VitalSignSyncItem` no declara ningún rango. O el comentario está obsoleto, o la validación se hace con FluentValidation (que no emite al OpenAPI). **Conviene confirmarlo antes de apoyarse en esa suposición**, porque de ella depende la lógica de "descartar el lote ante un 400" de las líneas 268-280.

Nótese además la asimetría con C-04: el cliente fabrica valores para *pasar* una validación que quizá no existe, mientras que los valores realmente absurdos (altura 999999 de A-04) no los detiene nadie.

**Corrección:** DataAnnotations o FluentValidation en todos los DTOs, y `[Range]` explícito en las magnitudes fisiológicas:

```csharp
public record VitalSignSyncItem
{
    [Range(20, 260)]   public double HeartRate { get; init; }
    [Range(0, 300)]    public double Hrv { get; init; }
    [Range(50, 100)]   public double Spo2 { get; init; }
    [Range(0, 200_000)] public int Steps { get; init; }
}
```

Y limitar el tamaño de los lotes (`[MaxLength(500)]` en las colecciones de `SyncBatchRequest` y en `/medical/readings/batch`), hoy sin cota declarada.

---

### S-06 · Los puntos de gamificación los decide el cliente — ALTO
**OWASP API6:2023 (Unrestricted Access to Sensitive Business Flows)**

`GamificationEventRequest` acepta `points` como entero arbitrario, y el cliente lo envía tal cual:

```dart
// gamification_api_service.dart:75-81
await _dio.post('/gamification/events', data: {
  'eventType': eventType,
  'points': points,        // ← valor de confianza total
  ...
});
```

El valor sale de la base local del dispositivo (`offline_sync_service.dart:177-181` → `b.points` de la tabla `active_breaks`). Cualquiera con la app instalada y un proxy —o simplemente rooteando el dispositivo, aunque C-05/M-05 lo dificulten— puede otorgarse los puntos que quiera.

Existe `GET /api/v1/gamification/leaderboard`, lo que convierte esto en un incentivo real, no teórico. Si la gamificación llega a estar ligada a beneficios corporativos (premios, días libres, seguros), pasa de ser un problema de integridad a uno de fraude.

**Corrección:** que el servicio calcule los puntos a partir del `eventType` y de datos ya verificados en el servidor (sesiones de actividad de Ingestion), ignorando cualquier `points` que llegue del cliente. Añadir idempotencia por evento y un tope diario.

---

### S-07 · Endpoints de difusión masiva sin segregación aparente — ALTO
**OWASP API5:2023**

El Notifications Service publica, bajo el mismo esquema `Bearer` global y sin distinción visible de rol:

| Endpoint | Alcance |
|---|---|
| `POST /api/v1/emails/bulk` | `BulkEmailDto.to` es un array de destinatarios sin límite declarado |
| `POST /api/v1/push/broadcast` | `userIds[]`, o toda una `organizationId` / `familyId` / `departmentId` |
| `POST /api/v1/push/company` · `/family` · `/department` | Difusión por tenant |
| `POST /api/v1/notifications/bulk` | Array de notificaciones |
| `POST /api/v1/emails/send` | `isHtml: true` con `body` de hasta 5000 caracteres |

Si estos endpoints no exigen rol administrativo, un usuario autenticado puede enviar correo HTML arbitrario **desde el dominio y la reputación de LifeBalance** — un vector de phishing de calidad excepcional, dirigido a usuarios que ya confían en el remitente. Y en una app de salud, un push masivo con contenido falso ("tu lectura cardíaca es anómala") puede causar daño real.

También `POST /api/v1/alerts` (`CreateAlertDto.userId` es un campo del body): permitiría crear alertas médicas en la cuenta de otra persona.

**Corrección:** `[Authorize(Roles = "...")]` en todo lo que sea `bulk`, `broadcast` o dirigido por tenant; derivar `userId` del token en `CreateAlertDto`, `SendPushDto` y `SendNotificationDto` en lugar de leerlo del body; sanitizar el HTML de los correos con una allowlist; y aplicar cuotas por remitente.

---

### S-08 · El registro de dispositivos apunta a un endpoint inexistente — ALTO
**Bug funcional: las notificaciones push remotas no funcionan**

El cliente llama:

```dart
// notifications_api_service.dart:46-50
await _dio.post('/notifications/register-device', data: {
  'deviceId': deviceId,
  'token': fcmToken,
  'platform': 'android',
});
```

El contrato real es otro:

```json
"/api/v1/devices/register": {
  "post": { "requestBody": { "$ref": "#/components/schemas/DeviceRegistrationDto" } }
}
"DeviceRegistrationDto": {
  "required": ["deviceToken", "userId"],
  "properties": {
    "userId":      { "minLength": 1, "type": "string" },
    "deviceToken": { "maxLength": 2048, "minLength": 1 },
    "platform":    { "$ref": "#/components/schemas/DevicePlatform" }   // enum entero 0|1|2
  }
}
```

Cuatro discrepancias: la **ruta** no existe (`/notifications/register-device` no está en el contrato), el campo es `deviceToken` y no `token`, falta el `userId` **requerido**, y `platform` es un enum entero, no la cadena `'android'`.

El resultado sería un `404`, que además queda **silenciado**:

```dart
// device_registration_service.dart:85-87
} catch (e) {
  debugPrint('[DeviceRegistration] No se pudo registrar: $e');
}
```

Ningún dispositivo queda registrado → los push de FCM nunca llegan. Encaja con que la app dependa por completo de notificaciones locales.

**Corrección:** alinear ruta y payload con el contrato, y —dado que el registro es una precondición de una funcionalidad visible— reflejar el fallo en la UI en lugar de tragárselo. Idealmente el backend debería derivar `userId` del token y no aceptarlo del body: tal como está, un usuario podría registrar su token de dispositivo bajo el `userId` de otra persona y **recibir sus notificaciones**.

---

### S-09 · Las preferencias de notificación ya existen en el backend y el cliente las ignora — MEDIO

Refuerza y explica **M-10**. `UpdatePreferenceDto` del Notifications Service modela exactamente lo que `AlertSettingsScreen` recoge y guarda en `SharedPreferences` sin sincronizar:

```json
"receiveCriticalAlerts", "receiveReminders", "receiveGamification",
"allowedStartTime", "allowedEndTime",
"quietModeEnabled", "quietModeStart", "quietModeEnd",
"frequency", "language", "timezone"
```

El cliente solo envía tres booleanos:

```dart
// notifications_api_service.dart:155-166
Future<NotificationPreferences> updatePreferences({
  required bool pushEnabled,
  required bool emailEnabled,
  required bool wearEnabled,
}) async { ... _dio.put('/preferences', data: sent.toJson()); }
```

Así que el horario de operación y el modo silencio que el usuario configura **no llegan al servidor**, y por tanto tampoco los respeta el push remoto. El trabajo de backend ya está hecho; falta el cableado del cliente.

**Corrección:** mapear `AlertSettings` completo sobre `UpdatePreferenceDto` y usar el servidor como fuente de verdad, con `SharedPreferences` como caché.

---

### S-10 · El modelo de usuario del cliente no coincide con el del backend — MEDIO

Relacionado con **A-01**. El Dashboard Service describe al usuario así:

```json
"AuthUserResponseDto": {
  "userId", "email", "firstName", "lastName",
  "roles":     { "type": "array", "items": { "type": "string" } },
  "familyId":  { "type": "string" },
  "companyId": { "type": "string" }
}
```

El cliente lo modela así:

```dart
// user_model.dart
final String? role;      // ← singular, string; el backend manda un array
// no existe familyId ni companyId
```

`UserModel.fromJson` hace `role: json['role']` — si `/Profile/me` devuelve `roles` (plural, array), el campo queda **siempre `null`**. Es decir: además de que `role` no se usa en ninguna parte (A-01), es probable que ni siquiera se esté poblando.

Y sin `familyId`/`companyId`, la app no puede construir las vistas familiar y empresarial que el backend ya soporta — lo que a su vez explica por qué `IndividualDashboardScreen` quedó huérfana y por qué la pestaña `/admin` muestra datos locales en lugar de organizacionales.

**Corrección:** alinear `UserModel` con el contrato (`List<String> roles`, `familyId`, `companyId`), verificar la forma real de `/Profile/me` y usar `roles` para el gating de A-01.

---

### S-11 · Payloads sin tipar en Ingestion y ML — MEDIO
**OWASP API8:2023 (Security Misconfiguration)**

Dos endpoints aceptan JSON arbitrario sin esquema ni tope:

```json
"IngestionEventRequest": { "payload": { } }     // POST /api/v1/ingestion/events
"DatasetRequest":        { "data":    { } }     // POST /api/v1/ml/dataset
```

Un objeto sin esquema se deserializa a `object`/`JsonElement`. Sin límite de profundidad ni de tamaño, es un vector de agotamiento de memoria y CPU (JSON profundamente anidado, arrays enormes).

`POST /api/v1/ml/dataset` es además el más delicado: si alimenta el entrenamiento del modelo y no está restringido a administradores, permite **envenenamiento del dataset** — inyectar muestras que sesguen las predicciones de riesgo de salud de todos los usuarios.

**Corrección:** tipar ambos payloads con un esquema cerrado; si el polimorfismo es necesario, validar contra un JSON Schema y aplicar `MaxDepth` + límite de tamaño en `JsonSerializerOptions`. Restringir `/ml/dataset` a un rol de servicio, no a usuarios finales.

---

### S-12 · Endpoints de configuración operativa fuera del servicio de administración — MEDIO

Además del Administration Service, hay endpoints de configuración dispersos:

- `PUT /api/v1/ml/config` → `MlConfiguration { highRiskThreshold, mediumRiskThreshold, activeModelVersion }`. Alterar los umbrales cambia **qué se considera riesgo alto de salud** para toda la plataforma.
- `PUT /api/v1/config` (Sedentary) → `EngineConfiguration { inactivityThresholdMinutes, reminderCooldownMinutes, minimumDailySteps }`.

Ambos comparten el mismo `Bearer` global que los endpoints de usuario final, sin separación declarada. Un usuario normal que pueda tocarlos degrada el producto para todos.

**Corrección:** mover la configuración al Administration Service o, como mínimo, exigir rol administrativo y registrar los cambios en auditoría.

---

### 7.3 Resultados del sondeo activo (sin autenticación)

Ejecutado el 6/08/2026 con peticiones `GET` sin token, sobre los servicios del cliente. **Ninguna escritura.** El método para leer el resultado: si el endpoint devuelve cuerpo JSON, está sirviendo datos a un anónimo; si devuelve cuerpo vacío, está rechazando (401 en ASP.NET Core devuelve body vacío). Verificado por contraste — `/health` y `/dashboard/system` sí renderizan, confirmando que el sondeo distingue ambos casos.

**Endpoints protegidos correctamente (401 al anónimo, sin fuga):**

| Servicio | Endpoint probado | Resultado |
|---|---|---|
| Auth | `GET /api/v1/Profile/me` | vacío (401) ✓ |
| Administration | `GET /api/v1/Settings` | vacío (401) ✓ |
| Administration | `GET /api/v1/Logs` | vacío (401) ✓ |
| Administration | `GET /api/v1/Audit` | vacío (401) ✓ |
| Administration | `GET /api/v1/Maintenance/status` | vacío (401) ✓ |
| Administration | `GET /api/v1/Services/status` | vacío (401) ✓ |
| Administration | `GET /api/v1/feature-flags` | vacío (401) ✓ |
| Medical | `GET /api/v1/medical/biometrics/1` | vacío (401) ✓ |
| Sedentary | `GET /api/v1/sedentary/user/1` | vacío (401) ✓ |
| Sedentary | `GET /api/v1/sedentary/history?from=…&to=…` | vacío (401) ✓ |
| ML | `GET /api/v1/ml/risk/1` | vacío (401) ✓ |
| Dashboard | `GET /api/v1/dashboard/individual` | vacío (401) ✓ |
| Dashboard | `GET /api/v1/dashboard/summary` | vacío (401) ✓ |
| Dashboard | `GET /api/v1/dashboard/company?companyId=1` | vacío (401) ✓ |
| Notifications | `GET /api/v1/history/organization/1` | vacío (401) ✓ |
| Ingestion | `GET /api/v1/ingestion/sync/status` | vacío (401) ✓ |

**Conclusión:** la autenticación se aplica de forma consistente. No hay fuga de datos de salud, de administración ni de auditoría a un llamante anónimo. **Esto descarta "Broken Authentication" pero NO descarta BOLA/IDOR (S-02)**, que es un fallo de la capa de *autorización* y solo se manifiesta con un token válido pidiendo el objeto de otro usuario.

**Endpoints públicos confirmados (devuelven datos sin token):**

| Endpoint | Qué devuelve | Valoración |
|---|---|---|
| `GET /dashboard/system` | `environment: "Production"`, hora del servidor | Aceptable, pero revela entorno |
| `GET /dashboard/health` | estado de salud | Aceptable (health check) |
| `GET /dashboard/version` | `version`, `buildNumber: "1.0.0.20260728"`, **`commitHash: "git-sha-f82a9b"`** | **S-19** — fuga menor |
| `GET /swagger/v1/swagger.json` (10/12) | contrato completo | **S-01** confirmado, sigue activo |
| `GET /health`, `/health/ready` (todos) | estado + dependencias (Reporting revela `mongodb`) | Aceptable; ver S-15 |

**S-19 · Divulgación de metadatos de build — BAJO.** `GET /api/v1/dashboard/version` entrega a cualquier anónimo el `commitHash` y la fecha de build. Facilita correlacionar la versión desplegada con vulnerabilidades conocidas del commit. Restringir a usuarios autenticados o recortar a la versión semántica pública.

**Corrección de un hallazgo previo (S-16):** el sondeo demuestra que `/dashboard/system`, `/dashboard/health` y `/dashboard/version` **sí son públicos**. Por tanto el cliente hace bien en tratarlos como tales (`dashboard_api_service.dart:79-92`) — mi observación anterior de que devolverían 401 era incorrecta. S-16 queda **retirado**.

---

### 7.4 Resultados del sondeo AUTENTICADO (token de cuenta de prueba, rol USER)

Ejecutado el 6/08/2026 con el `accessToken` de una cuenta de prueba propia (`test@uttest.com`, rol `USER`, org `6a74cb17…`). Solo `GET`. Este sondeo **sí puede evaluar la autorización** (BOLA y rol), no solo la autenticación.

**Baseline (datos propios):**

| Endpoint | Resultado | Lectura |
|---|---|---|
| `GET /Profile/me` | **200** | token válido ✓ |
| `GET /dashboard/individual` | **200** | agregador responde ✓ |
| `GET /medical/latest` | **404** | la cuenta no tiene lecturas médicas |
| `GET /sedentary/score` | **404** | la cuenta no tiene score calculado |

**Sección BOLA/IDOR — pedir objetos de otro usuario/organización:**

| Endpoint (id/org ajeno) | Resultado | Veredicto |
|---|---|---|
| `GET /medical/biometrics/{ajeno}` | **403** | autorización correcta ✓ |
| `GET /sedentary/user/{ajeno}` | **403** | correcta ✓ |
| `GET /ml/risk/{ajeno}` | **403** | correcta ✓ |
| `GET /ml/recommendations/{ajeno}` | **403** | correcta ✓ |
| `GET /dashboard/company?companyId={org ajena}` | **403** | correcta ✓ |
| `GET /dashboard/company?companyId={TU org}` | **403** | un `USER` no ve agregados de empresa ni de su propia org — segregación por función correcta ✓ |
| `GET /notifications/history/organization/{org ajena}` | **200** (cuerpo `data:[]`) | **BOLA estructural — ver S-20** |

**Sección rol admin — endpoints de administración con token `USER`:**

| Endpoint | Resultado | Veredicto |
|---|---|---|
| `GET /admin/Settings` | **403** | rol aplicado ✓ |
| `GET /admin/Logs` | **403** | ✓ |
| `GET /admin/feature-flags` | **403** | ✓ |
| `GET /admin/Audit` | **403** | ✓ |
| `GET /admin/Audit/by-user/{ajeno}` | **403** | ✓ |

**Conclusión — corrige la severidad del informe:**

- **S-02 (BOLA) queda en gran parte REFUTADO.** Seis de siete endpoints con identificador ajeno devuelven `403`: la autorización a nivel de objeto **sí está implementada** en los datos de salud (medical, sedentary, ml, dashboard). Era mi segunda preocupación y la evidencia la desmonta. Baja de "crítico a verificar" a **"mayormente correcto, con una excepción (S-20)"**.
- **S-03 / S-07 (rol) — el peor escenario queda REFUTADO** para lectura: un `USER` recibe `403` en todos los endpoints de administración. La autorización por rol funciona. (Persisten S-01 —Swagger público— y la objeción de diseño sobre `allowAnonymousAccess` en el modelo de settings, que no se pudo ejercitar porque el `GET` ya da 403.)
- **Reporting: la premisa "el endpoint de historial no existe" es incorrecta.** `GET /sedentary/history` responde **200** con `{"data":[]}`. Junto a los `404` de `/medical/latest` y `/sedentary/score`, indica que **esta cuenta de prueba nunca sincronizó actividad** — para ella, los ceros son correctos (no hay nada que agregar), no un bug. Distinguir agregación-vs-datos en un usuario real exige repetir esto con una cuenta que sí haya subido lecturas desde el reloj.

---

### S-20 · `history/organization/{organizationId}` no verifica la pertenencia — ✅ CORREGIDO (6/08/2026)
**Antes: ALTO** *(BOLA estructural; fuga en vivo no reproducida)*

> **Estado: corregido.** `HistoryController.GetByOrganization` ahora exige que el `organizationId` de la ruta coincida con el claim `organization_id` del token, salvo rol `ADMIN` — mismo patrón que `GetAll()`. De paso se corrigió un BOLA de escritura hermano en el mismo archivo: `AlertsController.Create` aceptaba `CreateAlertDto.UserId` del body sin verificarlo contra el caller; ahora se sobreescribe con el `userId` del token salvo `ADMIN`. Añadidos tests de regresión en `HistoryControllerTests` y `AlertsControllerTests` (mismatch → `Forbid`, sin claim → `Forbid`, `ADMIN` → permitido). Repo: `NotificationsAndAlerts`, `HistoryController.cs` / `AlertsController.cs`.
**OWASP API1:2023 (BOLA)**

En el sondeo autenticado, **todos** los endpoints con identificador ajeno devolvieron `403` — **excepto** `GET /api/v1/history/organization/{organizationId}`, que devuelve **200**. Se investigó a fondo con dos cuentas (una de prueba y una real, ambas rol `USER`, en organizaciones distintas). Tres consultas resolvieron el mecanismo:

```
A) GET /history/user                          → 200, trae 1 notificación real del usuario,
                                                  con "organizationId": null (es personal)
B) GET /history/organization/<TU org>         → 200, {"data":[]}
C) GET /history/organization/<org ajena>      → 200, {"data":[]}
```

**Esto descarta la hipótesis "inocente".** Si el endpoint ignorara el parámetro y devolviera el historial del propio usuario, B y C habrían mostrado la notificación que sí aparece en A. Como **ambas salen vacías** mientras A trae datos, el endpoint **filtra realmente por el `organizationId` del path**. La org propia sale vacía porque las notificaciones del usuario son personales (`organizationId: null`) y no hacen match; las notificaciones *de organización* las generan los broadcasts de empresa/departamento (`POST /push/company`, `/push/department`, `/push/broadcast`).

Queda entonces demostrado lo esencial del fallo:

1. El endpoint **consulta por el `organizationId` que le pasas en la URL** (filtro real, no decorativo).
2. Devuelve **200, no 403**, para una organización a la que el usuario **no pertenece** — a diferencia de sus 6 endpoints hermanos, que sí devuelven 403 ante un objeto ajeno.
3. La verificación de pertenencia (contrastar el path contra el claim `organization_id` del token) **está ausente**.

La fuga en vivo **no se reprodujo** únicamente porque ninguna de las organizaciones probadas tenía notificaciones org-scoped que filtrar — es un vacío de datos, no un control que bloquee. Contra una organización con broadcasts (un mensaje de empresa, un aviso de departamento), un usuario de **otra** organización los leería pasando ese `organizationId`. Los títulos/cuerpos de esos broadcasts pueden contener información interna y contexto de salud.

**Severidad: alto.** BOLA estructural confirmado (control ausente); la única razón para no marcarlo crítico es que no se observó extracción de datos reales de un tercero — falta un tenant con datos org-scoped para la demostración final.

**Reproducción para la demostración definitiva** (requiere generar un broadcast, es decir una escritura con rol adecuado — no se hizo en esta auditoría, que fue de solo lectura):
1. Como admin de la organización X, enviar `POST /push/company` (o `/push/broadcast` con `organizationId: X`).
2. Con un token `USER` de una organización Y ≠ X, pedir `GET /history/organization/X`.
3. Si devuelve el broadcast de X → fuga entre inquilinos confirmada (subir a crítico e iniciar el proceso de notificación de incidente).

**Corrección:** que el handler derive `organization_id` del claim del token (ya viaja firmado) en vez de leerlo del path — o, si el parámetro debe permanecer, contrastarlo contra el claim y exigir rol de administrador de organización. Unificar además el código de respuesta con sus hermanos: `403` cuando no procede, nunca `200` vacío. Test de integración que falle si un `USER` de otra org recibe `200`.

---

### 7.2 Hallazgos menores de plataforma

| ID | Hallazgo |
|---|---|
| S-13 | **Esquemas de seguridad inconsistentes.** Administration declara `"type": "apiKey"` con `name: Authorization`; el resto usa `"type": "http", "scheme": "bearer"`. Funcionalmente equivalente, pero delata configuraciones copiadas sin revisar. |
| S-14 | **Endpoints "Compatibility" duplicados.** ML expone `/predictive-alerts`, `/recommendations` y `/sedentary-risk` compartiendo el mismo `PredictAlertRequest`; Sedentary expone `/active-breaks`, `/goals/reminders` y `/sedentary-score` con `SedentaryAlertRequest`. Superficie heredada que hay que asegurar y mantener por duplicado. Si ya nadie los usa, retirarlos. |
| S-15 | **`/health` bajo el `security` global.** Los tres servicios de salud (`/health`, `/health/live`, `/health/ready`) aparecen bajo el requisito `Bearer` global. Si no llevan `[AllowAnonymous]`, los health checks de Render fallarán; si lo llevan, el contrato miente. |
| ~~S-16~~ | **Retirado tras el sondeo** (ver 7.3): `/dashboard/system`, `/health` y `/version` sí son públicos; el cliente los trata bien. El `security` global del contrato incluía rutas con `[AllowAnonymous]`, lo que confirma S-15. |
| S-17 | **`priorityLabel` no existe en el contrato.** `createAlert` (`notifications_api_service.dart:74-81`) envía `priorityLabel: 'medium'`, campo ausente en `CreateAlertDto`. El propio comentario (líneas 60-64) admite que el enum `AlertPriority` (0-8) no está confirmado. Conviene cerrar el significado de esos nueve valores con el equipo backend y documentarlo. |
| S-18 | **Plan gratuito de Render.** Las instancias inactivas se suspenden; el arranque en frío ronda 30-50 s, contra un `connectTimeout` de 45 s (`api_client.dart:69`). Con doce servicios, la probabilidad de que al menos uno esté frío en cada sesión es alta. El `RetryWithBackoffInterceptor` ayuda, pero arrastra el bug A-06. Para producción con datos de salud conviene además revisar las garantías contractuales de residencia y cifrado del proveedor. |

---

## Limitaciones de esta auditoría

- El cliente se revisó de forma **estática**: no se compiló el proyecto, no se ejecutaron los tests ni se hicieron pruebas dinámicas (proxy MITM, análisis del APK, fuzzing).
- **Del backend se leyeron los documentos OpenAPI y se sondearon los endpoints sin token** (solo `GET`, sin escrituras; ver 7.3). No se revisó código de servidor, configuración de despliegue, base de datos ni políticas de IAM. El sondeo confirmó que la autenticación se aplica (401 al anónimo en todo lo sensible), pero **no se hicieron pruebas con credenciales**: S-02 (BOLA), S-03 y S-07 (rol además de token) y S-06 siguen siendo patrones de riesgo *a verificar con dos cuentas de prueba*, no vulnerabilidades confirmadas.
- Ausencia de validación en el OpenAPI no prueba ausencia de validación: FluentValidation y la lógica de dominio no se emiten al contrato. S-05 se apoya en el contraste con Notifications (que sí declara constraints), pero conviene confirmarlo en código.
- No se revisaron `ios/`, `web/`, Organization SaaS, Reporting, ni los flujos de CI/CD.
- Los hallazgos de cumplimiento (LFPDPPP/GDPR/HIPAA) son observaciones técnicas, no asesoría legal. Conviene contrastarlas con el área jurídica antes de tomar decisiones de producto.

### Estado de verificación tras las pruebas del 6/08/2026

Ya ejecutado con cuenta de prueba propia (rol `USER`), resultados en 7.4:

- **S-02 (BOLA): refutado** — 403 en 6/7 endpoints con id ajeno.
- **S-03 / S-07 (rol admin): peor escenario refutado** — 403 en los 5 endpoints de administración.
- **S-20: BOLA estructural confirmado** — probado con dos cuentas. `history/user` demuestra que el usuario tiene una notificación (`organizationId: null`); `history/organization/<propia>` y `<ajena>` salen ambas vacías. Eso prueba que el endpoint **filtra por el `organizationId` del path** (no ignora el param) y **responde 200, no 403, cross-tenant** (sin verificar pertenencia). La fuga en vivo no se reprodujo por falta de datos org-scoped, no por un control. Detalle y repro en el hallazgo S-20.

Verificaciones que **aún requieren** escrituras o datos org-scoped:

1. **S-20 (demostración final)**: generar un broadcast en una org X (`POST /push/company`) y, desde un `USER` de otra org, pedir `history/organization/X`. Si devuelve el broadcast → fuga entre inquilinos, subir a crítico. (Es una escritura; no se hizo en esta auditoría de solo lectura.)
2. **Reporting/agregación**: repetir el sondeo con una cuenta que **sí** haya sincronizado actividad, para distinguir "sin datos" (lo que vimos) de "datos presentes pero mal agregados".
3. **S-06 (puntos de gamificación)**: enviar un `POST /gamification/events` con `points` arbitrario desde la cuenta de prueba y verificar si el servidor lo acepta tal cual.
4. **S-07 (difusión)**: `POST /emails/bulk` y `/push/broadcast` con token `USER` — ¿403 o se envía?

Conviene dejar los casos 1-4 como tests de integración permanentes, no como comprobación puntual.
