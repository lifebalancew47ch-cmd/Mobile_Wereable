# Pruebas de autorizacion LifeBalance - cuenta de PRUEBA test@uttest.com
# Ejecutar en PowerShell:
#   1) Pega el accessToken FRESCO (login de nuevo; caduca a los 30 min) entre las comillas de $Token
#   2) cd a la carpeta del proyecto
#   3) powershell -ExecutionPolicy Bypass -File .\audit_probe.ps1
#      (o si ya estas dentro de PowerShell:  .\audit_probe.ps1 )

# ---- PEGA AQUI EL TOKEN FRESCO ----
$Token = $env:TOKEN
if (-not $Token) { $Token = "PEGA_AQUI_EL_ACCESSTOKEN" }
# -----------------------------------

if ($Token -eq "PEGA_AQUI_EL_ACCESSTOKEN" -or -not $Token) {
  Write-Host "Falta el token: pega el accessToken en la variable `$Token o usa `$env:TOKEN" -ForegroundColor Red
  exit 1
}

$Headers  = @{ Authorization = "Bearer $Token" }
$MINE_ORG = "6a74cb174079b221cea5151c"          # tu organization_id
$FAKE_ID  = "000000000000000000000000"           # id que NO es tuyo
$FAKE_ORG = "ffffffffffffffffffffffff"            # org que NO es tuya

$AUTH = "https://lifebalance-auth-service.onrender.com/api/v1"
$MED  = "https://medical-service-hb0v.onrender.com/api/v1"
$SED  = "https://sedentary-engine-service.onrender.com/api/v1"
$ML   = "https://ml-prediction-service-0sqa.onrender.com/api/v1"
$DASH = "https://lifebalance-dashboard-service.onrender.com/api/v1"
$ADM  = "https://lifebalance-administration-service.onrender.com/api/v1"
$NOT  = "https://lifebalance-notifications-api.onrender.com/api/v1"

function Code($label, $url) {
  try {
    $r = Invoke-WebRequest -Uri $url -Headers $Headers -Method GET -UseBasicParsing -TimeoutSec 90
    "{0,-32} HTTP {1}" -f $label, [int]$r.StatusCode
  } catch {
    if ($_.Exception.Response) { "{0,-32} HTTP {1}" -f $label, [int]$_.Exception.Response.StatusCode }
    else { "{0,-32} ERR {1}" -f $label, $_.Exception.Message }
  }
}

function Body($url) {
  try {
    $r = Invoke-WebRequest -Uri $url -Headers $Headers -Method GET -UseBasicParsing -TimeoutSec 90
    $r.Content
  } catch {
    if ($_.Exception.Response) { "HTTP " + [int]$_.Exception.Response.StatusCode + " (sin cuerpo util)" }
    else { "ERR " + $_.Exception.Message }
  }
}

Write-Host "===================================================================="
Write-Host " 0. BASELINE (tus propios datos - se espera 200)"
Write-Host "===================================================================="
Code "Profile/me"            "$AUTH/Profile/me"
Code "medical/latest"        "$MED/medical/latest"
Code "sedentary/score"       "$SED/sedentary/score"
Code "dashboard/individual"  "$DASH/dashboard/individual"

Write-Host ""
Write-Host "===================================================================="
Write-Host " 1. REPORTING - hay datos historicos? (pregunta de los ceros)"
Write-Host "===================================================================="
$hist = "$SED/sedentary/history?from=2026-07-01T00:00:00Z&to=2026-08-06T23:59:59Z"
Code "sedentary/history" $hist
Write-Host "  --- cuerpo (mira si trae filas o viene vacio) ---"
Body $hist

Write-Host ""
Write-Host "===================================================================="
Write-Host " 2. BOLA / IDOR - pedir objetos que NO son tuyos (se espera 403/404)"
Write-Host "    Un 200 CON DATOS aqui = fuga de datos de salud de terceros."
Write-Host "===================================================================="
Code "medical/biometrics <ajeno>"   "$MED/medical/biometrics/$FAKE_ID"
Code "sedentary/user <ajeno>"       "$SED/sedentary/user/$FAKE_ID"
Code "ml/risk <ajeno>"              "$ML/ml/risk/$FAKE_ID"
Code "ml/recommendations <ajeno>"   "$ML/ml/recommendations/$FAKE_ID"
Code "dashboard/company <org ajena>" "$DASH/dashboard/company?companyId=$FAKE_ORG"
Code "dashboard/company <TU org>"    "$DASH/dashboard/company?companyId=$MINE_ORG"
Code "notif/history/org <ajena>"     "$NOT/history/organization/$FAKE_ORG"

Write-Host ""
Write-Host "===================================================================="
Write-Host " 3. AUTORIZACION POR ROL - endpoints admin con token USER (se espera 403)"
Write-Host "    Un 200 aqui = Broken Function Level Authorization (critico)."
Write-Host "===================================================================="
Code "admin/Settings"       "$ADM/Settings"
Code "admin/Logs"           "$ADM/Logs"
Code "admin/feature-flags"  "$ADM/feature-flags"
Code "admin/Audit"          "$ADM/Audit"
Code "admin/Audit/by-user"  "$ADM/Audit/by-user/$FAKE_ID"

Write-Host ""
Write-Host "===================================================================="
Write-Host " Lectura:  200 en secciones 2 y 3 = vulnerabilidad confirmada."
Write-Host "           403/401/404 en 2 y 3    = autorizacion correcta."
Write-Host "           200 + filas en seccion 1 = ceros de Reporting son de"
Write-Host "                                       agregacion, no de falta de datos."
Write-Host "===================================================================="
