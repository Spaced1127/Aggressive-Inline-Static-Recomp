param(
    [string]$UserDir = "H:\Projects\Agressive Inline Static Recompile\work\perf_stutter\warm_user",
    [string]$State = "H:\Projects\Agressive Inline Static Recompile\work\memtest\levelselect.state",
    [int]$WarmSeconds = 6,
    [int]$CaptureSeconds = 25,
    [string]$Tag = "levelstart-warm",
    [switch]$StartLevel,
    [string]$Core = "static",
    [int]$RightPresses = 0
)
$ErrorActionPreference = "Stop"
$root = "H:\Projects\Agressive Inline Static Recompile"
$auto = Join-Path $root "work\perf_stutter\automation"
$game = Join-Path $root "work\game"
$outDir = Join-Path $root "work\perf_stutter\captures"
New-Item -ItemType Directory -Force -Path $UserDir, "$UserDir\Config", "$UserDir\Cache\Shaders", "$UserDir\logs", "$auto\commands", "$auto\processed", "$auto\failed", $outDir | Out-Null
Get-ChildItem "$auto\commands","$auto\processed","$auto\failed" -File -ErrorAction SilentlyContinue | Remove-Item -Force
Remove-Item (Join-Path $auto "status.txt") -Force -ErrorAction SilentlyContinue

Get-Process | Where-Object { $_.ProcessName -in @('gile','moderngekko-run','PresentMon') } | ForEach-Object { Stop-Process -Id $_.Id -Force }
Start-Sleep -Milliseconds 700

$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$outLog = Join-Path $UserDir "logs\$Tag-$stamp.stdout.log"
$errLog = Join-Path $UserDir "logs\$Tag-$stamp.stderr.log"
if ($Core -eq "jit") {
    $cfg = Join-Path $UserDir "config.ini"
    $text = Get-Content $cfg -Raw
    if ($text -notmatch '(?m)^cpu_core=') {
        if ($text -match '(?m)^\[Core\]') { $text = $text -replace '(?m)^\[Core\]', "[Core]`r`ncpu_core=jit" }
        else { $text = "[Core]`r`ncpu_core=jit`r`n" + $text }
        Set-Content $cfg $text -NoNewline
    }
    $argLine = "--game `"$game`" --user-dir `"$UserDir`" --audio cubeb --automation-dir `"$auto`" --load-state `"$State`" --allow-interpreter"
} else {
    $argLine = "--game `"$game`" --module `"$root\build\gGILE51_recomp_clang.dll`" --user-dir `"$UserDir`" --audio cubeb --automation-dir `"$auto`" --load-state `"$State`""
}
if ($Core -eq "jit") { $env:MODERNGEKKO_STATICRECOMP = "0" } else { $env:MODERNGEKKO_STATICRECOMP = "1" }
$p = Start-Process -FilePath "H:\Projects\SB-RFD\build\moderngekko\moderngekko-run.exe" `
    -ArgumentList $argLine -RedirectStandardOutput $outLog -RedirectStandardError $errLog -PassThru

function Read-Status {
    $path = Join-Path $auto "status.txt"
    if (-not (Test-Path $path)) { return $null }
    $h = @{}
    foreach ($line in Get-Content $path -ErrorAction SilentlyContinue) {
        $eq = $line.IndexOf('=')
        if ($eq -gt 0) { $h[$line.Substring(0, $eq)] = $line.Substring($eq + 1) }
    }
    return $h
}
function Send-Command([string]$name, [string]$body) {
    $path = Join-Path $auto "commands\$name.txt"
    Set-Content -Path $path -Value $body -NoNewline
    $deadline = (Get-Date).AddSeconds(30)
    while ((Get-Date) -lt $deadline) {
        if (Test-Path (Join-Path $auto "processed\$name.txt")) { return $true }
        if (Test-Path (Join-Path $auto "failed\$name.txt")) { return $false }
        Start-Sleep -Milliseconds 100
    }
    return $false
}

$deadline = (Get-Date).AddSeconds(180)
while ((Get-Date) -lt $deadline) {
    $s = Read-Status
    if ($s -and $s.booted -eq '1' -and [double]$s.present_count -gt 300 -and [double]$s.fps -gt 55) { break }
    Start-Sleep -Milliseconds 250
}
$s = Read-Status
if (-not $s -or $s.booted -ne '1') {
    Write-Output "boot failed"
    Get-Content $errLog -Tail 30 -ErrorAction SilentlyContinue
    Get-Process -Id $p.Id -ErrorAction SilentlyContinue | Stop-Process -Force
    exit 1
}
Start-Sleep -Seconds $WarmSeconds
Write-Output "pre-capture status:"
Get-Content (Join-Path $auto "status.txt") | Select-String -Pattern 'fps=|speed=|present_count=|frame_count='

$shotRel = "../captures/$Tag-$stamp-before.png"
Send-Command "shot-before" "command=screenshot`npath=$shotRel" | Out-Null

