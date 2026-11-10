@echo off
setlocal
set ROOT=H:\Projects\Agressive Inline Static Recompile
start "GILE51 jit probe" /b "H:\Projects\SB-RFD\build\moderngekko\moderngekko-run.exe" --game "%ROOT%\work\game" --user-dir "%ROOT%\work\user" --audio cubeb --allow-interpreter --headless --automation-dir "%ROOT%\work\automation"
exit /b 0
