param(
    [int]$Seconds = 30,
    [string]$UserDir = "H:\Projects\Agressive Inline Static Recompile\work\perf_user",
    [string]$Module = "H:\Projects\Agressive Inline Static Recompile\build\gGILE51_recomp_clang.dll",
    [string]$State = "H:\Projects\Agressive Inline Static Recompile\work\saves\tutorial-start.state",
    [switch]$Affinity,
    [switch]$NoMove
)
$ErrorActionPreference = "Stop"
$root = "H:\Projects\Agressive Inline Static Recompile"
$auto = Join-Path $root "work\automation"
$game = Join-Path $root "work\game"
New-Item -ItemType Directory -Force -Path $UserDir, "$UserDir\Config", "$UserDir\Cache\Shaders", "$UserDir\logs", "$auto\commands", "$auto\processed", "$auto\failed" | Out-Null
Get-ChildItem "$auto\commands","$auto\processed","$auto\failed" -File -ErrorAction SilentlyContinue | Remove-Item -Force
$runStamp = Get-Date -Format "yyyyMMdd-HHmmss"
$outLog = Join-Path $UserDir "logs\perf-$runStamp.stdout.log"
$errLog = Join-Path $UserDir "logs\perf-$runStamp.stderr.log"

Get-Process | Where-Object { $_.ProcessName -in @('gile','moderngekko-run') } | ForEach-Object { Stop-Process -Id $_.Id -Force }
Start-Sleep -Milliseconds 500
if ($Affinity) { $env:MODERNGEKKO_CACHE_AFFINITY = "1" } else { Remove-Item Env:MODERNGEKKO_CACHE_AFFINITY -ErrorAction SilentlyContinue }

$argLine = "--game `"$game`" --module `"$Module`" --user-dir `"$UserDir`" --audio cubeb --automation-dir `"$auto`""
$p = Start-Process -FilePath "H:\Projects\SB-RFD\build\moderngekko\moderngekko-run.exe" `
    -ArgumentList $argLine -RedirectStandardOutput $outLog -RedirectStandardError $errLog -NoNewWindow -PassThru

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

$bootDeadline = (Get-Date).AddSeconds(90)
while ((Get-Date) -lt $bootDeadline) {
    $s = Read-Status
    if ($s -and $s.booted -eq '1') { break }
    Start-Sleep -Milliseconds 250
}
$booted = (Read-Status).booted
if ($booted -ne '1') { Write-Output "boot failed"; Get-Process -Id $p.Id -ErrorAction SilentlyContinue | Stop-Process -Force; exit 1 }

# Load the tutorial state, then dismiss the two tutorial pages.
Set-Content -Path "$auto\commands\001-load.txt" -Value "command=load_state`npath=$State"
Start-Sleep -Seconds 4
Set-Content -Path "$auto\commands\002-a.txt" -Value "command=pad_frames`nport=0`nframes=6`na=1"
Start-Sleep -Seconds 2
Set-Content -Path "$auto\commands\003-a.txt" -Value "command=pad_frames`nport=0`nframes=6`na=1"
Start-Sleep -Seconds 2
if (-not $NoMove) {
    Set-Content -Path "$auto\commands\004-move.txt" -Value "command=pad`nport=0`nmain_y=1"
}
Start-Sleep -Seconds 2

$samples = New-Object System.Collections.Generic.List[object]
$sw = [Diagnostics.Stopwatch]::StartNew()
$proc = Get-Process -Id $p.Id -ErrorAction SilentlyContinue
$memStart = if ($proc) { $proc.WorkingSet64 } else { 0 }
$cpuStart = if ($proc) { $proc.TotalProcessorTime.TotalSeconds } else { 0 }
while ($sw.Elapsed.TotalSeconds -lt $Seconds) {
    $s = Read-Status
    $proc = Get-Process -Id $p.Id -ErrorAction SilentlyContinue
    $titleFps = $null
    if ($proc -and $proc.MainWindowTitle -match '\|\s*([0-9.]+)\s*FPS') { $titleFps = [double]$Matches[1] }
    if ($s) {
        $samples.Add([pscustomobject]@{
            t = [math]::Round($sw.Elapsed.TotalSeconds, 2)
            fps = [double]$s.fps
            vps = [double]$s.vps
            speed = [double]$s.speed
            frame = [long]$s.frame_count
            present = [long]$s.present_count
            titleFps = $titleFps
            memMB = if ($proc) { [math]::Round($proc.WorkingSet64 / 1MB, 1) } else { 0 }
        })
    }
    Start-Sleep -Milliseconds 250
}
$memEnd = if ($proc) { $proc.WorkingSet64 } else { 0 }
$cpuEnd = if ($proc) { $proc.TotalProcessorTime.TotalSeconds } else { 0 }
Set-Content -Path "$auto\commands\999-clear.txt" -Value "command=clear_pad`nport=0"
Start-Sleep -Milliseconds 500
Get-Process -Id $p.Id -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep -Milliseconds 500

