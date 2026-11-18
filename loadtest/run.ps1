param(
    [string]$Url = 'http://127.0.0.1:8000',
    [ValidateRange(1, 100)][int]$Vus = 8,
    [ValidateSet('off', 'on')][string]$Cache = 'off',
    [switch]$Smoke
)

$ErrorActionPreference = 'Stop'
$results = Join-Path $PSScriptRoot 'results'
New-Item -ItemType Directory -Path $results -Force | Out-Null
$stamp = (Get-Date).ToUniversalTime().ToString('yyyyMMdd-HHmmss')
$label = if ($Smoke) { 'smoke' } else { 'load' }
$smokeFlag = [int]$Smoke.IsPresent
$report = Join-Path $results "$stamp-$label-$Cache.json"
$log = Join-Path $results "$stamp-$label-$Cache.log"
$script = Join-Path $PSScriptRoot 'library.js'

k6 run --quiet --log-output=stdout -e "BASE_URL=$Url" -e "VUS=$Vus" -e "EXPECT_CACHE=$Cache" -e "SMOKE=$smokeFlag" -e "SUMMARY_PATH=$report" $script |
    Tee-Object -FilePath $log

if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
}
