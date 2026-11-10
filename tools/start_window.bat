@echo off
setlocal
set ROOT=H:\Projects\Agressive Inline Static Recompile
start "GILE51 window probe" /b "H:\Projects\SB-RFD\build\moderngekko\moderngekko-run.exe" --game "%ROOT%\work\game" --module "%ROOT%\build\gGILE51_recomp_clang.dll" --user-dir "%ROOT%\work\user" --audio cubeb --automation-dir "%ROOT%\work\automation"
exit /b 0
