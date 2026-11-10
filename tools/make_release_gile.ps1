param(
    [string]$Version = "0.0.1",
    [string]$Runner = "H:\Projects\SB-RFD\build\moderngekko\moderngekko-run.exe",
    [string]$Module = "H:\Projects\Agressive Inline Static Recompile\build\gGILE51_recomp_clang.dll",
    [string]$Rvz = "H:\Projects\Agressive Inline Static Recompile\build\pyinstaller\dist\rvz_extract.exe",
    [string]$Sys = "H:\Projects\SB-RFD\build\moderngekko\Sys",
    [string]$Licenses = "H:\Projects\SB-RFD\dist\SpongeBobRecomp-Release-v0.1.2\LICENSES"
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$stageName = "AggressiveInline-Recomp-v$Version-Windows-x64"
$stage = Join-Path $root "dist\$stageName"
$zip = Join-Path $root "dist\$stageName.zip"
$csc = "C:\Windows\Microsoft.NET\Framework64\v4.0.30319\csc.exe"

foreach ($p in @($csc, $Runner, $Module, $Rvz, $Sys, $Licenses,
                 (Join-Path $root "tools\gile_launcher.cs"),
                 (Join-Path $root "tools\set_icon.cs"),
                 (Join-Path $root "assets\gile.ico"),
                 (Join-Path $root "recomplauncher.json"),
                 (Join-Path $root "README.md"),
                 (Join-Path $root "PLAYERS.md"),
                 (Join-Path $root "run.bat"),
                 (Join-Path $root "work\user\Config\GCPadNew.ini"))) {
    if (-not (Test-Path $p)) { throw "Missing release input: $p" }
}

if (Test-Path $stage) { Remove-Item $stage -Recurse -Force }
New-Item -ItemType Directory -Force -Path $stage | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $stage "defaults") | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $stage "game") | Out-Null

# Compile the launcher from source so it always matches this tree.
& $csc /nologo /optimize+ /target:exe /r:System.Windows.Forms.dll /r:System.Drawing.dll `
    /win32icon:"$root\assets\gile.ico" /out:"$stage\gile-launcher.exe" `
    (Join-Path $root "tools\gile_launcher.cs")
if ($LASTEXITCODE -ne 0) { throw "gile-launcher.exe build failed" }

Copy-Item -LiteralPath $Runner -Destination (Join-Path $stage "gile.exe") -Force
Copy-Item -LiteralPath $Module -Destination (Join-Path $stage "gGILE51_recomp_clang.dll") -Force
Copy-Item -LiteralPath $Rvz -Destination (Join-Path $stage "rvz_extract.exe") -Force

$setIcon = Join-Path $root "work\set_icon.exe"
& $csc /nologo /target:exe /out:"$setIcon" (Join-Path $root "tools\set_icon.cs")
if ($LASTEXITCODE -ne 0) { throw "set_icon.exe build failed" }
& $setIcon (Join-Path $stage "gile.exe") (Join-Path $root "assets\gile.ico")
if ($LASTEXITCODE -ne 0) { throw "gile.exe icon update failed" }

Copy-Item -LiteralPath $Sys -Destination (Join-Path $stage "Sys") -Recurse -Force
Copy-Item -LiteralPath $Licenses -Destination (Join-Path $stage "LICENSES") -Recurse -Force
Copy-Item -LiteralPath "H:\Projects\SB-RFD\lib\ModernGekko-Template\lib\ModernGekko\LICENSE" `
    -Destination (Join-Path $stage "LICENSES\ModernGekko.txt") -Force
Copy-Item -LiteralPath (Join-Path $root "recomplauncher.json") -Destination $stage -Force
Copy-Item -LiteralPath (Join-Path $root "README.md") -Destination $stage -Force
Copy-Item -LiteralPath (Join-Path $root "PLAYERS.md") -Destination $stage -Force
Copy-Item -LiteralPath (Join-Path $root "run.bat") -Destination $stage -Force
Copy-Item -LiteralPath (Join-Path $root "work\user\Config\GCPadNew.ini") `
    -Destination (Join-Path $stage "defaults\GCPadNew.ini") -Force
Set-Content -LiteralPath (Join-Path $stage "VERSION") -Value "v$Version" -Encoding ASCII

$gameReadme = @"
Put your extracted Aggressive Inline (USA) game folder HERE.

It must contain:
  sys\main.dol
  files\

Or run run.bat with the path to your ISO or RVZ:
  run.bat "D:\Aggressive Inline (USA).rvz"
"@
Set-Content -LiteralPath (Join-Path $stage "game\README.txt") -Value $gameReadme -Encoding ASCII

$licensesReadme = @"
DolRecomp.txt        DolRecomp license
ModernGekko.txt      ModernGekko license
Dolphin-GPL-2.0.txt  Dolphin-derived runtime notice

The release contains no Nintendo game data.
"@
Set-Content -LiteralPath (Join-Path $stage "LICENSES\README.txt") -Value $licensesReadme -Encoding ASCII

# Never ship game data.
$bad = Get-ChildItem $stage -Recurse -File | Where-Object {
    $_.Extension -in ".iso", ".rvz", ".gcm", ".dol", ".thp", ".pak", ".zsd", ".zal" -or
    $_.FullName -match '\\sys\\main\.dol$'
}
if ($bad) { throw ("Refusing to package game data: " + (($bad | ForEach-Object FullName) -join ", ")) }

if (Test-Path $zip) { Remove-Item $zip -Force }
Compress-Archive -Path $stage -DestinationPath $zip -CompressionLevel Optimal
$hash = (Get-FileHash $zip -Algorithm SHA256).Hash
$size = (Get-Item $zip).Length
Write-Output "Built $zip"
Write-Output ("Size: {0:N0} bytes" -f $size)
Write-Output "SHA-256: $hash"
Write-Output "recomplauncher.json: $(Test-Path (Join-Path $stage 'recomplauncher.json'))"
