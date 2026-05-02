$ErrorActionPreference = "Stop"

$workspace = Split-Path -Parent $PSScriptRoot
$runtimeRoot = Join-Path $workspace "tmp\local-stack"
$pidDir = Join-Path $runtimeRoot "pids"
$composeFile = Join-Path $workspace "offeratlas-core-api\docker-compose.local.yml"
$legacyContainers = @(
    "scholargraph-api",
    "scholargraph-postgres",
    "scholargraph-redis",
    "scholargraph-meilisearch"
)

function Write-Step {
    param([string]$Message)
    Write-Host ""
    Write-Host "== $Message ==" -ForegroundColor Cyan
}

function Stop-RecordedService {
    param([string]$Name)

    $safeName = $Name.ToLowerInvariant().Replace(" ", "-")
    $pidFile = Join-Path $pidDir "$safeName.pid"

    if (-not (Test-Path $pidFile)) {
        Write-Host "$Name has no PID record. Skip." -ForegroundColor Yellow
        return
    }

    $pidValue = (Get-Content $pidFile -ErrorAction SilentlyContinue | Select-Object -First 1).Trim()
    if (-not $pidValue) {
        Remove-Item $pidFile -Force -ErrorAction SilentlyContinue
        Write-Host "$Name PID file was empty and has been removed." -ForegroundColor Yellow
        return
    }

    $process = Get-Process -Id $pidValue -ErrorAction SilentlyContinue
    if ($process) {
        & taskkill /PID $pidValue /T /F | Out-Null
        Write-Host "$Name stopped. PID=$pidValue" -ForegroundColor Green
    }
    else {
        Write-Host "$Name process no longer exists. Cleaning PID file." -ForegroundColor Yellow
    }

    Remove-Item $pidFile -Force -ErrorAction SilentlyContinue
}

function Stop-ContainersByName {
    param(
        [Parameter(Mandatory = $true)][string[]]$Names,
        [Parameter(Mandatory = $true)][string]$Label
    )

    $running = @()
    foreach ($name in $Names) {
        $containerId = ((& docker ps -aq --filter "name=^/$name$" 2>$null) | Select-Object -First 1 | Out-String).Trim()
        if (-not $containerId) {
            continue
        }
        $state = ((& docker inspect -f "{{.State.Running}}" $containerId 2>$null) | Out-String).Trim()
        if ($LASTEXITCODE -eq 0 -and $state -eq "true") {
            $running += $containerId
        }
    }

    if ($running.Count -eq 0) {
        return
    }

    Write-Step $Label
    & docker stop @running | Out-Null
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to stop containers: $($running -join ', ')"
    }
    Write-Host "Stopped containers: $($running -join ', ')" -ForegroundColor Green
}

Write-Step "Stop local app processes"
$services = @(
    "OfferAtlas DataAdmin",
    "OfferAtlas Student",
    "OfferAtlas Pro",
    "DataAdmin API",
    "Core API",
    "ScholarGraph"
)

foreach ($service in $services) {
    Stop-RecordedService -Name $service
}

Write-Step "Stop infra containers"
if (Test-Path $composeFile) {
    Push-Location (Join-Path $workspace "offeratlas-core-api")
    try {
        & docker compose -f $composeFile stop postgres redis minio meilisearch
        if ($LASTEXITCODE -ne 0) {
            throw "Docker Compose stop failed with exit code $LASTEXITCODE"
        }
        Write-Host "Infra containers stopped." -ForegroundColor Green
    }
    finally {
        Pop-Location
    }
}
else {
    Write-Host "Compose file not found. Skip docker stop." -ForegroundColor Yellow
}

Stop-ContainersByName -Names $legacyContainers -Label "Stop legacy ScholarGraph containers"

Write-Step "Done"
Write-Host "Use the root launcher to start everything again." -ForegroundColor Green
