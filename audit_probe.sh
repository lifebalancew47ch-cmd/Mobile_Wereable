#!/usr/bin/env bash
# Pruebas de autorización LifeBalance — cuenta de PRUEBA test@uttest.com
# Uso:  TOKEN="<accessToken fresco>" bash audit_probe.sh
# El accessToken caduca a los 30 min: vuelve a hacer login antes de correrlo.
set -u

# Pega aquí el accessToken FRESCO (recién sacado del login). Caduca en 30 min.
# Si prefieres, exporta TOKEN por fuera y esto lo respeta: TOKEN=eyJ... bash audit_probe.sh
TOKEN="${TOKEN:-PEGA_AQUI_EL_ACCESSTOKEN}"
if [ "$TOKEN" = "PEGA_AQUI_EL_ACCESSTOKEN" ]; then
  echo "Falta el accessToken: pasa TOKEN=\"...\" o edita audit_probe.sh" >&2
  exit 1
fi
: "${TOKEN:?Falta el accessToken}"

AUTH="Authorization: Bearer $TOKEN"
MINE_ORG="6a74cb174079b221cea5151c"      # organization_id de tu token
FAKE_ID="000000000000000000000000"        # id que NO es tuyo (24 hex)
FAKE_ORG="ffffffffffffffffffffffff"        # org que NO es tuya

AUTH_URL="https://lifebalance-auth-service.onrender.com/api/v1"
MED="https://medical-service-hb0v.onrender.com/api/v1"
SED="https://sedentary-engine-service.onrender.com/api/v1"
ML="https://ml-prediction-service-0sqa.onrender.com/api/v1"
DASH="https://lifebalance-dashboard-service.onrender.com/api/v1"
ADM="https://lifebalance-administration-service.onrender.com/api/v1"
NOT="https://lifebalance-notifications-api.onrender.com/api/v1"

code() { # $1=metodo $2=url  -> imprime "HTTP <codigo>"
  curl -s -o /dev/null -w "HTTP %{http_code}" -X "$1" -H "$AUTH" "$2"
}
body() { curl -s -H "$AUTH" "$1"; }

echo "===================================================================="
echo " 0. BASELINE (tus propios datos — se espera 200)"
echo "===================================================================="
echo -n "  Profile/me            "; code GET "$AUTH_URL/Profile/me"; echo
echo -n "  medical/latest        "; code GET "$MED/medical/latest"; echo
echo -n "  sedentary/score       "; code GET "$SED/sedentary/score"; echo
echo -n "  dashboard/individual  "; code GET "$DASH/dashboard/individual"; echo

echo
echo "===================================================================="
echo " 1. REPORTING — ¿hay datos históricos? (pregunta de los ceros)"
echo "===================================================================="
echo -n "  sedentary/history     "; code GET "$SED/sedentary/history?from=2026-07-01T00:00:00Z&to=2026-08-06T23:59:59Z"; echo
echo "  --- cuerpo (mira si trae filas o viene vacio) ---"
body "$SED/sedentary/history?from=2026-07-01T00:00:00Z&to=2026-08-06T23:59:59Z"; echo

echo
echo "===================================================================="
echo " 2. BOLA / IDOR — pedir objetos que NO son tuyos (se espera 403/404)"
echo "    Un 200 CON DATOS aqui = fuga de datos de salud de terceros."
echo "===================================================================="
echo -n "  medical/biometrics/<ajeno>   "; code GET "$MED/medical/biometrics/$FAKE_ID"; echo
echo -n "  sedentary/user/<ajeno>       "; code GET "$SED/sedentary/user/$FAKE_ID"; echo
echo -n "  ml/risk/<ajeno>              "; code GET "$ML/ml/risk/$FAKE_ID"; echo
echo -n "  ml/recommendations/<ajeno>   "; code GET "$ML/ml/recommendations/$FAKE_ID"; echo
echo -n "  dashboard/company <org ajena>"; code GET "$DASH/dashboard/company?companyId=$FAKE_ORG"; echo
echo -n "  dashboard/company <TU org>   "; code GET "$DASH/dashboard/company?companyId=$MINE_ORG"; echo
echo -n "  notif/history/org <ajena>    "; code GET "$NOT/history/organization/$FAKE_ORG"; echo
echo "  (Si 'dashboard/company <TU org>' da 200 pero deberia ser solo-admin,"
echo "   es escalada de funcion: un USER viendo agregados de empresa.)"

echo
echo "===================================================================="
echo " 3. AUTORIZACION POR ROL — endpoints admin con token USER (se espera 403)"
echo "    Un 200 aqui = Broken Function Level Authorization (critico)."
echo "===================================================================="
echo -n "  admin/Settings        "; code GET "$ADM/Settings"; echo
echo -n "  admin/Logs            "; code GET "$ADM/Logs"; echo
echo -n "  admin/feature-flags   "; code GET "$ADM/feature-flags"; echo
echo -n "  admin/Audit           "; code GET "$ADM/Audit"; echo
echo -n "  admin/Audit/by-user   "; code GET "$ADM/Audit/by-user/$FAKE_ID"; echo

echo
echo "===================================================================="
echo " Resumen de lectura:"
echo "  200 en secciones 2 y 3  -> vulnerabilidad confirmada"
echo "  403/401/404 en 2 y 3     -> autorizacion correcta"
echo "  200 + filas en seccion 1 -> los ceros de Reporting son de agregacion,"
echo "                              no de falta de datos"
echo "===================================================================="
