param(
    [string]$Aspect = "wide",
    [string]$WideHack = "true",
    [string]$OutName = "ws-wide",
    [string]$UserDir = "H:\Projects\Agressive Inline Static Recompile\work\ws_user",
    [string]$Runner = "H:\Projects\SB-RFD\build\moderngekko\moderngekko-run.exe",
    [switch]$Borderless
)
$ErrorActionPreference = "Stop"
$root = "H:\Projects\Agressive Inline Static Recompile"
$game = Join-Path $root "work\game"
$module = Join-Path $root "build\gGILE51_recomp_clang.dll"
$auto = Join-Path $root "work\automation"
$evidence = Join-Path $root "work\evidence"
New-Item -ItemType Directory -Force -Path $UserDir, "$UserDir\Config", "$UserDir\logs", "$auto\commands", "$auto\processed", "$auto\failed", $evidence | Out-Null
Get-ChildItem "$auto\commands","$auto\processed","$auto\failed" -File -ErrorAction SilentlyContinue | Remove-Item -Force
Remove-Item "$auto\status.txt" -Force -ErrorAction SilentlyContinue

# Seed config from the perf user once, then force the requested aspect keys.
if (-not (Test-Path "$UserDir\Config\Dolphin.ini")) {
    Copy-Item "H:\Projects\Agressive Inline Static Recompile\work\perf_user\Config\*" "$UserDir\Config\" -Recurse -Force
    Copy-Item "H:\Projects\Agressive Inline Static Recompile\work\perf_user\Cache" "$UserDir\Cache" -Recurse -Force -ErrorAction SilentlyContinue
}
$config = Join-Path $UserDir "config.ini"
if (-not (Test-Path $config)) {
    @(
        '[Video]',
        'resolution=1920x1080',
        'backend=Vulkan',
        'fullscreen=false',
        'show_fps_in_title=true',
        'mute=false',
        'volume=100',
        'aspect=auto',
        'widescreen_hack=false',
        'efb_access=true'
    ) | Set-Content $config
}
$text = Get-Content $config
$text = $text -replace '^aspect\s*=.*', "aspect=$Aspect"
$text = $text -replace '^widescreen_hack\s*=.*', "widescreen_hack=$WideHack"
$text | Set-Content $config
Get-Content $config | Select-String "aspect|widescreen_hack"

Get-Process | Where-Object { $_.ProcessName -in @('moderngekko-run','gile') } | ForEach-Object { Stop-Process -Id $_.Id -Force }
Start-Sleep -Milliseconds 500
$stamp = Get-Date -Format "HHmmss"
$outLog = Join-Path $UserDir "logs\aspect-$stamp.out.log"
$errLog = Join-Path $UserDir "logs\aspect-$stamp.err.log"
$args = "--core static --game `"$game`" --module `"$module`" --user-dir `"$UserDir`" --audio cubeb --automation-dir `"$auto`""
$p = Start-Process -FilePath $Runner -ArgumentList $args -RedirectStandardOutput $outLog -RedirectStandardError $errLog -NoNewWindow -PassThru

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
$deadline = (Get-Date).AddSeconds(90)
while ((Get-Date) -lt $deadline) {
    $s = Read-Status
    if ($s -and $s.booted -eq '1') { break }
    Start-Sleep -Milliseconds 250
}
$s = Read-Status
if (-not $s -or $s.booted -ne '1') { Write-Output "boot failed"; Get-Process -Id $p.Id -ErrorAction SilentlyContinue | Stop-Process -Force; exit 1 }

if ($Borderless) {
    Add-Type @"
using System;
using System.Runtime.InteropServices;
public static class GileBorderless {
  [DllImport("user32.dll")] public static extern int GetSystemMetrics(int nIndex);
  [DllImport("user32.dll")] public static extern int GetWindowLong(IntPtr hWnd, int nIndex);
  [DllImport("user32.dll")] public static extern int SetWindowLong(IntPtr hWnd, int nIndex, int dwNewLong);
  [DllImport("user32.dll")] public static extern bool SetWindowPos(IntPtr hWnd, IntPtr after, int x, int y, int cx, int cy, uint flags);
  [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
}
"@
    $proc = Get-Process -Id $p.Id -ErrorAction SilentlyContinue
    $deadline = (Get-Date).AddSeconds(30)
    while ((Get-Date) -lt $deadline -and $proc -and $proc.MainWindowHandle -eq 0) { Start-Sleep -Milliseconds 250; $proc.Refresh() }
    if ($proc -and $proc.MainWindowHandle -ne 0) {
        $hwnd = $proc.MainWindowHandle
        $w = [GileBorderless]::GetSystemMetrics(0)
        $h = [GileBorderless]::GetSystemMetrics(1)
        $style = [GileBorderless]::GetWindowLong($hwnd, -16)
        $style = $style -band (-bnot (0x00C00000 -bor 0x00040000 -bor 0x00020000 -bor 0x00010000 -bor 0x00080000))
        $style = $style -bor 0x80000000 -bor 0x10000000
        [GileBorderless]::SetWindowLong($hwnd, -16, $style) | Out-Null
        [GileBorderless]::SetWindowPos($hwnd, [IntPtr]::Zero, 0, 0, $w, $h, 0x0020 -bor 0x0040 -bor 0x0004) | Out-Null
        [GileBorderless]::ShowWindow($hwnd, 9) | Out-Null
        Write-Output "borderless: ${w}x${h}"
        Start-Sleep -Seconds 2
    }
}

Set-Content "$auto\commands\001-load.txt" -Value "command=load_state`npath=H:\Projects\Agressive Inline Static Recompile\work\saves\tutorial-start.state"
Start-Sleep -Seconds 4
Set-Content "$auto\commands\002-a.txt" -Value "command=pad_frames`nport=0`nframes=6`na=1"
Start-Sleep -Seconds 2
Set-Content "$auto\commands\003-a.txt" -Value "command=pad_frames`nport=0`nframes=6`na=1"
Start-Sleep -Seconds 2
$shot = Join-Path $evidence "$OutName.png"
Set-Content "$auto\commands\004-shot.txt" -Value "command=screenshot`npath=$shot"
$shotDeadline = (Get-Date).AddSeconds(20)
while ((Get-Date) -lt $shotDeadline) {
    if (Test-Path (Join-Path $auto "processed\004-shot.txt")) { break }
    if (Test-Path (Join-Path $auto "failed\004-shot.txt")) { break }
    Start-Sleep -Milliseconds 250
}
Start-Sleep -Seconds 3
Get-Process -Id $p.Id -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep -Milliseconds 500
Write-Output "shot: $shot"
Get-Item $shot -ErrorAction SilentlyContinue | Select-Object Name,Length
Write-Output "=== stderr video line ==="
Get-Content $errLog -ErrorAction SilentlyContinue | Select-String -Pattern "\[video\]"
Write-Output "=== stderr tail ==="
Get-Content $errLog -Tail 5 -ErrorAction SilentlyContinue
