$ErrorActionPreference = "Stop"

$workspace = Split-Path -Parent $PSScriptRoot
$runtimeRoot = Join-Path $workspace "tmp\local-stack"
$logDir = Join-Path $runtimeRoot "logs"
$pidDir = Join-Path $runtimeRoot "pids"
$composeFile = Join-Path $workspace "offeratlas-core-api\docker-compose.local.yml"
$legacyContainers = @(
    "scholargraph-api",
    "scholargraph-postgres",
    "scholargraph-redis",
    "scholargraph-meilisearch"
)

New-Item -ItemType Directory -Force -Path $runtimeRoot, $logDir, $pidDir | Out-Null

function Write-Step {
    param([string]$Message)
    Write-Host ""
    Write-Host "== $Message ==" -ForegroundColor Cyan
}

function Ensure-Command {
    param([string]$Name)
    if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
        throw "Missing command: $Name"
    }
}

function Ensure-File {
    param(
        [string]$Path,
        [string]$Label
    )
    if (-not (Test-Path $Path)) {
        throw "$Label not found: $Path"
    }
}

function Ensure-PythonModule {
    param(
        [Parameter(Mandatory = $true)][string]$PythonExe,
        [Parameter(Mandatory = $true)][string]$ModuleName,
        [Parameter(Mandatory = $true)][string]$RequirementsFile,
        [Parameter(Mandatory = $true)][string]$WorkingDirectory,
        [Parameter(Mandatory = $true)][string]$ServiceName
    )

    Push-Location $WorkingDirectory
    try {
        & $PythonExe -c "import $ModuleName"
        if ($LASTEXITCODE -eq 0) {
            return
        }

        Write-Host "$ServiceName missing Python module '$ModuleName'. Installing requirements..." -ForegroundColor Yellow
        & $PythonExe -m pip install -r $RequirementsFile
        if ($LASTEXITCODE -ne 0) {
            throw "$ServiceName failed to install requirements."
        }

        & $PythonExe -c "import $ModuleName"
        if ($LASTEXITCODE -ne 0) {
            throw "$ServiceName still cannot import $ModuleName after install."
        }
    }
    finally {
        Pop-Location
    }
}

function Test-LocalPort {
    param([int]$Port)

    $client = New-Object System.Net.Sockets.TcpClient
    try {
        $async = $client.BeginConnect("127.0.0.1", $Port, $null, $null)
        $connected = $async.AsyncWaitHandle.WaitOne(300)
        if (-not $connected) {
            return $false
        }
        $client.EndConnect($async) | Out-Null
        return $true
    }
    catch {
        return $false
    }
    finally {
        $client.Close()
    }
}

function Wait-LocalPort {
    param(
        [int]$Port,
        [int]$TimeoutSeconds = 60
    )

    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    while ((Get-Date) -lt $deadline) {
        if (Test-LocalPort -Port $Port) {
            return
        }
        Start-Sleep -Seconds 2
    }

    throw "Port $Port did not become ready within $TimeoutSeconds seconds."
}

function Wait-HttpOk {
    param(
        [string]$Url,
        [int]$TimeoutSeconds = 120
    )

    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    while ((Get-Date) -lt $deadline) {
        try {
            $response = Invoke-WebRequest -Uri $Url -UseBasicParsing -TimeoutSec 5
            if ($response.StatusCode -ge 200 -and $response.StatusCode -lt 500) {
                return
            }
        }
        catch {
        }
        Start-Sleep -Seconds 3
    }

    throw "URL $Url did not become ready within $TimeoutSeconds seconds."
}

function Invoke-External {
    param(
        [Parameter(Mandatory = $true)][string]$FilePath,
        [Parameter(Mandatory = $true)][string[]]$Arguments,
        [Parameter(Mandatory = $true)][string]$WorkingDirectory,
        [Parameter(Mandatory = $true)][string]$Name
    )

    Push-Location $WorkingDirectory
    try {
        & $FilePath @Arguments
        if ($LASTEXITCODE -ne 0) {
            throw "$Name failed with exit code $LASTEXITCODE"
        }
    }
    finally {
        Pop-Location
    }
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

function Get-PortOwner {
    param([int]$Port)

    $conn = Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $conn) {
        return $null
    }

    $process = Get-Process -Id $conn.OwningProcess -ErrorAction SilentlyContinue
    if (-not $process) {
        return "PID $($conn.OwningProcess)"
    }

    $path = ""
    try {
        $path = $process.Path
    }
    catch {
    }

    if ($path) {
        return "$($process.ProcessName) [PID=$($process.Id)] $path"
    }

    return "$($process.ProcessName) [PID=$($process.Id)]"
}

