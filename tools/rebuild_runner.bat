@echo off
setlocal
call "C:\Program Files (x86)\Microsoft Visual Studio\18\BuildTools\Common7\Tools\VsDevCmd.bat" -arch=amd64 -host_arch=amd64 >nul
cmake --build "H:\Projects\SB-RFD\build\moderngekko" --target moderngekko-run -j16
exit /b %ERRORLEVEL%
