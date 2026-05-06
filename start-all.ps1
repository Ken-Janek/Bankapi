# start-all.ps1 — Local dev starter (no Docker needed)
$root = $PSScriptRoot

$services = @(
  @{ name="user-service";     port=3001 },
  @{ name="account-service";  port=3002 },
  @{ name="transfer-service"; port=3003 },
  @{ name="gateway";          port=3000 }
)

foreach ($svc in $services) {
  $dir = Join-Path $root $svc.name
  Write-Host "Starting $($svc.name) on :$($svc.port)..." -ForegroundColor Cyan
  Start-Process powershell -ArgumentList "-NoExit","-Command","cd '$dir'; node index.js"
  Start-Sleep -Seconds 2
}

Write-Host ""
Write-Host "All services started!" -ForegroundColor Green
Write-Host "  API:     http://localhost:3000/api/v1" -ForegroundColor Yellow
Write-Host "  Swagger: http://localhost:3000/docs"   -ForegroundColor Yellow
