@echo off
setlocal
set ROOT=H:\Projects\Agressive Inline Static Recompile
start "GILE51 probe" /b "H:\Projects\SB-RFD\build\moderngekko\moderngekko-run.exe" --game "%ROOT%\work\game" --module "%ROOT%\build\gGILE51_recomp_clang.dll" --user-dir "%ROOT%\work\user" --audio cubeb --headless --automation-dir "%ROOT%\work\automation"
exit /b 0
