@echo off
setlocal
call "C:\Program Files (x86)\Microsoft Visual Studio\18\BuildTools\Common7\Tools\VsDevCmd.bat" -arch=amd64 -host_arch=amd64 >nul
cd /d "H:\Projects\SB-RFD\build\moderngekko"
moderngekko-port.exe build "H:\Projects\Agressive Inline Static Recompile\work\game" --backend c --toolchain msvc --opt-level 2 --output "C:\gile\modules"
exit /b %ERRORLEVEL%
