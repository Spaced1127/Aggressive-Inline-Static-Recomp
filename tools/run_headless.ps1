param(
    [int]$Seconds = 60,
    [string]$Module = "H:\Projects\Agressive Inline Static Recompile\build\gGILE51_recomp.dll",
    [string]$Extra = ""
)
$ErrorActionPreference = "Stop"
$root = "H:\Projects\Agressive Inline Static Recompile"
$userDir = Join-Path $root "work\user"
$gameDir = Join-Path $root "work\game"
$runDir = Join-Path $root "work\runs"
New-Item -ItemType Directory -Force -Path $runDir | Out-Null
$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$outLog = Join-Path $runDir "$stamp.stdout.log"
$errLog = Join-Path $runDir "$stamp.stderr.log"

$argLine = "--game `"$gameDir`" --module `"$Module`" --user-dir `"$userDir`" --headless"
if ($Extra -ne "") { $argLine += " " + $Extra }

$p = Start-Process -FilePath "H:\Projects\SB-RFD\build\moderngekko\moderngekko-run.exe" `
    -ArgumentList $argLine -RedirectStandardOutput $outLog -RedirectStandardError $errLog `
    -NoNewWindow -PassThru
$exited = $p.WaitForExit($Seconds * 1000)
if (-not $exited) {
    Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue
    Start-Sleep -Milliseconds 500
}
Write-Output "=== run $stamp exited=$exited code=$(if ($exited) { $p.ExitCode } else { 'killed' }) ==="
Write-Output "=== stdout ==="
if (Test-Path $outLog) { Get-Content $outLog -Tail 80 }
Write-Output "=== stderr ==="
if (Test-Path $errLog) { Get-Content $errLog -Tail 80 }
$dolphinLog = Join-Path $userDir "Logs\dolphin.log"
if (Test-Path $dolphinLog) {
    Write-Output "=== dolphin.log tail ==="
    Get-Content $dolphinLog -Tail 120
}
