# Plan de mejora de seguridad — LifeBalance

> **Actualización (6/ago/2026, misma sesión):** los ítems 1.1, 1.2, 1.3, 1.4, M-01, M-02, A-05 y A-06 de este plan ya se implementaron en código (ver detalle en cada sección, marcado "✅ implementado"). 1.5 se implementó parcialmente (el guard existe en `role_guard.dart` pero no se conectó a `/admin` — ver esa sección). Nada de esto se compiló ni se corrió en un dispositivo/emulador real: sigue aplicando la Fase 0 antes de publicar.

**Fecha:** 6 de agosto de 2026
**Base:** hallazgos de `AUDIT.md` (6/ago/2026) + revisión adicional de `fog_engine.dart`, `offline_sync_service.dart` y `.github/workflows/devsecops.yml` (ver evaluación previa en esta conversación).
**Criterio de priorización:** explotabilidad × impacto sobre datos de salud, no solo severidad OWASP nominal.

Este plan asume que los seis hallazgos marcados "✅ Corregido" en `AUDIT.md` (C-01 a C-06) **no están verificados** — se escribieron sin correr `flutter test` ni compilar. Por eso la Fase 0 no es opcional aunque el audit los dé por cerrados.

---

## Resumen ejecutivo del roadmap

| Fase | Objetivo | Duración estimada | Bloquea release |
|---|---|---|---|
| 0 | Verificar que los fixes ya aplicados realmente funcionan | 1-2 días | Sí |
| 1 | Cerrar los bloqueantes que ni el audit ni los fixes tocaron | 1 semana | Sí |
| 2 | Hallazgos altos restantes (cliente) | 1-2 semanas | No, pero antes de escalar usuarios |
| 3 | Endurecer el pipeline DevSecOps | 3-5 días | No |
| 4 | Backend / API Gateway (los 12 microservicios) | 2-3 semanas | Sí para producción abierta |
| 5 | Gobierno continuo | Recurrente | — |

---

## Fase 0 — Verificar antes de confiar (1-2 días)

Nada de lo marcado "corregido" entra a producción sin esto:

1. **Compilar y correr la suite completa.** `flutter pub get && flutter analyze --fatal-warnings && flutter test`. Prestar atención especial a `test/security/masvs/network_tls_test.dart` y al nuevo `test/security/spki_extractor_test.dart`.
2. **Probar el certificate pinning end-to-end contra el servidor real**, no solo el parser SPKI aislado: generar el pin con el comando `openssl` documentado en `certificate_pinning.dart`, meterlo en `.env.production`, compilar `--release`, y confirmar que una MITM (mitmproxy/Charles con su propia CA) es rechazada. Ahora mismo `.env.production` está vacío — sin este paso, el fail-closed corregido en C-01 nunca se ha ejercitado con un pin real.
3. **Generar la keystore de release** (`keytool -genkey -alias lifebalance -keyalg RSA -keysize 2048 -validity 10000`), completar `android/key.properties`, y confirmar que `assembleRelease` falla limpio sin ella y firma correcto con ella. Verificar que `wear/build.gradle.kts` usa el mismo `applicationId` (`com.lifebalance.app`) — un mismatch rompe el empaquetado del Wear OS APK dentro del APK del teléfono.
4. **Confirmar en el backend que S-01 (Swagger público) y S-20 (BOLA en `history/organization/{id}`) están desplegados**, no solo commiteados. El audit dice "pendiente de deploy" — revisar que el deploy ocurrió antes de dar el hallazgo por cerrado.
5. **Repetir el sondeo de la sección 7.3/7.4 del audit** tras el deploy, con la misma cuenta de prueba, para confirmar 403 donde antes había 200.

**Criterio de salida de Fase 0:** captura de pantalla o log de CI de `flutter test` en verde + confirmación de MITM rechazada + confirmación de los dos endpoints corregidos en producción.

---