function Start-BackgroundService {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][string]$WorkingDirectory,
        [Parameter(Mandatory = $true)][string]$FilePath,
        [Parameter(Mandatory = $true)][string[]]$Arguments,
        [Parameter(Mandatory = $true)][int]$Port,
        [string]$HealthUrl,
        [int]$TimeoutSeconds = 180
    )

    $safeName = $Name.ToLowerInvariant().Replace(" ", "-")
    $pidFile = Join-Path $pidDir "$safeName.pid"
    $stdoutFile = Join-Path $logDir "$safeName.out.log"
    $stderrFile = Join-Path $logDir "$safeName.err.log"

    if (Test-Path $pidFile) {
        $existingId = (Get-Content $pidFile -ErrorAction SilentlyContinue | Select-Object -First 1).Trim()
        if ($existingId) {
            $existingProcess = Get-Process -Id $existingId -ErrorAction SilentlyContinue
            if ($existingProcess) {
                Write-Host "$Name already running with PID $existingId. Skip." -ForegroundColor Yellow
                return
            }
        }
        Remove-Item $pidFile -Force -ErrorAction SilentlyContinue
    }

    if (Test-LocalPort -Port $Port) {
        $owner = Get-PortOwner -Port $Port
        throw "$Name port $Port is already occupied by $owner"
    }

    $process = Start-Process `
        -FilePath $FilePath `
        -ArgumentList $Arguments `
        -WorkingDirectory $WorkingDirectory `
        -WindowStyle Hidden `
        -RedirectStandardOutput $stdoutFile `
        -RedirectStandardError $stderrFile `
        -PassThru

    Set-Content -Path $pidFile -Value $process.Id -Encoding ascii
    Write-Host "$Name started with PID $($process.Id)" -ForegroundColor Green

    if ($HealthUrl) {
        Wait-HttpOk -Url $HealthUrl -TimeoutSeconds $TimeoutSeconds
    }
    else {
        Wait-LocalPort -Port $Port -TimeoutSeconds $TimeoutSeconds
    }
}

function Ensure-DataAdminDatabase {
    Write-Step "Ensure offeratlas_data_admin database"
    $exists = & docker exec offeratlas-postgres psql -U offeratlas -d postgres -tAc "SELECT 1 FROM pg_database WHERE datname='offeratlas_data_admin'"
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to check offeratlas_data_admin database."
    }

    if (($exists | Out-String).Trim() -eq "1") {
        Write-Host "offeratlas_data_admin already exists." -ForegroundColor Green
        return
    }

    & docker exec offeratlas-postgres psql -U offeratlas -d postgres -c "CREATE DATABASE offeratlas_data_admin"
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to create offeratlas_data_admin database."
    }

    Write-Host "offeratlas_data_admin created." -ForegroundColor Green
}

Ensure-Command "docker"
Ensure-Command "mvn"
Ensure-Command "npm"

$pythonScholar = Join-Path $workspace "OfferAtlas ScholarGraph\.venv\Scripts\python.exe"
$pythonDataAdmin = Join-Path $workspace "offeratlas-data-admin-api\.venv\Scripts\python.exe"
$scholarRequirements = Join-Path $workspace "OfferAtlas ScholarGraph\requirements.txt"
$dataAdminRequirements = Join-Path $workspace "offeratlas-data-admin-api\requirements.txt"

Ensure-File -Path $pythonScholar -Label "ScholarGraph Python"
Ensure-File -Path $pythonDataAdmin -Label "DataAdmin API Python"
Ensure-File -Path $scholarRequirements -Label "ScholarGraph requirements"
Ensure-File -Path $dataAdminRequirements -Label "DataAdmin API requirements"
Ensure-File -Path $composeFile -Label "Core Docker Compose"

Ensure-PythonModule `
    -PythonExe $pythonScholar `
    -ModuleName "alembic" `
    -RequirementsFile $scholarRequirements `
    -WorkingDirectory (Join-Path $workspace "OfferAtlas ScholarGraph") `
    -ServiceName "ScholarGraph"

