param(
    [int]$Seconds = 60,
    [int[]]$Shots = @(10, 30, 55),
    [string]$Module = "H:\Projects\Agressive Inline Static Recompile\build\gGILE51_recomp.dll",
    [string]$Commands = ""
)
$ErrorActionPreference = "Stop"
$root = "H:\Projects\Agressive Inline Static Recompile"
$userDir = Join-Path $root "work\user"
$gameDir = Join-Path $root "work\game"
$autoDir = Join-Path $root "work\automation"
$shotDir = Join-Path $root "work\evidence"
New-Item -ItemType Directory -Force -Path $shotDir, "$autoDir\commands", "$autoDir\processed", "$autoDir\failed" | Out-Null
Get-ChildItem "$autoDir\commands" -File -ErrorAction SilentlyContinue | Remove-Item -Force
Get-ChildItem "$autoDir\processed" -File -ErrorAction SilentlyContinue | Remove-Item -Force
$runDir = Join-Path $root "work\runs"
New-Item -ItemType Directory -Force -Path $runDir | Out-Null
$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$outLog = Join-Path $runDir "$stamp.auto.stdout.log"
$errLog = Join-Path $runDir "$stamp.auto.stderr.log"

$argLine = "--game `"$gameDir`" --module `"$Module`" --user-dir `"$userDir`" --headless --automation-dir `"$autoDir`""
$p = Start-Process -FilePath "H:\Projects\SB-RFD\build\moderngekko\moderngekko-run.exe" `
    -ArgumentList $argLine -RedirectStandardOutput $outLog -RedirectStandardError $errLog `
    -NoNewWindow -PassThru

function Send-Command([string]$name, [string]$body) {
    $path = Join-Path $autoDir "commands\$name.txt"
    Set-Content -Path $path -Value $body -NoNewline
    $deadline = (Get-Date).AddSeconds(30)
    while ((Get-Date) -lt $deadline) {
        if (Test-Path (Join-Path $autoDir "processed\$name.txt")) { return $true }
        if (Test-Path (Join-Path $autoDir "failed\$name.txt")) { return $false }
        Start-Sleep -Milliseconds 100
    }
    return $false
}

$sw = [Diagnostics.Stopwatch]::StartNew()
try {
    foreach ($t in $Shots | Sort-Object) {
        $wait = $t * 1000 - $sw.ElapsedMilliseconds
        if ($wait -gt 0) { Start-Sleep -Milliseconds $wait }
        $proc = Get-Process -Id $p.Id -ErrorAction SilentlyContinue
        if (-not $proc) { Write-Output "process exited before ${t}s"; break }
        $rel = "../evidence/$stamp-t$t.png"
        $name = "shot-$t"
        $body = "command=screenshot`npath=$rel"
        $ok = Send-Command $name $body
        Write-Output ("{0}s: screenshot ok={1} -> work/{2}" -f $t, $ok, $rel)
    }
    if ($Commands -ne "") {
        foreach ($line in Get-Content $Commands) {
            if ($line.Trim() -eq "" -or $line.Trim().StartsWith("#")) { continue }
            $n = "extra-$($sw.ElapsedMilliseconds)"
            $ok = Send-Command $n $line
            Write-Output "extra: $line => $ok"
            Start-Sleep -Milliseconds 500
        }
    }
} finally {
    $remaining = ($Seconds * 1000) - $sw.ElapsedMilliseconds
    if ($remaining -gt 0) { Start-Sleep -Milliseconds $remaining }
    $proc = Get-Process -Id $p.Id -ErrorAction SilentlyContinue
    if ($proc) { & taskkill /PID $p.Id /T /F | Out-Null; Start-Sleep -Milliseconds 500 }
}

Write-Output "=== automation status ==="
Get-Content (Join-Path $autoDir "status.txt") -ErrorAction SilentlyContinue
Write-Output "=== failed ==="
Get-ChildItem "$autoDir\failed" -File -ErrorAction SilentlyContinue | ForEach-Object { $_.Name; Get-Content $_.FullName }
Write-Output "=== stderr ==="
Get-Content $errLog -Tail 20 -ErrorAction SilentlyContinue
