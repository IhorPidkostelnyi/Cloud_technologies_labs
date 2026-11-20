param(
    [string]$Url = 'http://127.0.0.1:8000',
    [string]$SecondUrl = 'http://127.0.0.1:8001'
)

$ErrorActionPreference = 'Stop'
$first = $Url.TrimEnd('/')
$second = $SecondUrl.TrimEnd('/')
$author = Invoke-RestMethod "$first/authors" -Method Post -ContentType 'application/json' `
    -Body (@{ name = "Cache check $([guid]::NewGuid())" } | ConvertTo-Json)
$query = "/books?author_id=$($author.id)&limit=10"

function Get-Page([string]$Base, [string]$Expected) {
    $result = Invoke-WebRequest "$Base$query" -UseBasicParsing
    $actual = [string]($result.Headers['X-Books-Cache'] | Select-Object -First 1)
    if ($actual -ne $Expected) { throw "Expected $Expected from $Base, got $actual" }
    Write-Host "$Base GET /books X-Books-Cache=$actual $($result.Content)"
    return $result.Content | ConvertFrom-Json
}

$null = Get-Page $first 'MISS'
$null = Get-Page $second 'HIT'
$created = Invoke-RestMethod "$first/books" -Method Post -ContentType 'application/json' `
    -Body (@{ title = 'Shared Redis check'; author_id = $author.id } | ConvertTo-Json)
Write-Output "$first POST /books id=$($created.id)"
$books = @(Get-Page $second 'MISS')
if ($books.Count -ne 1 -or $books[0].id -ne $created.id) {
    throw 'Other instance did not read the newly created record'
}
$null = Get-Page $first 'HIT'
Write-Output 'PASS: two instances use the same cache and see the same invalidation'
