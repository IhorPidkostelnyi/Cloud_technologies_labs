param(
    [Parameter(Mandatory)][string]$Url,
    [ValidateRange(1, 60)][int]$Minutes = 15
)

$deadline = [DateTimeOffset]::UtcNow.AddMinutes($Minutes)
$url = $Url.TrimEnd('/')
$healthy = 0
$failed = 0

do {
    try {
        $response = Invoke-WebRequest "$url/health" -UseBasicParsing -TimeoutSec 5 -ErrorAction Stop
        $status = $response.StatusCode
        $healthy++
    } catch {
        $status = 'FAILED'
        $failed++
    }
    Write-Output "$([DateTimeOffset]::UtcNow.ToString('o')) /health $status"
    Start-Sleep -Seconds 2
} while ([DateTimeOffset]::UtcNow -lt $deadline)

Write-Output "Health checks: HTTP 200=$healthy failures=$failed"
if ($failed -gt 0) { throw 'At least one health check failed' }