$fpsValues = $samples | Where-Object { $_.fps -gt 0 } | ForEach-Object { $_.fps }
$speedValues = $samples | Where-Object { $_.speed -gt 0 } | ForEach-Object { $_.speed }
$titleValues = $samples | Where-Object { $null -ne $_.titleFps } | ForEach-Object { $_.titleFps }
$presentFps = New-Object System.Collections.Generic.List[double]
$frameFps = New-Object System.Collections.Generic.List[double]
for ($i = 1; $i -lt $samples.Count; $i++) {
    $dt = $samples[$i].t - $samples[$i-1].t
    if ($dt -gt 0.1) {
        $presentFps.Add((($samples[$i].present - $samples[$i-1].present) / $dt))
        $frameFps.Add((($samples[$i].frame - $samples[$i-1].frame) / $dt))
    }
}
function Stats($values) {
    if (-not $values) { return "n/a" }
    $sorted = @($values | Sort-Object)
    $avg = ($sorted | Measure-Object -Average).Average
    $min = $sorted[0]
    $p5 = $sorted[[math]::Min($sorted.Count - 1, [int]($sorted.Count * 0.05))]
    $p1 = $sorted[[math]::Min($sorted.Count - 1, [int]($sorted.Count * 0.01))]
    return ("avg={0:N2} min={1:N2} p5={2:N2} p1={3:N2}" -f $avg, $min, $p5, $p1)
}
$csv = Join-Path $UserDir "logs\perf-$runStamp.csv"
$samples | Export-Csv -Path $csv -NoTypeInformation
Write-Output "=== run $runStamp affinity=$Affinity seconds=$Seconds ==="
Write-Output "samples: $csv"
Write-Output "=== worst status FPS samples ==="
$samples | Sort-Object fps | Select-Object -First 12 | Format-Table t,fps,titleFps,speed,memMB -AutoSize | Out-String | Write-Output
Write-Output "=== first 8 samples ==="
$samples | Select-Object -First 8 | Format-Table t,fps,titleFps,speed,memMB -AutoSize | Out-String | Write-Output
Write-Output ("Status FPS samples: {0}; {1}" -f $fpsValues.Count, (Stats $fpsValues))
Write-Output ("Title FPS samples: {0}; {1}" -f $titleValues.Count, (Stats $titleValues))
Write-Output ("Present FPS samples: {0}; {1}" -f $presentFps.Count, (Stats $presentFps))
Write-Output ("Frame FPS samples: {0}; {1}" -f $frameFps.Count, (Stats $frameFps))
Write-Output ("Speed samples: {0}; {1}" -f $speedValues.Count, (Stats $speedValues))
if ($presentFps) {
    $below58 = @($presentFps | Where-Object { $_ -lt 58 }).Count
    $below55 = @($presentFps | Where-Object { $_ -lt 55 }).Count
    $below50 = @($presentFps | Where-Object { $_ -lt 50 }).Count
    Write-Output ("Present FPS below 58={0} below 55={1} below 50={2}" -f $below58, $below55, $below50)
}
$worst = $presentFps | Sort-Object | Select-Object -First 10
Write-Output ("Worst present samples: " + (($worst | ForEach-Object { "{0:N1}" -f $_ }) -join ", "))
Write-Output ("Memory: start={0:N1} MB end={1:N1} MB delta={2:N1} MB" -f ($memStart/1MB), ($memEnd/1MB), (($memEnd-$memStart)/1MB))
Write-Output ("CPU time: {0:N1} s over {1:N1} s wall" -f ($cpuEnd-$cpuStart), $sw.Elapsed.TotalSeconds)
$shaderDir = Join-Path $UserDir "Cache\Shaders"
$shaderFiles = Get-ChildItem $shaderDir -Recurse -File -ErrorAction SilentlyContinue
Write-Output ("Shader cache: {0} files, {1:N1} MB" -f $shaderFiles.Count, (($shaderFiles | Measure-Object Length -Sum).Sum / 1MB))
Write-Output "=== stderr tail ==="
Get-Content $errLog -Tail 8 -ErrorAction SilentlyContinue
Write-Output "=== perf log lines ==="
Get-Content $outLog -ErrorAction SilentlyContinue | Select-String -Pattern "\[perf\]|Audio|shader|cache" | Select-Object -Last 10
