@echo off
setlocal
set ROOT=%~dp0..
rem Use the project's runner (build\gile.exe, the one the release ships). It
rem binds the first connected SDL pad when the profile's device is missing, so
rem any controller works without editing GCPadNew.ini. The shared
rem SB-RFD moderngekko-run.exe is older and lacks that fallback.
rem gile.exe loads Sys\ from its own folder: build\Sys is a junction to
rem H:\Projects\SB-RFD\build\moderngekko\Sys (create it once with
rem   mklink /J build\Sys H:\Projects\SB-RFD\build\moderngekko\Sys).
if not exist "%ROOT%\build\Sys" (
  echo build\Sys is missing. Run: mklink /J "%ROOT%\build\Sys" "H:\Projects\SB-RFD\build\moderngekko\Sys"
  exit /b 1
)
if not exist "%ROOT%\work\user\GameSettings" mkdir "%ROOT%\work\user\GameSettings"
copy /Y "%ROOT%\assets\GameSettings\GILE51.ini" "%ROOT%\work\user\GameSettings\GILE51.ini" >nul
start "" "%ROOT%\build\gile.exe" --core static --game "%ROOT%\work\game" --module "%ROOT%\build\gGILE51_recomp_clang.dll" --user-dir "%ROOT%\work\user" --audio cubeb %*
exit /b 0
