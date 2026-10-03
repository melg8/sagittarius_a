@echo off
rem ============================================================
rem  EVEmu build and run - rebuild + server restart in 1 click
rem  (double click me). Requires prior full deployment via
rem  deploy_windows.bat.
rem  Log: .winbuild\logs\build_and_run.log
rem ============================================================
title EVEmu build and run
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0build_and_run.ps1" %*
set BUILD_EXIT=%errorlevel%
if not "%BUILD_EXIT%"=="0" (
    echo.
    echo build_and_run.ps1 FAILED with exit code %BUILD_EXIT%.
    echo See .winbuild\logs\build_and_run.log
    pause
)
exit /b %BUILD_EXIT%
