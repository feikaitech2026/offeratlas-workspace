$ErrorActionPreference = "Stop"

$workspace = Split-Path -Parent $PSScriptRoot
$pidDir = Join-Path $workspace "tmp\local-stack\pids"
$managedPorts = [ordered]@{
    "ScholarGraph" = 8000
    "Core API" = 18080
    "DataAdmin API" = 8010
    "OfferAtlas Pro" = 5173
    "OfferAtlas Student" = 5174
    "OfferAtlas DataAdmin" = 6173
}
$managedContainers = @(
    "offeratlas-postgres",
    "offeratlas-redis",
    "offeratlas-meilisearch",
    "offeratlas-minio"
)
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

function Get-PortRow {
    param(
        [string]$Name,
        [int]$Port
    )

    $conn = Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $conn) {
        return [PSCustomObject]@{
            Service = $Name
            Port = $Port
            State = "DOWN"
            Pid = ""
            Process = ""
        }
    }

    $proc = Get-Process -Id $conn.OwningProcess -ErrorAction SilentlyContinue
    return [PSCustomObject]@{
        Service = $Name
        Port = $Port
        State = "UP"
        Pid = $conn.OwningProcess
        Process = if ($proc) { $proc.ProcessName } else { "" }
    }
}

function Get-ContainerRow {
    param([string]$Name)

    $containerId = ((& docker ps -aq --filter "name=^/$Name$" 2>$null) | Select-Object -First 1 | Out-String).Trim()
    if (-not $containerId) {
        return [PSCustomObject]@{
            Container = $Name
            State = "MISSING"
        }
    }

    $state = (& docker inspect -f "{{.State.Status}}" $containerId 2>$null)
    return [PSCustomObject]@{
        Container = $Name
        State = (($state | Out-String).Trim()).ToUpperInvariant()
    }
}

Write-Step "Managed app ports"
$portRows = foreach ($entry in $managedPorts.GetEnumerator()) {
    Get-PortRow -Name $entry.Key -Port $entry.Value
}
$portRows | Format-Table -AutoSize

Write-Step "Managed docker containers"
$managedContainers | ForEach-Object { Get-ContainerRow -Name $_ } | Format-Table -AutoSize

Write-Step "Legacy ScholarGraph containers"
$legacyContainers | ForEach-Object { Get-ContainerRow -Name $_ } | Format-Table -AutoSize

Write-Step "PID files"
if (Test-Path $pidDir) {
    $files = Get-ChildItem $pidDir -File -ErrorAction SilentlyContinue
    if ($files) {
        $files | Select-Object Name, LastWriteTime | Format-Table -AutoSize
    }
    else {
        Write-Host "No PID files." -ForegroundColor Yellow
    }
}
else {
    Write-Host "PID directory not found." -ForegroundColor Yellow
}
