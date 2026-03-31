Write-Host "==========================="
Write-Host " Starting Blauplug V2 App  "
Write-Host "==========================="

Write-Host "1. Starting V2 Node.js Backend..."
Start-Process powershell -ArgumentList "-NoExit -Command cd backend; npm run dev"

Start-Sleep -Seconds 3

Write-Host "2. Starting V2 Simulation Engine..."
Start-Process powershell -ArgumentList "-NoExit -Command .\venv\Scripts\Activate.ps1; python .\simulate.py"

Write-Host "3. Starting V2 Flutter Dashboard (Chrome)..."
Start-Process powershell -ArgumentList "-NoExit -Command cd flutter_dashboard; flutter clean; flutter run -d chrome --web-port 8081"

Write-Host "All systems booting up. Close the individual windows to stop."
