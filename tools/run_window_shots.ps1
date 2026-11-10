param(
    [int]$Seconds = 120,
    [string]$Module = "H:\Projects\Agressive Inline Static Recompile\build\gGILE51_recomp.dll",
    [int[]]$Shots = @(20, 50, 90)
)
$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
$root = "H:\Projects\Agressive Inline Static Recompile"
$userDir = Join-Path $root "work\user"
$gameDir = Join-Path $root "work\game"
$shotDir = Join-Path $root "work\evidence"
New-Item -ItemType Directory -Force -Path $shotDir | Out-Null
$runDir = Join-Path $root "work\runs"
New-Item -ItemType Directory -Force -Path $runDir | Out-Null
$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$outLog = Join-Path $runDir "$stamp.window.stdout.log"
$errLog = Join-Path $runDir "$stamp.window.stderr.log"

$argLine = "--game `"$gameDir`" --module `"$Module`" --user-dir `"$userDir`""
$p = Start-Process -FilePath "H:\Projects\SB-RFD\build\moderngekko\moderngekko-run.exe" `
    -ArgumentList $argLine -RedirectStandardOutput $outLog -RedirectStandardError $errLog `
    -NoNewWindow -PassThru

function Grab($path) {
    $bounds = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
    $bmp = New-Object System.Drawing.Bitmap($bounds.Width, $bounds.Height)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.CopyFromScreen($bounds.Location, [System.Drawing.Point]::Empty, $bounds.Size)
    $bmp.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
    $g.Dispose(); $bmp.Dispose()
}

$sw = [Diagnostics.Stopwatch]::StartNew()
foreach ($t in $Shots | Sort-Object) {
    $wait = $t * 1000 - $sw.ElapsedMilliseconds
    if ($wait -gt 0) { Start-Sleep -Milliseconds $wait }
    $proc = Get-Process -Id $p.Id -ErrorAction SilentlyContinue
    if (-not $proc) { Write-Output "process exited before ${t}s"; break }
    $win = Get-Process | Where-Object { $_.MainWindowHandle -ne 0 -and $_.ProcessName -like "moderngekko*" } | Select-Object -First 1
    $title = if ($win) { $win.MainWindowTitle } else { "(none)" }
    $path = Join-Path $shotDir ("{0}-t{1}.png" -f $stamp, $t)
    Grab $path
    Write-Output ("{0}s: window='{1}' -> {2}" -f $t, $title, $path)
}
$remaining = ($Seconds * 1000) - $sw.ElapsedMilliseconds
if ($remaining -gt 0) { $exited = $p.WaitForExit($remaining) } else { $exited = $false }
if (-not $exited) { & taskkill /PID $p.Id /T /F | Out-Null; Start-Sleep -Milliseconds 500 }
Write-Output "=== exited=$exited code=$(if ($exited) { $p.ExitCode } else { 'killed' }) ==="
Write-Output "=== stderr ==="
Get-Content $errLog -Tail 40 -ErrorAction SilentlyContinue
