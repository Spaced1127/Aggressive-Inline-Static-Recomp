@echo off
setlocal
cd /d "%~dp0"
set "GAME=%~1"
if "%GAME%"=="" set "GAME=%~dp0game"
if not exist "%GAME%" (
  echo Put your extracted Aggressive Inline (USA) folder in "%~dp0game",
  echo or pass the folder, .iso or .rvz path:
  echo   run.bat "D:\Aggressive Inline (USA).rvz"
  pause
  exit /b 1
)
set "USERDIR=%LOCALAPPDATA%\AggressiveInlineRecomp"
if not exist "%USERDIR%\game\sys\main.dol" (
  "%~dp0gile-launcher.exe" --prepare --game "%GAME%" --user-dir "%USERDIR%"
  if errorlevel 1 (
    pause
    exit /b 1
  )
)
"%~dp0gile-launcher.exe" --game "%GAME%" --user-dir "%USERDIR%"
