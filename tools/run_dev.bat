@echo off
setlocal
set ROOT=%~dp0..
start "" "H:\Projects\SB-RFD\build\moderngekko\moderngekko-run.exe" --game "%ROOT%\work\game" --module "%ROOT%\build\gGILE51_recomp_clang.dll" --user-dir "%ROOT%\work\user" --audio cubeb
exit /b 0
