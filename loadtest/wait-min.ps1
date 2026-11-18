param(
    [ValidateRange(1, 60)][int]$TimeoutMinutes = 25
)

$ErrorActionPreference = 'Stop'
$infra = Join-Path (Split-Path $PSScriptRoot -Parent) 'infra'
function Get-Output([string]$Name) {
    $value = terraform "-chdir=$infra" output -raw $Name
    if ($LASTEXITCODE -ne 0 -or !$value) { throw "Cannot read Terraform output $Name" }
    return $value
}

$region = Get-Output 'aws_region'
$cluster = Get-Output 'ecs_cluster_name'
$service = Get-Output 'ecs_service_name'
$url = Get-Output 'app_url'
$deadline = (Get-Date).AddMinutes($TimeoutMinutes)

do {
    $result = aws ecs describe-services --region $region --cluster $cluster --services $service --query "services[0].[desiredCount,runningCount,pendingCount]" --output json --no-cli-pager
    if ($LASTEXITCODE -ne 0) { throw 'Cannot read ECS service state' }
    $counts = $result | ConvertFrom-Json
    if ($null -eq $counts -or $counts.Count -ne 3) { throw 'ECS service not found' }
    $desired, $running, $pending = $counts
    $time = (Get-Date).ToUniversalTime().ToString('o')
    Write-Output "$time desired=$desired running=$running pending=$pending"
    if ($desired -eq 1 -and $running -eq 1 -and $pending -eq 0) { return }
    Invoke-WebRequest -UseBasicParsing -Uri "$url/" -TimeoutSec 5 -ErrorAction SilentlyContinue | Out-Null
    Start-Sleep -Seconds 20
} while ((Get-Date) -lt $deadline)

throw 'ECS did not return to one task before the timeout'
