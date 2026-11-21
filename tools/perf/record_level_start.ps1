param(
    [string]$UserDir = "H:\Projects\Agressive Inline Static Recompile\work\perf_stutter\visual_user",
    [string]$State = "H:\Projects\Agressive Inline Static Recompile\work\memtest\levelselect.state",
    [int]$Seconds = 14,
    [string]$Tag = "visual",
    [int]$RightPresses = 0
)
$ErrorActionPreference = "Stop"
$root = "H:\Projects\Agressive Inline Static Recompile"
$auto = Join-Path $root "work\perf_stutter\automation"
$game = Join-Path $root "work\game"
$outDir = Join-Path $root "work\perf_stutter\captures"
New-Item -ItemType Directory -Force -Path "$auto\commands", "$auto\processed", "$auto\failed", $outDir | Out-Null
Get-ChildItem "$auto\commands","$auto\processed","$auto\failed" -File -ErrorAction SilentlyContinue | Remove-Item -Force
Remove-Item (Join-Path $auto "status.txt") -Force -ErrorAction SilentlyContinue
Get-Process | Where-Object { $_.ProcessName -in @('gile','moderngekko-run','PresentMon','ffmpeg') } | ForEach-Object { Stop-Process -Id $_.Id -Force }
Start-Sleep -Milliseconds 700

$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$outLog = Join-Path $UserDir "logs\$Tag-$stamp.stdout.log"
$errLog = Join-Path $UserDir "logs\$Tag-$stamp.stderr.log"
$argLine = "--game `"$game`" --module `"$root\build\gGILE51_recomp_clang.dll`" --user-dir `"$UserDir`" --audio cubeb --automation-dir `"$auto`" --load-state `"$State`""
$p = Start-Process -FilePath "H:\Projects\SB-RFD\build\moderngekko\moderngekko-run.exe" -ArgumentList $argLine -RedirectStandardOutput $outLog -RedirectStandardError $errLog -PassThru

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
    Set-Content -Path (Join-Path $auto "commands\$name.txt") -Value $body -NoNewline
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
Start-Sleep -Seconds 4

$video = Join-Path $outDir "$Tag-$stamp.mp4"
$ffArgLine = "-y -loglevel error -f gdigrab -framerate 15 -i desktop -t $Seconds " +
             "-vf `"scale=1280:-2`" -c:v libx264 -preset ultrafast -pix_fmt yuv420p `"$video`""
$ffLog = Join-Path $outDir "$Tag-$stamp.ffmpeg.log"
$ff = Start-Process -FilePath "H:\Tools\ffmpeg\bin\ffmpeg.exe" -ArgumentList $ffArgLine -PassThru -WindowStyle Hidden -RedirectStandardError $ffLog
Start-Sleep -Seconds 1
for ($i = 1; $i -le $RightPresses; $i++) {
    Send-Command "right-$i" "command=pad_frames`nport=0`nframes=20`nmain_x=1" | Out-Null
    Start-Sleep -Milliseconds 1200
}
$startSent = Get-Date
Send-Command "start-level" "command=pad_frames`nport=0`nframes=20`na=1" | Out-Null
Write-Output "level start at $($startSent.ToString('HH:mm:ss.fff')) (ack at $(Get-Date -Format HH:mm:ss.fff))"
Wait-Process -Id $ff.Id -Timeout ([int]$Seconds + 20)
Get-Process -Id $p.Id -ErrorAction SilentlyContinue | Stop-Process -Force
Write-Output "VIDEO=$video"
if (Test-Path $video) {
    $sheet = Join-Path $outDir "$Tag-$stamp-sheet.png"
    & "H:\Tools\ffmpeg\bin\ffmpeg.exe" -y -loglevel error -i $video -vf "fps=4,scale=480:-2,tile=4x14" -frames:v 1 $sheet
    Write-Output "SHEET=$sheet"
}