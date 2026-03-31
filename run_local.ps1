# ============================================================
#   Blauplug Trading Platform — Local Runner (No Docker)
#   This script automates the setup and execution of the
#   microservices on a Windows host.
# ============================================================

$services = @(
    "api-gateway",
    "market-data"
)

$rootDir = Get-Location

# ── Step 1: Initialize Node.js API ──────────────────────────
Write-Host "`n[1/3] Initializing Node.js API..." -ForegroundColor Green
Start-Process npm -ArgumentList "install" -WorkingDirectory (Join-Path $rootDir "backend") -Wait

# ── Step 2: Initialize Simulation Environment ────────────────
Write-Host "`n[2/3] Initializing Simulation Venv..." -ForegroundColor Green
if (!(Test-Path (Join-Path $rootDir "venv"))) {
    Start-Process python -ArgumentList "-m venv venv" -WorkingDirectory $rootDir -Wait
}
$pipPath = Join-Path $rootDir "venv/Scripts/pip.exe"
Start-Process $pipPath -ArgumentList "install requests python-dotenv" -NoNewWindow -Wait

# ── Step 3: Launch Services ──────────────────────────────────
Write-Host "`n[3/3] Launching Data API Platform..." -ForegroundColor Green

# 1. Start Node.js API
Write-Host "  - Starting Node.js API (Port 8000)..."
Start-Process powershell -ArgumentList "-NoExit", "-Command", "npm run dev" -WorkingDirectory (Join-Path $rootDir "backend")

# 2. Start Simulation Engine
Write-Host "  - Starting Simulation Engine..."
Start-Process powershell -ArgumentList "-NoExit", "-Command", ".\venv\Scripts\activate; python simulate.py" -WorkingDirectory $rootDir

Write-Host "`nAll services launched!" -ForegroundColor Yellow
Write-Host "Check the new terminals for logs."
Write-Host "To start the dashboard, run 'flutter run -d chrome' in flutter_dashboard folder.`n"
