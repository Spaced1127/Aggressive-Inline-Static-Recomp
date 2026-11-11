param(
    [string]$ProcessName = "gile",
    [int]$Seconds = 1800,
    [string]$OutDir = "C:\Users\Gamer\AppData\Local\AggressiveInlineRecomp\logs\session"
)
$ErrorActionPreference = "Stop"
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$csv = Join-Path $OutDir "process-$stamp.csv"
@("timestamp,working_set_mb,private_mb,cpu_seconds,threads,handles") | Set-Content $csv
$sw = [Diagnostics.Stopwatch]::StartNew()
$missing = 0
while ($sw.Elapsed.TotalSeconds -lt $Seconds) {
    $p = Get-Process -Name $ProcessName -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($p) {
        $missing = 0
        $row = "{0},{1:N1},{2:N1},{3:N3},{4},{5}" -f (Get-Date).ToString('o'),
            ($p.WorkingSet64 / 1MB), ($p.PrivateMemorySize64 / 1MB),
            $p.TotalProcessorTime.TotalSeconds, $p.Threads.Count, $p.HandleCount
        Add-Content -Path $csv -Value $row
    } else {
        $missing++
        if ($missing -ge 6) { break }
    }
    Start-Sleep -Seconds 5
}
Write-Output "process sample: $csv"
