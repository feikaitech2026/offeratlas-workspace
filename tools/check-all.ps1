$ErrorActionPreference = "Stop"

$workspace = Split-Path -Parent $PSScriptRoot
$failures = New-Object System.Collections.Generic.List[string]

function Invoke-Check {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string[]]$Command
    )

    Write-Host ""
    Write-Host "== $Name ==" -ForegroundColor Cyan

    if (-not (Test-Path $Path)) {
        Write-Host "路径不存在：$Path" -ForegroundColor Red
        $script:failures.Add($Name)
        return
    }

    Push-Location $Path
    try {
        & $Command[0] @($Command[1..($Command.Length - 1)])
        if ($LASTEXITCODE -ne 0) {
            throw "Exit code $LASTEXITCODE"
        }
    }
    catch {
        Write-Host "检查失败：$Name - $_" -ForegroundColor Red
        $script:failures.Add($Name)
    }
    finally {
        Pop-Location
    }
}

Invoke-Check `
    -Name "Core API tests" `
    -Path (Join-Path $workspace "offeratlas-core-api") `
    -Command @("mvn", "test")

Invoke-Check `
    -Name "Pro frontend build" `
    -Path (Join-Path $workspace "OfferAtlas Pro") `
    -Command @("npm", "run", "build")

Invoke-Check `
    -Name "Student frontend build" `
    -Path (Join-Path $workspace "OfferAtlas Student") `
    -Command @("npm", "run", "build")

Invoke-Check `
    -Name "DataAdmin frontend build" `
    -Path (Join-Path $workspace "OfferAtlas DataAdmin") `
    -Command @("npm", "run", "build")

Invoke-Check `
    -Name "DataAdmin API tests" `
    -Path (Join-Path $workspace "offeratlas-data-admin-api") `
    -Command @(".\.venv\Scripts\python.exe", "-m", "pytest")

Invoke-Check `
    -Name "ScholarGraph syntax check" `
    -Path (Join-Path $workspace "OfferAtlas ScholarGraph") `
    -Command @(".\.venv\Scripts\python.exe", "-m", "compileall", "app")

Invoke-Check `
    -Name "Crawler syntax check" `
    -Path (Join-Path $workspace "OfferAtlas Crawler") `
    -Command @(".\.venv\Scripts\python.exe", "-m", "compileall", "src")

Write-Host ""
if ($failures.Count -gt 0) {
    Write-Host "以下检查失败：" -ForegroundColor Red
    $failures | ForEach-Object { Write-Host "- $_" -ForegroundColor Red }
    exit 1
}

Write-Host "全部检查通过。" -ForegroundColor Green
