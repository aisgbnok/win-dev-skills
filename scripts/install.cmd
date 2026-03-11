@echo off
REM Unified installer for Windows Development Skills toolkit.
REM This bypasses PowerShell execution policy restrictions.

echo.
echo ================================================
echo  Windows Development Skills - Installation
echo ================================================
echo.

REM Run PowerShell with bypass execution policy
powershell.exe -ExecutionPolicy Bypass -File "%~dp0install.ps1"

REM Check if the script succeeded
REM Exit code 2 = elevated to another window, skip messaging
if %ERRORLEVEL% EQU 2 goto :eof
if %ERRORLEVEL% EQU 0 (
    echo.
    echo Installation completed successfully!
) else (
    echo.
    echo Installation encountered an error.
    echo Please check the output above for details.
)

echo.
