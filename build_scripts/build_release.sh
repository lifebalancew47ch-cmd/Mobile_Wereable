#!/usr/bin/env bash
# =============================================================================
# LifeBalance — Script de build de producción (C-01 fix 07/08/2026)
#
# Uso:
#   chmod +x build_scripts/build_release.sh
#   ./build_scripts/build_release.sh
#
# Requiere:
#   - Flutter SDK en el PATH
#   - Variables de entorno definidas (o editar los valores abajo)
#   - Keystore de producción configurada en android/key.properties
#
# IMPORTANTE: nunca commitear este script con valores reales rellenos.
# Usar variables de entorno del CI/CD (GitHub Actions Secrets, GitLab CI
# Variables, etc.) para inyectar los valores sensibles.
# =============================================================================

set -euo pipefail

# ---------------------------------------------------------------------------
# Configuración — leer desde variables de entorno del CI o sobreescribir aquí
# ---------------------------------------------------------------------------

API_URL="${API_URL:-https://lifebalance-auth-service.onrender.com/api/v1}"
DASHBOARD_API_URL="${DASHBOARD_API_URL:-https://lifebalance-dashboard-service.onrender.com/api/v1}"
NOTIFICATIONS_API_URL="${NOTIFICATIONS_API_URL:-https://lifebalance-notifications-api.onrender.com/api/v1}"
INGESTION_API_URL="${INGESTION_API_URL:-https://ingestion-service-fouo.onrender.com/api/v1}"
GAMIFICATION_API_URL="${GAMIFICATION_API_URL:-https://gamification-service-9o3z.onrender.com/api/v1}"
SEDENTARY_API_URL="${SEDENTARY_API_URL:-https://sedentary-engine-service.onrender.com/api/v1}"
MEDICAL_API_URL="${MEDICAL_API_URL:-https://medical-service-hb0v.onrender.com/api/v1}"
ML_API_URL="${ML_API_URL:-https://ml-prediction-service-0sqa.onrender.com/api/v1}"

# Pins SPKI SHA-256 (hex, separados por coma).
# Regenerar con:
#   openssl s_client -connect <host>:443 -servername <host> < /dev/null \
#     | openssl x509 -pubkey -noout \
#     | openssl pkey -pubin -outform der | openssl dgst -sha256
# El valor actual corresponde a onrender.com + intermediaria GTS WE1.
# ACTUALIZAR si Render rota la clave pública (distinto de renovar el cert).
PINNED_CERT_SHA256="${PINNED_CERT_SHA256:-97:70:15:23:4E:DF:51:32:BF:96:84:20:E1:E0:87:44:C6:8F:AE:B4:03:83:A1:FE:4A:7B:52:0C:68:D9:45:5D,0A:85:F2:0B:27:5E:C6:2A:CD:F5:FE:7C:A7:CE:D7:58:7A:30:EE:2A:13:E5:D1:0F:A0:E9:28:5F:67:22:86:55}"

# ---------------------------------------------------------------------------
# Verificaciones previas
# ---------------------------------------------------------------------------

if [[ -z "${PINNED_CERT_SHA256}" ]]; then
  echo "❌ ERROR: PINNED_CERT_SHA256 no configurado. El build de release no puede"
  echo "   proceder sin pins TLS — CertificatePinning.isConfigured sería false"
  echo "   y la app rechazaría TODAS las conexiones HTTPS (fail-closed)."
  exit 1
fi

echo "🔒 Iniciando build de producción con pins TLS configurados..."
echo "   Pins: ${PINNED_CERT_SHA256:0:60}..."

# ---------------------------------------------------------------------------
# Clean + get
# ---------------------------------------------------------------------------
flutter clean
flutter pub get

# ---------------------------------------------------------------------------
# Build Android APK (release)
# ---------------------------------------------------------------------------
flutter build apk --release \
  --dart-define="API_URL=${API_URL}" \
  --dart-define="DASHBOARD_API_URL=${DASHBOARD_API_URL}" \
  --dart-define="NOTIFICATIONS_API_URL=${NOTIFICATIONS_API_URL}" \
  --dart-define="INGESTION_API_URL=${INGESTION_API_URL}" \
  --dart-define="GAMIFICATION_API_URL=${GAMIFICATION_API_URL}" \
  --dart-define="SEDENTARY_API_URL=${SEDENTARY_API_URL}" \
  --dart-define="MEDICAL_API_URL=${MEDICAL_API_URL}" \
  --dart-define="ML_API_URL=${ML_API_URL}" \
  --dart-define="PINNED_CERT_SHA256=${PINNED_CERT_SHA256}"

echo "✅ APK generado: build/app/outputs/flutter-apk/app-release.apk"

# ---------------------------------------------------------------------------
# Build Android App Bundle (para Play Store)
# ---------------------------------------------------------------------------
flutter build appbundle --release \
  --dart-define="API_URL=${API_URL}" \
  --dart-define="DASHBOARD_API_URL=${DASHBOARD_API_URL}" \
  --dart-define="NOTIFICATIONS_API_URL=${NOTIFICATIONS_API_URL}" \
  --dart-define="INGESTION_API_URL=${INGESTION_API_URL}" \
  --dart-define="GAMIFICATION_API_URL=${GAMIFICATION_API_URL}" \
  --dart-define="SEDENTARY_API_URL=${SEDENTARY_API_URL}" \
  --dart-define="MEDICAL_API_URL=${MEDICAL_API_URL}" \
  --dart-define="ML_API_URL=${ML_API_URL}" \
  --dart-define="PINNED_CERT_SHA256=${PINNED_CERT_SHA256}"

echo "✅ AAB generado: build/app/outputs/bundle/release/app-release.aab"

# ---------------------------------------------------------------------------
# Verificación post-build: confirmar que .env no está en el APK
# ---------------------------------------------------------------------------
APK_PATH="build/app/outputs/flutter-apk/app-release.apk"
if unzip -l "${APK_PATH}" 2>/dev/null | grep -q "\.env"; then
  echo "❌ ADVERTENCIA: se encontró un archivo .env dentro del APK."
  echo "   Verificar que pubspec.yaml no incluye .env en flutter.assets."
  exit 1
else
  echo "✅ Verificación: ningún archivo .env empaquetado en el APK."
fi

echo ""
echo "🎉 Build de producción completado exitosamente."
