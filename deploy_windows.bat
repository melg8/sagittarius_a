@echo off
rem ============================================================
rem  EVEmu deploy - full deployment in 1 click (double click me)
rem  Installs tools, builds the server, sets up MariaDB + DB
rem  schema, seeds the market and starts eve-server.
rem  Full log: deploy_install.log (next to this file).
rem ============================================================
title EVEmu deploy
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0deploy_windows.ps1" %*
set DEPLOY_EXIT=%errorlevel%
if not "%DEPLOY_EXIT%"=="0" (
    echo.
    echo deploy_windows.ps1 FAILED with exit code %DEPLOY_EXIT%.
    echo Send deploy_install.log for diagnostics.
    pause
)
exit /b %DEPLOY_EXIT%