$pmCsv = Join-Path $outDir "$Tag-$stamp.csv"
$pmSession = "GilePerf-$stamp"
$pmArgLine = "--process_id $($p.Id) --output_file `"$pmCsv`" --no_console_stats " +
             "--session_name $pmSession --timed $($CaptureSeconds + 6) --terminate_after_timed"
$pmLog = Join-Path $outDir "$Tag-$stamp.presentmon.log"
$pm = Start-Process -FilePath "H:\Projects\RPBB-GCN-Recomp\work\PresentMon.exe" -ArgumentList $pmArgLine -PassThru -RedirectStandardOutput $pmLog -RedirectStandardError "$pmLog.err"
Start-Sleep -Seconds 2
if ($pm.HasExited) {
    Write-Output "PresentMon exited early:"
    Get-Content $pmLog -Tail 10 -ErrorAction SilentlyContinue
    Get-Content "$pmLog.err" -Tail 10 -ErrorAction SilentlyContinue
}

if ($StartLevel) {
    for ($i = 1; $i -le $RightPresses; $i++) {
        Send-Command "right-$i" "command=pad_frames`nport=0`nframes=20`nmain_x=1" | Out-Null
        Start-Sleep -Milliseconds 1200
    }
    Send-Command "start-level" "command=pad_frames`nport=0`nframes=20`na=1" | Out-Null
    Write-Output "sent level start at $(Get-Date -Format HH:mm:ss.fff)"
}

Start-Sleep -Seconds $CaptureSeconds
$shotRel2 = "../captures/$Tag-$stamp-after.png"
Send-Command "shot-after" "command=screenshot`npath=$shotRel2" | Out-Null
Start-Sleep -Milliseconds 800
Write-Output "post-capture status:"
Get-Content (Join-Path $auto "status.txt") | Select-String -Pattern 'fps=|speed=|present_count=|frame_count='

# PresentMon writes the CSV when it exits; do not kill it mid-capture.
$pmDeadline = (Get-Date).AddSeconds(25)
while (-not $pm.HasExited -and (Get-Date) -lt $pmDeadline) { Start-Sleep -Milliseconds 250 }
if (-not $pm.HasExited) {
    Write-Output "PresentMon still running; stopping session"
    Get-Process -Id $pm.Id -ErrorAction SilentlyContinue | Stop-Process -Force
    Start-Sleep -Milliseconds 500
    & logman stop $pmSession -ets 2>&1 | Out-Null
}
Send-Command "stop-final" "command=stop" | Out-Null
$exitDeadline = (Get-Date).AddSeconds(10)
while (-not $p.HasExited -and (Get-Date) -lt $exitDeadline) { Start-Sleep -Milliseconds 250 }
if (-not $p.HasExited) { Get-Process -Id $p.Id -ErrorAction SilentlyContinue | Stop-Process -Force }
Start-Sleep -Milliseconds 700

Write-Output "PM_CSV=$pmCsv"
if (Test-Path $pmCsv) {
    $rows = Import-Csv $pmCsv
    Write-Output ("frames={0}" -f $rows.Count)
}
Write-Output "ERR_TAIL:"
Get-Content $errLog -Tail 12 -ErrorAction SilentlyContinue