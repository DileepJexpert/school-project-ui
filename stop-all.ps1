# Stop backend and worker processes
Get-Process | Where-Object { $_.ProcessName -match "workerd" } | Stop-Process -Force -ErrorAction SilentlyContinue
Write-Host "Services stopped." -ForegroundColor Green