## Fase 1 — Bloqueantes no cubiertos por el audit existente (1 semana)

### 1.1 Escrituras a SQLite sin `await` en `FogEngine` (crítico — pérdida silenciosa de datos) — ✅ implementado
`core/fog_engine.dart:219,232,250,269,309,315` — seis llamadas a `insertActivitySession`/`logAlert` sin `await`, fuera del alcance del `try/catch` de `_analyzeWindow`.

- Envolver cada llamada en `await` + `try/catch` local.
- Añadir una cola de reintento acotada en memoria (`Queue<PendingWrite>`, cap ~50) para escrituras fallidas, con flush al recuperar espacio/DB.
- Capturar `DatabaseException` específicamente para distinguir `SQLITE_FULL`/I-O de otros errores, y exponer `storageHealthProvider` (Riverpod) que la UI pueda leer.
- **Aceptación:** test que fuerza una excepción en `insertActivitySession` (mock) y confirma que `FogEngine` la registra en la cola de reintento en vez de perderla.

### 1.2 `ClientBatchId` no idempotente (crítico — duplicación de datos médicos) — ✅ implementado (versión simplificada)
`services/offline_sync_service.dart:491-496` — el ID se genera aleatorio en cada intento, no se persiste antes del POST.

- Derivar el ID determinísticamente: hash (SHA-256, 16 bytes) de los IDs locales ordenados + rango de timestamps del lote.
- Persistir el `pending_batch_id` en SQLite **antes** de la llamada HTTP (nueva tabla `sync_attempts(batch_id, row_ids, created_at, status)`), y reutilizarlo en reintentos hasta que el servidor confirme o hasta expirar (p. ej. 24 h, luego se emite lote nuevo).
- **Aceptación:** test de integración que simula un timeout tras el POST (servidor procesó, cliente no vio la respuesta) y confirma que el reintento usa el mismo `ClientBatchId`.

**Lo que se implementó realmente (versión simplificada, sin tabla nueva):** `_stableBatchId()` en `offline_sync_service.dart` deriva el ID con FNV-1a 64 bits (puro Dart, sin dependencias) a partir de `deviceId` + los IDs locales ordenados del lote (vitals/sessions/alerts), en vez de un ID aleatorio por intento. Mismo conjunto de filas no sincronizadas -> mismo `ClientBatchId` automáticamente, sin necesitar persistir nada aparte (el propio contenido de la fila SQLite ya es la fuente de verdad). No se usó SHA-256 ni el paquete `crypto` para no añadir una dependencia solo para esto -- no hace falta que sea criptográfico, solo estable. **Pendiente real:** confirmar en el backend que `ClientBatchId` efectivamente se usa como clave de deduplicación (este fix solo garantiza que el cliente lo reenvíe igual; la garantía de idempotencia final es del servidor).

### 1.3 `AuthGate` (bloqueo biométrico) huérfano — ✅ implementado
`core/security/auth_gate.dart` está completo pero nunca se instancia (M-04 del audit, marcado medio — lo subo a bloqueante porque es una app de salud sin bloqueo de reapertura).

- Insertarlo como ruta intermedia entre `/splash` y `/dashboard` en `app_router.dart`, activable/desactivable desde `SettingsScreen`.

**Implementado:** nueva ruta `/auth-gate`, redirect en `app_router.dart` (gatea cualquier ruta protegida si `AppLockPreferences.isBiometricLockEnabled()` es `true` y `appUnlockedThisSession` sigue en `false`), toggle en `SettingsScreen` (apagado por defecto -- opt-in, para no bloquear a usuarios existentes en la actualización sin aviso), y fallback en `AuthGate` que deja pasar si el dispositivo no tiene biometría/PIN configurado (`NotAvailable`/`NotEnrolled`/`PasscodeNotSet`) en vez de dejar al usuario sin acceso a su propia app. **No re-bloquea al volver de background** dentro del mismo proceso (solo en arranque en frío) -- requeriría un `WidgetsBindingObserver`, fuera de alcance de este fix.

