param(
    [string]$Url = 'http://127.0.0.1:8000',
    [ValidateRange(1, 100)][int]$Vus = 8,
    [ValidateSet('off', 'on')][string]$Cache = 'off',
    [switch]$Smoke,
    [switch]$Probe
)

$ErrorActionPreference = 'Stop'
if ($Smoke -and $Probe) { throw 'Choose either -Smoke or -Probe' }
$results = Join-Path $PSScriptRoot 'results'
New-Item -ItemType Directory -Path $results -Force | Out-Null
$stamp = (Get-Date).ToUniversalTime().ToString('yyyyMMdd-HHmmss')
$label = if ($Smoke) { 'smoke' } elseif ($Probe) { 'probe' } else { 'load' }
$report = Join-Path $results "$stamp-$label-$Cache.json"
$log = Join-Path $results "$stamp-$label-$Cache.log"
$script = Join-Path $PSScriptRoot 'library.js'

k6 run --quiet --no-color --log-output=stdout -e "BASE_URL=$Url" -e "VUS=$Vus" -e "EXPECT_CACHE=$Cache" -e "PROFILE=$label" -e "SUMMARY_PATH=$report" $script |
    Tee-Object -FilePath $log

if ($LASTEXITCODE -ne 0) {
    throw "k6 exited with code $LASTEXITCODE. See $log"
}
Write-Output "Summary: $report"
Write-Output "Timeline: $log"