Ensure-PythonModule `
    -PythonExe $pythonDataAdmin `
    -ModuleName "alembic" `
    -RequirementsFile $dataAdminRequirements `
    -WorkingDirectory (Join-Path $workspace "offeratlas-data-admin-api") `
    -ServiceName "DataAdmin API"

Stop-ContainersByName -Names $legacyContainers -Label "Stop legacy ScholarGraph containers"

Write-Step "Start infra containers"
Invoke-External `
    -FilePath "docker" `
    -Arguments @("compose", "-f", $composeFile, "up", "-d", "postgres", "redis", "minio", "meilisearch") `
    -WorkingDirectory (Join-Path $workspace "offeratlas-core-api") `
    -Name "Docker Compose"

Wait-LocalPort -Port 15432 -TimeoutSeconds 120
Wait-LocalPort -Port 16379 -TimeoutSeconds 120
Wait-LocalPort -Port 17700 -TimeoutSeconds 120
Wait-LocalPort -Port 9100 -TimeoutSeconds 120

Ensure-DataAdminDatabase

Write-Step "Run ScholarGraph migration"
Invoke-External `
    -FilePath $pythonScholar `
    -Arguments @("-m", "alembic", "upgrade", "head") `
    -WorkingDirectory (Join-Path $workspace "OfferAtlas ScholarGraph") `
    -Name "ScholarGraph Alembic"

Start-BackgroundService `
    -Name "ScholarGraph" `
    -WorkingDirectory (Join-Path $workspace "OfferAtlas ScholarGraph") `
    -FilePath $pythonScholar `
    -Arguments @("-m", "uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000") `
    -Port 8000 `
    -HealthUrl "http://127.0.0.1:8000/health" `
    -TimeoutSeconds 180

Start-BackgroundService `
    -Name "Core API" `
    -WorkingDirectory (Join-Path $workspace "offeratlas-core-api") `
    -FilePath "mvn.cmd" `
    -Arguments @("spring-boot:run") `
    -Port 18080 `
    -HealthUrl "http://127.0.0.1:18080/actuator/health" `
    -TimeoutSeconds 240

Write-Step "Run DataAdmin API migration"
Invoke-External `
    -FilePath $pythonDataAdmin `
    -Arguments @("-m", "alembic", "upgrade", "head") `
    -WorkingDirectory (Join-Path $workspace "offeratlas-data-admin-api") `
    -Name "DataAdmin API Alembic"

Start-BackgroundService `
    -Name "DataAdmin API" `
    -WorkingDirectory (Join-Path $workspace "offeratlas-data-admin-api") `
    -FilePath $pythonDataAdmin `
    -Arguments @("-m", "uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8010") `
    -Port 8010 `
    -HealthUrl "http://127.0.0.1:8010/health" `
    -TimeoutSeconds 180

Start-BackgroundService `
    -Name "OfferAtlas Pro" `
    -WorkingDirectory (Join-Path $workspace "OfferAtlas Pro") `
    -FilePath "npm.cmd" `
    -Arguments @("run", "dev", "--", "--host", "0.0.0.0", "--port", "5173") `
    -Port 5173 `
    -TimeoutSeconds 120

Start-BackgroundService `
    -Name "OfferAtlas Student" `
    -WorkingDirectory (Join-Path $workspace "OfferAtlas Student") `
    -FilePath "npm.cmd" `
    -Arguments @("run", "dev", "--", "--host", "0.0.0.0", "--port", "5174") `
    -Port 5174 `
    -TimeoutSeconds 120

Start-BackgroundService `
    -Name "OfferAtlas DataAdmin" `
    -WorkingDirectory (Join-Path $workspace "OfferAtlas DataAdmin") `
    -FilePath "npm.cmd" `
    -Arguments @("run", "dev", "--", "--host", "0.0.0.0", "--port", "6173") `
    -Port 6173 `
    -TimeoutSeconds 120

Write-Step "All services started"
Write-Host "OfferAtlas Pro:      http://127.0.0.1:5173" -ForegroundColor Green
Write-Host "OfferAtlas Student:  http://127.0.0.1:5174" -ForegroundColor Green
Write-Host "OfferAtlas DataAdmin:http://127.0.0.1:6173" -ForegroundColor Green
Write-Host "Core API:            http://127.0.0.1:18080" -ForegroundColor Green
Write-Host "ScholarGraph:        http://127.0.0.1:8000/docs" -ForegroundColor Green
Write-Host "DataAdmin API:       http://127.0.0.1:8010/health" -ForegroundColor Green
Write-Host "MinIO Console:       http://127.0.0.1:9101" -ForegroundColor Green
Write-Host ""
Write-Host "Logs: $logDir" -ForegroundColor Yellow
Write-Host "Crawler is a batch CLI and is not started as a long-running service." -ForegroundColor Yellow
