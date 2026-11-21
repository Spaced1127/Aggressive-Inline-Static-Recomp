param(
    [string]$UserDir = "H:\Projects\Agressive Inline Static Recompile\work\perf_stutter\fastdisc_user",
    [string]$State = "H:\Projects\Agressive Inline Static Recompile\work\memtest\levelselect.state",
    [int]$Seconds = 16,
    [string]$Tag = "thread-sample",
    [int]$RightPresses = 0
)
$ErrorActionPreference = "Stop"
$root = "H:\Projects\Agressive Inline Static Recompile"
$auto = Join-Path $root "work\perf_stutter\automation"
$game = Join-Path $root "work\game"
New-Item -ItemType Directory -Force -Path "$auto\commands", "$auto\processed", "$auto\failed" | Out-Null
Get-ChildItem "$auto\commands","$auto\processed","$auto\failed" -File -ErrorAction SilentlyContinue | Remove-Item -Force
Remove-Item (Join-Path $auto "status.txt") -Force -ErrorAction SilentlyContinue
Get-Process | Where-Object { $_.ProcessName -in @('gile','moderngekko-run','PresentMon') } | ForEach-Object { Stop-Process -Id $_.Id -Force }
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
for ($i = 1; $i -le $RightPresses; $i++) {
    Send-Command "right-$i" "command=pad_frames`nport=0`nframes=20`nmain_x=1" | Out-Null
    Start-Sleep -Milliseconds 1200
}
Send-Command "start-level" "command=pad_frames`nport=0`nframes=20`na=1" | Out-Null

$src = @"
using System;
using System.Diagnostics;
using System.Threading;
using System.Collections.Generic;
using System.Linq;

public static class ThreadSampler
{
    public static void Run(int pid, int seconds)
    {
        Process p = Process.GetProcessById(pid);
        p.Refresh();
        var last = new Dictionary<int, double>();
        foreach (ProcessThread t in p.Threads) { try { last[t.Id] = t.TotalProcessorTime.TotalMilliseconds; } catch {} }
        var sw = Stopwatch.StartNew();
        double lastSample = 0;
        while (sw.Elapsed.TotalSeconds < seconds)
        {
            Thread.Sleep(10);
            if (sw.Elapsed.TotalMilliseconds - lastSample < 100) continue;
            double elapsed = sw.Elapsed.TotalMilliseconds - lastSample;
            lastSample = sw.Elapsed.TotalMilliseconds;
            p.Refresh();
            var rows = new List<string>();
            double total = 0;
            foreach (ProcessThread t in p.Threads)
            {
                double cpu;
                try { cpu = t.TotalProcessorTime.TotalMilliseconds; } catch { continue; }
                double prev;
                if (!last.TryGetValue(t.Id, out prev)) prev = cpu;
                last[t.Id] = cpu;
                double delta = cpu - prev;
                if (delta <= 0) continue;
                total += delta;
                string wait = "";
                try { wait = t.WaitReason.ToString(); } catch { wait = "?"; }
                string state = "";
                try { state = t.ThreadState.ToString(); } catch { state = "?"; }
                rows.Add(string.Format("{0,6} {1,-9} {2,-16} {3,7:F1}ms {4,5:F0}%", t.Id, state, wait, delta, delta / elapsed * 100.0));
            }
            Console.WriteLine("T={0,7:F0}ms total={1,6:F1}ms util={2,5:F0}%", sw.Elapsed.TotalMilliseconds, total, total / elapsed * 100.0);
            foreach (var r in rows.OrderByDescending(x => x).Take(6)) Console.WriteLine("   " + r);
        }
    }
}
"@
Add-Type -TypeDefinition $src -Language CSharp
[ThreadSampler]::Run($p.Id, $Seconds)

Send-Command "stop" "command=stop" | Out-Null
Start-Sleep -Milliseconds 500
Get-Process -Id $p.Id -ErrorAction SilentlyContinue | Stop-Process -Force
Write-Output "--- stderr tail ---"
Get-Content $errLog -Tail 8 -ErrorAction SilentlyContinue