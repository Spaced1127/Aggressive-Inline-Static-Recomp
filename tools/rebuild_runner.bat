@echo off
setlocal
call "C:\Program Files (x86)\Microsoft Visual Studio\18\BuildTools\Common7\Tools\VsDevCmd.bat" -arch=amd64 -host_arch=amd64 >nul
rem The shared ModernGekko build tree is configured for another port, so the
rem Aggressive Inline runner needs its own branding values on every configure:
rem runner name, window title, user-directory name and no fixed disc ID.
"C:\Program Files\CMake\bin\cmake.exe" "H:\Projects\SB-RFD\build\moderngekko" -DMODERNGEKKO_RUNNER_OUTPUT_NAME=gile -DMODERNGEKKO_DEFAULT_WINDOW_TITLE="Aggressive Inline" -DMODERNGEKKO_USER_DIRECTORY_NAME=moderngekko "-DMODERNGEKKO_REQUIRED_DISC_ID:STRING=" "-DMODERNGEKKO_REQUIRED_DOL_SHA256:STRING="
if errorlevel 1 exit /b %ERRORLEVEL%
cmake --build "H:\Projects\SB-RFD\build\moderngekko" --target moderngekko-run -j16
exit /b %ERRORLEVEL%