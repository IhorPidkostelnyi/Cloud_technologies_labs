param(
    [string]$Url = 'http://127.0.0.1:8000',
    [string]$SecondUrl = $Url,
    [switch]$LocalSql
)

$ErrorActionPreference = 'Stop'
$first = $Url.TrimEnd('/')
$second = $SecondUrl.TrimEnd('/')
$key = [guid]::NewGuid().ToString('N')
$authorBody = @{ name = "Idempotency $key" } | ConvertTo-Json
$author = Invoke-RestMethod "$first/authors" -Method Post -ContentType 'application/json' -Body $authorBody
$body = @{ title = "Replay $key"; author_id = $author.id; year = 2026 } | ConvertTo-Json
$headers = @{ 'Idempotency-Key' = $key }
$a = Invoke-WebRequest "$first/books" -UseBasicParsing -Method Post -ContentType 'application/json' -Body $body -Headers $headers
$b = Invoke-WebRequest "$second/books" -UseBasicParsing -Method Post -ContentType 'application/json' -Body $body -Headers $headers
$id = ($a.Content | ConvertFrom-Json).id
if ($a.StatusCode -ne 201 -or $b.StatusCode -ne 201 -or $a.Content -cne $b.Content) {
    throw 'Expected two identical HTTP 201 responses'
}
$page = Invoke-RestMethod "$second/books?author_id=$($author.id)&limit=10"
$books = @($page)
if ($books.Count -ne 1 -or $books[0].id -ne $id) {
    throw "Expected exactly one book for author $($author.id)"
}

Write-Output "POST 1: HTTP $($a.StatusCode)  $($a.Content)"
Write-Output "POST 2: HTTP $($b.StatusCode)  $($b.Content)"
Write-Output "GET books for author $($author.id): $($books.Count) row, book id=$id"
if ($LocalSql) {
    $authorId = [int]$author.id
    $rows = docker compose exec -T db psql -U library -d library -At -c "SELECT count(*) FROM books WHERE author_id = $authorId"
    if ($LASTEXITCODE -ne 0 -or [string]$rows -ne '1') { throw 'PostgreSQL did not report exactly one row' }
    $ttl = docker compose exec -T redis redis-cli TTL "library:book-request:$key"
    if ($LASTEXITCODE -ne 0 -or [int]$ttl -lt 86300 -or [int]$ttl -gt 86400) { throw 'Unexpected Redis replay TTL' }
    Write-Output "PostgreSQL COUNT(*): $rows"
    Write-Output "Redis TTL: $ttl seconds"
}
Write-Output 'PASS: two equal responses; one stored book'
