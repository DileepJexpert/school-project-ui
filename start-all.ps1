<#
.SYNOPSIS
    Starts the School Management Cloudflare Worker backend and then the Flutter frontend in sequence.
.USAGE
    .\start-all.ps1
#>

$ErrorActionPreference = "Continue"
$rootDir = $PSScriptRoot
if (-not $rootDir) {
    $rootDir = Get-Location
}

Write-Host "========================================================" -ForegroundColor Cyan
Write-Host "  School Management System - Full Stack Startup" -ForegroundColor Cyan
Write-Host "========================================================" -ForegroundColor Cyan
Write-Host ""

# 1. Start Cloudflare Worker in a separate terminal window
Write-Host "[1/2] Starting Cloudflare Worker Backend on port 8787..." -ForegroundColor Yellow
$workerDir = Join-Path $rootDir "cloudflare\worker"

Start-Process cmd.exe -ArgumentList "/k cd /d `"$workerDir`" && title School Backend (Wrangler) && echo Starting Wrangler dev... && npx wrangler dev"

Write-Host "Waiting for backend to be ready on http://127.0.0.1:8787..." -ForegroundColor Gray
$ready = $false
for ($i = 1; $i -le 25; $i++) {
    Start-Sleep -Seconds 2
    try {
        $req = [System.Net.WebRequest]::Create("http://127.0.0.1:8787/docs")
        $req.Timeout = 1500
        $resp = $req.GetResponse()
        if ($resp.StatusCode -eq 200) {
            $resp.Close()
            $ready = $true
            break
        }
        $resp.Close()
    } catch {
        Write-Host "  Waiting for backend ($i/25)..." -ForegroundColor DarkGray
    }
}

if ($ready) {
    Write-Host ""
    Write-Host "[SUCCESS] Backend is live at http://127.0.0.1:8787" -ForegroundColor Green
} else {
    Write-Host ""
    Write-Host "[Notice] Proceeding to launch frontend..." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "[2/2] Starting Flutter Web Frontend (Chrome)..." -ForegroundColor Yellow
Write-Host "  Target API URL: http://localhost:8787/api" -ForegroundColor Gray
Write-Host ""

Set-Location $rootDir
flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:8787/api
