# Ejecutar la app en teléfono Android conectado por USB
# Requiere: backend en localhost:8000 (docker compose up)

$adb = "$env:LOCALAPPDATA\Android\sdk\platform-tools\adb.exe"
if (-not (Test-Path $adb)) {
    Write-Error "adb no encontrado. Instale Android SDK platform-tools."
    exit 1
}

& $adb reverse tcp:8000 tcp:8000
Write-Host "Puerto 8000 redirigido PC -> telefono (adb reverse)"

flutter run `
  --dart-define=API_URL=http://127.0.0.1:8000 `
  --dart-define=WS_URL=ws://127.0.0.1:8000
