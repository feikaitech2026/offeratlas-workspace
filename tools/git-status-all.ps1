$ErrorActionPreference = "Stop"

$workspace = Split-Path -Parent $PSScriptRoot
$repos = @(
    "OfferAtlas Crawler",
    "OfferAtlas DataAdmin",
    "OfferAtlas Docs",
    "OfferAtlas Pro",
    "OfferAtlas ScholarGraph",
    "OfferAtlas Student",
    "offeratlas-core-api",
    "offeratlas-data-admin-api"
)

foreach ($repo in $repos) {
    $path = Join-Path $workspace $repo
    Write-Host ""
    Write-Host "== $repo ==" -ForegroundColor Cyan

    if (-not (Test-Path (Join-Path $path ".git"))) {
        Write-Host "不是 Git 仓库：$path" -ForegroundColor Yellow
        continue
    }

    git -C $path status --short --branch
}
