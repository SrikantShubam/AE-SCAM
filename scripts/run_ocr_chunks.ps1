param(
    [Parameter(Mandatory = $true)]
    [ValidateSet("rapidocr", "tesseract", "easyocr")]
    [string]$Engine,

    [Parameter(Mandatory = $true)]
    [ValidateSet("synthetic", "stress", "all")]
    [string]$SourceGroup,

    [int]$ChunkSize = 100
)

$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $PSScriptRoot
$evalManifest = Join-Path $root "data\benchmark\v0.1\metadata\ocr_eval_manifest.csv"
$reportDir = Join-Path $root "data\benchmark\v0.1\reports"
$dashboardScript = Join-Path $root "scripts\generate_benchmark_dashboard.py"

switch ($Engine) {
    "rapidocr" { $output = Join-Path $reportDir ("rapidocr_predictions_{0}_v0_1.csv" -f $SourceGroup) }
    "tesseract" { $output = Join-Path $reportDir ("tesseract_predictions_{0}_v0_1.csv" -f $SourceGroup) }
    "easyocr" { $output = Join-Path $reportDir ("easyocr_predictions_{0}_v0_1.csv" -f $SourceGroup) }
}

if (Test-Path $output) {
    Remove-Item $output
}

$rows = Import-Csv $evalManifest
if ($SourceGroup -ne "all") {
    $rows = $rows | Where-Object { $_.source_group -eq $SourceGroup }
}
$total = $rows.Count

for ($offset = 0; $offset -lt $total; $offset += $ChunkSize) {
    $limit = [Math]::Min($ChunkSize, $total - $offset)
    if ($Engine -eq "rapidocr") {
        python (Join-Path $root "scripts\run_rapidocr_batch.py") --source-group $SourceGroup --offset $offset --limit $limit --append --output $output
    }
    elseif ($Engine -eq "easyocr") {
        python (Join-Path $root "scripts\run_easyocr_batch.py") --source-group $SourceGroup --offset $offset --limit $limit --append --output $output
    }
    else {
        docker run --rm -v C:/experiments/ai-elderly-scam:/workspace elderly-scam-tesseract --source-group $SourceGroup --offset $offset --limit $limit --append --output ("data/benchmark/v0.1/reports/" + [System.IO.Path]::GetFileName($output))
    }
    python $dashboardScript
}

Write-Host "Completed $Engine for $SourceGroup in chunks of $ChunkSize"