### 1.4 Crashlytics desconectado — ✅ implementado
`main.dart` nunca conecta `FlutterError.onError` ni `PlatformDispatcher.instance.onError`. Sin esto, los fallos silenciosos de 1.1 seguirían siendo invisibles en telemetría aunque se corrijan parcialmente.

```dart
FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
PlatformDispatcher.instance.onError = (error, stack) {
  FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
  return true;
};
```

### 1.5 Control de acceso por rol (A-01 del audit) — implementado, sin conectar
`UserModel.role` se parsea y nunca se lee. `/admin` es visible para todo usuario.

Se creó `lib/core/security/role_guard.dart` (widget `RoleGuard`, listo para envolver una ruta), pero **no se conectó** a `/admin` en `app_router.dart`. Antes de confirmarlo se preguntó explícitamente si esa pantalla es un panel multi-tenant real o un resumen de uso general — la respuesta fue "no estoy seguro", así que aplicar el gate a ciegas se descartó por riesgo de romper la navegación principal (tab central con FAB) para la mayoría de los usuarios.

**Pendiente:** confirmar con producto/equipo qué usuarios deben ver `AdminSummaryScreen`. Si es admin-only: envolver la ruta en `app_router.dart` con `RoleGuard(allowedRoles: {'ADMIN','SUPERADMIN'}, child: const AdminSummaryScreen())` y, si aplica, ocultar el tab en `main_navigation_shell.dart` para roles no admin. Recordar: esto es solo UX/defensa en profundidad — la autorización real debe vivir (y ya vive, según 7.4 del audit) en el backend.

### 1.6 Ruteo por API Gateway + rate limiting (S-04 del audit)
Hoy cada uno de los 12 microservicios se llama directo desde el móvil, sin gateway. Sin rate limiting, `/Auth/login` es fuerza-bruta-able.

- Mover las 8 URLs base en `api_client.dart` a apuntar al gateway (`API_GATEWAY_URL`).
- En el gateway: rate limit agresivo por IP+usuario en `/Auth/login` y `/Auth/forgot-password` (p. ej. 5 intentos / 15 min), moderado en el resto.
- Consolida además el certificate pinning a un solo dominio (hoy son 8 certificados que pinear).

---

## Fase 2 — Altos restantes del audit (1-2 semanas)

Orden sugerido por relación esfuerzo/impacto:

