@echo off
REM Installer for Windows Development Skills toolkit.
REM No admin privileges required.

echo.
echo ================================================
echo  Windows Development Skills - Installation
echo ================================================
echo.

REM Run PowerShell with bypass execution policy
powershell.exe -ExecutionPolicy Bypass -File "%~dp0install.ps1"

if %ERRORLEVEL% EQU 0 (
    echo.
    echo Installation completed successfully!
    echo Open a NEW terminal for PATH changes to take effect.
) else (
    echo.
    echo Installation encountered an error.
    echo Please check the output above for details.
)

echo.
pause