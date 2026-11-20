param(
    [Parameter(Mandatory)][string]$RunLog,
    [int]$ClockOffsetSeconds = 0
)

$ErrorActionPreference = 'Stop'
$path = (Resolve-Path -LiteralPath $RunLog).Path
$log = Get-Content -LiteralPath $path -Raw
if ($ClockOffsetSeconds -ne 0 -and $log -match 'CLOCK_OFFSET_SECONDS=') {
    throw 'This log already uses clock-aligned timestamps'
}
function Get-RunTime([string]$Name) {
    $match = [regex]::Match($log, "$Name=(\d{4}-\d{2}-\d{2}T[\d:.]+Z)")
    if (!$match.Success) { throw "Missing $Name in $path. Choose the log from a completed full run." }
    return [DateTimeOffset]::Parse($match.Groups[1].Value).AddSeconds($ClockOffsetSeconds)
}

$minute = [TimeSpan]::TicksPerMinute
$start = Get-RunTime 'START_UTC'
$end = Get-RunTime 'LOAD_END_UTC'
$first = $start.AddTicks(($minute - ($start.Ticks % $minute)) % $minute)
$last = $end.AddTicks(-($end.Ticks % $minute))
$count = [int](($last - $first).TotalMinutes)
if ($count -lt 1) { throw 'No complete minute in the workload window' }

$infra = Join-Path (Split-Path $PSScriptRoot -Parent) 'infra'
$region = terraform "-chdir=$infra" output -raw aws_region
if ($LASTEXITCODE -ne 0 -or !$region) { throw 'Cannot read AWS region' }
$db = terraform "-chdir=$infra" output -raw rds_identifier
if ($LASTEXITCODE -ne 0 -or !$db) { throw 'Cannot read RDS identifier' }
$output = [ordered]@{
    rds = $db
    source = 'AWS/RDS'
    start_inclusive_utc = $first.UtcDateTime.ToString('s') + 'Z'
    end_exclusive_utc = $last.UtcDateTime.ToString('s') + 'Z'
    expected_minutes = $count
    metrics = [ordered]@{}
}

foreach ($metric in @('CPUUtilization', 'ReadIOPS')) {
    $json = aws cloudwatch get-metric-statistics --region $region --namespace 'AWS/RDS' `
        --metric-name $metric --dimensions "Name=DBInstanceIdentifier,Value=$db" `
        --start-time $output.start_inclusive_utc --end-time $output.end_exclusive_utc `
        --period 60 --statistics Average --output json --no-cli-pager
    if ($LASTEXITCODE -ne 0) { throw "Cannot read RDS metric $metric" }
    $points = @(($json | ConvertFrom-Json).Datapoints | Sort-Object Timestamp)
    if ($points.Count -ne $count) {
        throw "$metric has $($points.Count) of $count data points. Wait for CloudWatch and retry."
    }
    $stats = $points | Measure-Object -Property Average -Average -Maximum
    $output.metrics[$metric] = [ordered]@{
        mean = [math]::Round($stats.Average, 3)
        peak_one_minute_average = [math]::Round($stats.Maximum, 3)
        points = $points
    }
}

$report = [IO.Path]::ChangeExtension($path, 'rds.json')
$output | ConvertTo-Json -Depth 7 | Tee-Object -FilePath $report
Write-Output "Saved $report"