1. **M-02** — ✅ implementado. `flutter_secure_storage` sin `AndroidOptions(encryptedSharedPreferences: true)`. En vez de forzar re-login, se implementó una migración de arranque (`secure_storage.dart`: `migrateLegacySecureStorageIfNeeded()`, llamada al inicio de `main()` antes de tocar la BD o cualquier token) que copia los valores del backend heredado al nuevo antes de que se necesiten -- esto importaba especialmente para la clave AES de `EncryptionService`: perderla habría hecho que el código generara una nueva creyendo que no existía, dejando la base SQLCipher local ilegible y borrándola por completo. `EncryptionService` mantiene un campo tipado `FlutterSecureStorage` explícito (aunque apunta a la misma instancia) porque `test/security/masvs/secure_storage_test.dart` verifica estáticamente esa referencia en el archivo -- si se toca de nuevo, no romper ese test.
2. **A-03 / A-04** — `Validators` centralizado + migrar `TextField` → `TextFormField` con `Form` en login, forgot-password y perfil biométrico. El patrón correcto ya existe en `settings_screen.dart` y `alert_settings_screen.dart`; replicarlo.
3. **A-02** — wrapper `AppLog.d()` no-op fuera de `kDebugMode`; regla ProGuard para `Log.d/v/i` en release. 76 llamadas de logging a auditar, priorizar las 6 que exponen HR/HRV/pasos/varianza listadas en el audit.
4. **M-03** — `FLAG_SECURE` en pantallas con datos de salud (dashboard, perfil biométrico, historial médico).
5. **A-05** — ✅ implementado. En vez de convertir el diálogo en `StatefulWidget`, se envolvió `_showChangePasswordDialog` en un `try/finally` que hace `.clear()` + `.dispose()` de los tres `TextEditingController` sin importar cómo termine (guardar, cancelar, o error de `changePassword`) -- más simple que la reestructuración completa y con el mismo efecto.
6. **A-06** — ✅ implementado. Contador de reintentos movido a `err.requestOptions.extra['_retry_count']` (por petición, ya no compartido entre peticiones concurrentes), `await` real en el retry (antes era un `Future.delayed` sin esperar, que podía llamar `handler.next()` dos veces), backoff exponencial real (`baseDelay * (1 << count)`, antes era lineal pese al nombre de la clase) + jitter aleatorio de hasta 200ms.
7. **A-08 / A-09** — `android:exported="false"` en `SensorService`/`BootReceiver` del Wear OS app; validar `sourceNodeId` y tamaño máximo de payload (256 KB) en `WearMessageListenerService`.
8. **A-07** — implementar el flujo de refresh token (ya existe `getRefreshToken()` sin consumidor) con `QueuedInterceptor` para evitar estampida de refrescos concurrentes.
9. **C-05 / C-06 (re-verificar)** — confirmar que el `SessionWiper` de logout realmente purga `SharedPreferences` con datos biométricos, no solo el secure storage, y que `allowBackup="false"` quedó en ambos manifiestos (app + wear).

---

## Fase 3 — Endurecer el pipeline DevSecOps (3-5 días)

Sobre `.github/workflows/devsecops.yml` actual (gitleaks + flutter analyze + android lint + Trivy fs + tests + build debug):

1. **Eliminar el job duplicado** — `sast-android` y `android-lint` hacen lo mismo con configuración distinta; quedarse con uno solo bien configurado (sin `|| true` que enmascara fallos).
2. **Añadir build de release real**, no solo debug, con verificación de que la firma **no** es la keystore de debug:
   ```yaml
   - run: flutter build apk --release
   - name: Verificar que no está firmado con debug keystore
     run: |
       jarsigner -verify -verbose -certs build/app/outputs/flutter-apk/app-release.apk | grep -q "CN=Android Debug" && exit 1 || exit 0
   ```
3. **Trivy sobre el APK/imagen construida**, no solo el filesystem del repo — hoy solo escanea dependencias declaradas, no el artefacto final.
4. **SBOM** (`syft` o `cyclonedx`) generado por build y publicado como artifact, para poder responder rápido a un CVE nuevo sin tener que reconstruir.
5. **Gate de cobertura sobre `test/security/**`** — que el pipeline falle si los tests MASVS existentes bajan de cobertura, no solo que existan.
6. **DAST programado (no bloqueante)** — OWASP ZAP baseline scan semanal contra los entornos de staging de los 12 microservicios, con reporte a un canal de alertas.
7. **Dependabot/Renovate** para `pubspec.yaml` y `build.gradle.kts` — hoy no hay actualización automática de dependencias, solo el escaneo puntual de Trivy.
8. **Branch protection en `main`**: exigir el pipeline completo en verde + al menos una revisión antes de merge. (Proceso, no código — verificar en GitHub Settings.)

---

## Fase 4 — Backend / API Gateway (2-3 semanas, fuera del repo móvil)

Del audit, lo que depende de los servicios y no de la app:

