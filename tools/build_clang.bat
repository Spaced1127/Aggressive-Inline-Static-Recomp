@echo off
setlocal
call "C:\Program Files (x86)\Microsoft Visual Studio\18\BuildTools\Common7\Tools\VsDevCmd.bat" -arch=amd64 -host_arch=amd64 >nul
set PATH=C:\Program Files\LLVM\bin;%PATH%
set CFLAGS=-march=x86-64-v3 -mtune=generic
set DOLRECOMP_C_LOOP_CYCLE_BUDGET=4096
set DOLRECOMP_C_MAX_CALL_DEPTH=128
cd /d "H:\Projects\SB-RFD\build\moderngekko"
moderngekko-port.exe build "H:\Projects\Agressive Inline Static Recompile\work\game" --backend c --toolchain clang --opt-level 3 --output "C:\gile\modules-clang"
exit /b %ERRORLEVEL%
