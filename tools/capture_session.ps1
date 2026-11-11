param(
    [int]$Seconds = 600,
    [string]$ProcessName = "gile",
    [string]$OutDir = "C:\Users\Gamer\AppData\Local\AggressiveInlineRecomp\logs\session"
)
$ErrorActionPreference = "Stop"
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$csv = Join-Path $OutDir "pm-$stamp.csv"
$procCsv = Join-Path $OutDir "process-$stamp.csv"
$meta = Join-Path $OutDir "meta-$stamp.txt"
$pmExe = "C:\Program Files\ROTK Launcher\resources\diagnostics\PresentMon.exe"

@(
    "start=$((Get-Date).ToString('o'))",
    "seconds=$Seconds",
    "process=$ProcessName",
    "csv=$csv"
) | Set-Content $meta

# Sample process memory/CPU until the game exits or PresentMon stops.
$pmArgs = "--process_name $ProcessName.exe --timed $Seconds --output_file `"$csv`" --no_console_stats"
$pm = Start-Process -FilePath $pmExe -ArgumentList $pmArgs -PassThru -WindowStyle Hidden
@("timestamp,working_set_mb,private_mb,cpu_seconds,threads,handles") | Set-Content $procCsv
$missing = 0
while (-not $pm.HasExited) {
    $p = Get-Process -Name $ProcessName -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($p) {
        $missing = 0
        $row = "{0},{1:N1},{2:N1},{3:N3},{4},{5}" -f (Get-Date).ToString('o'),
            ($p.WorkingSet64 / 1MB), ($p.PrivateMemorySize64 / 1MB),
            $p.TotalProcessorTime.TotalSeconds, $p.Threads.Count, $p.HandleCount
        Add-Content -Path $procCsv -Value $row
    } else {
        $missing++
        if ($missing -ge 6) { Stop-Process -Id $pm.Id -Force -ErrorAction SilentlyContinue; break }
    }
    Start-Sleep -Seconds 5
}
$p = Get-Process -Name $ProcessName -ErrorAction SilentlyContinue | Select-Object -First 1
if ($p) {
    $row = "{0},{1:N1},{2:N1},{3:N3},{4},{5}" -f (Get-Date).ToString('o'),
        ($p.WorkingSet64 / 1MB), ($p.PrivateMemorySize64 / 1MB),
        $p.TotalProcessorTime.TotalSeconds, $p.Threads.Count, $p.HandleCount
    Add-Content -Path $procCsv -Value $row
}
@(
    "end=$((Get-Date).ToString('o'))",
    "presentmon_exit=$($pm.ExitCode)",
    "csv=$csv",
    "process_csv=$procCsv"
) | Add-Content $meta
Write-Output "capture done: $csv"
Write-Output "process: $procCsv"
Get-Item $csv -ErrorAction SilentlyContinue | Select-Object Name,Length
