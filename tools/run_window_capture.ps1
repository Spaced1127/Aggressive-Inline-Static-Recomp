param(
    [int]$Seconds = 120,
    [string]$Module = "H:\Projects\Agressive Inline Static Recompile\build\gGILE51_recomp.dll",
    [int[]]$Shots = @(20, 50, 90)
)
$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Drawing
Add-Type @"
using System;
using System.Runtime.InteropServices;
public static class Win32Cap {
    [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left, Top, Right, Bottom; }
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr hWnd, out RECT rect);
    [DllImport("user32.dll")] public static extern bool PrintWindow(IntPtr hWnd, IntPtr hdcBlt, uint nFlags);
}
"@
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

$captured = @{}
$sw = [Diagnostics.Stopwatch]::StartNew()
foreach ($t in $Shots | Sort-Object) {
    $wait = $t * 1000 - $sw.ElapsedMilliseconds
    if ($wait -gt 0) { Start-Sleep -Milliseconds $wait }
    $proc = Get-Process -Id $p.Id -ErrorAction SilentlyContinue
    if (-not $proc) { Write-Output "process exited before ${t}s"; break }
    $win = Get-Process | Where-Object { $_.MainWindowHandle -ne 0 -and $_.ProcessName -like "moderngekko*" } | Select-Object -First 1
    if (-not $win) { Write-Output "${t}s: no window yet"; continue }
    $r = New-Object Win32Cap+RECT
    [Win32Cap]::GetWindowRect($win.MainWindowHandle, [ref]$r) | Out-Null
    $w = $r.Right - $r.Left; $h = $r.Bottom - $r.Top
    if ($w -le 0 -or $h -le 0) { Write-Output "${t}s: bad window size $w x $h"; continue }
    $bmp = New-Object System.Drawing.Bitmap($w, $h)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $hdc = $g.GetHdc()
    $ok = [Win32Cap]::PrintWindow($win.MainWindowHandle, $hdc, 2)
    $g.ReleaseHdc($hdc); $g.Dispose()
    $path = Join-Path $shotDir ("{0}-t{1}.png" -f $stamp, $t)
    $bmp.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
    $bmp.Dispose()
    Write-Output "${t}s: PrintWindow=$ok size=${w}x${h} title='$($win.MainWindowTitle)' -> $path"
}
$exited = $p.WaitForExit(($Seconds * 1000) - $sw.ElapsedMilliseconds)
if (-not $exited) { Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue; Start-Sleep -Milliseconds 500 }
Write-Output "=== exited=$exited code=$(if ($exited) { $p.ExitCode } else { 'killed' }) ==="
Write-Output "=== stderr ==="
Get-Content $errLog -Tail 40 -ErrorAction SilentlyContinue
Write-Output "=== stdout ==="
Get-Content $outLog -Tail 20 -ErrorAction SilentlyContinue