1. **S-04** — gateway con rate limiting real (ver 1.6).
2. **S-01** — quitar o autenticar Swagger en los 10 servicios expuestos; si se mantiene para desarrollo, restringirlo a IPs internas o a un entorno no productivo.
3. **S-20** — confirmar en producción que `history/organization/{id}` deriva `organization_id` del JWT y ya no del path (ver Fase 0.4).
4. **Validación de DTOs** — Auth, Ingestion, Medical, ML, Sedentary, Gamification, Administration no declaran `required`/`maxLength`/`minimum`/`maximum` en sus esquemas (a diferencia de Notifications, que sí lo hace bien — usarlo como referencia interna). Añadir DataAnnotations/FluentValidation, con `[Range]` explícito en magnitudes fisiológicas (HR 1-260, SpO₂ 1-100, etc.) para que el servidor rechace lo que el cliente ya no debería enviar tras la Fase 2.2.
5. **Gamificación** — que el servicio calcule los puntos desde `eventType` y datos ya verificados de Ingestion, ignorando cualquier `points` que llegue del cliente; añadir idempotencia por evento y tope diario.
6. **`POST /api/v1/ml/dataset`** — restringir a rol admin; sin esto es una vía de envenenamiento del dataset de riesgo de salud.

---

## Fase 5 — Gobierno continuo

- **Rotación de secretos**: pins de respaldo (backup pins) para `PINNED_CERT_SHA256` antes de la próxima renovación de certificado en Render; política de rotación de la clave de firma JWT del backend.
- **Definition of Done de seguridad**: ninguna feature que toque datos de salud se marca lista sin un test en `test/security/` que la cubra.
- **Re-sondeo trimestral** de los 12 microservicios (mismo método que la sección 7 del audit) — la superficie crece con cada servicio nuevo.
- **Revisión de amenazas al añadir features**: cualquier endpoint nuevo que reciba `userId`/`companyId`/`familyId` como parámetro en vez de derivarlo del JWT entra a revisión obligatoria antes de merge (el patrón que causó S-20).

---

## Resumen de cambios de código aplicados en esta sesión

También se corrigió **M-01** (no estaba en las fases de arriba, es del `AUDIT.md` original): `token_service.dart` aceptaba como válido para siempre cualquier token sin `exp` decodificable -- opaco, truncado, corrupto, o con firma inválida. Ahora se rechaza, con 30s de margen de tolerancia por desfase de reloj.

Archivos nuevos: `lib/core/security/secure_storage.dart`, `lib/core/security/app_lock_preferences.dart`, `lib/core/security/role_guard.dart` (implementado, sin conectar -- ver 1.5).

Archivos modificados: `lib/core/fog_engine.dart`, `lib/models/fog_state.dart`, `lib/services/offline_sync_service.dart`, `lib/core/security/auth_gate.dart`, `lib/core/routes/app_router.dart`, `lib/features/settings/presentation/settings_screen.dart`, `lib/main.dart`, `lib/core/security/token_service.dart`, `lib/core/security/encryption_service.dart`, `lib/core/network/api_client.dart`, `lib/features/auth/presentation/screens/login_screen.dart`, `lib/features/profile/presentation/screens/biometric_profile_screen.dart`.

**Nada de esto se compiló ni se corrió** (el entorno de esta sesión no tuvo acceso a un toolchain de Flutter/Dart ni a un dispositivo). Antes de publicar, correr como mínimo: `flutter analyze --fatal-warnings` y `flutter test` (especialmente `test/security/masvs/secure_storage_test.dart`, que se verificó a mano contra los cambios de M-02), y probar en un dispositivo real el flujo de bloqueo biométrico (1.3) y una actualización desde una versión anterior para confirmar que la migración de Secure Storage (M-02) no deja a un usuario existente deslogueado o, peor, con la base de datos local ilegible.

## Qué NO hacer

- No cerrar hallazgos como "corregido" sin evidencia de test/build en verde (ver Fase 0).
- No usar `debugPrint`/`Log.d` para datos de salud "solo en desarrollo" — no se elimina en release, hay que envolverlo explícitamente (1.4 y A-02).
- No añadir rate limiting solo en el cliente (p. ej. deshabilitar el botón de login tras 5 intentos) como sustituto del rate limiting de servidor — es UX, no control de seguridad, y no habría sobrevivido ni un `curl` en loop.
