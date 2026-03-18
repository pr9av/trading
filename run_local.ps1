# ============================================================
#   Blauplug Trading Platform — Local Runner (No Docker)
#   This script automates the setup and execution of the
#   microservices on a Windows host.
# ============================================================

$services = @(
    "api-gateway",
    "market-data",
    "order-management",
    "trade-execution",
    "ai-signal"
)

$rootDir = Get-Location

# ── Step 1: Initialize Virtual Envs ────────────────────────
Write-Host "`n[1/2] Initializing Virtual Environments..." -ForegroundColor Green

foreach ($service in $services) {
    $serviceDir = Join-Path $rootDir "services/$service"
    Write-Host "  Processing $service..." -ForegroundColor Cyan
    
    # Check if venv exists, if not create it
    if (!(Test-Path (Join-Path $serviceDir "venv"))) {
        Write-Host "    - Creating venv..."
        Start-Process python -ArgumentList "-m venv venv" -WorkingDirectory $serviceDir -Wait
    }
    
    # Install/Update requirements
    Write-Host "    - Installing dependencies..."
    $pipPath = Join-Path $serviceDir "venv/Scripts/pip.exe"
    $reqPath = Join-Path $serviceDir "requirements.txt"
    Start-Process $pipPath -ArgumentList "install -r $reqPath" -NoNewWindow -Wait
}

# ── Step 2: Launch Services ────────────────────────────────
Write-Host "`n[2/2] Launching Backend Services..." -ForegroundColor Green

foreach ($service in $services) {
    $serviceDir = Join-Path $rootDir "services/$service"
    Write-Host "  - Starting $service in its own terminal..."
    
    $command = "cd $serviceDir; .\venv\Scripts\activate; python main.py"
    Start-Process powershell -ArgumentList "-NoExit", "-Command", $command
}

Write-Host "`nAll 5 microservices launched!" -ForegroundColor Yellow
Write-Host "Remember to start your Postgres and Redis before running this script."
Write-Host "To start the dashboard, run 'flutter run -d chrome' in flutter_dashboard folder.`n"
