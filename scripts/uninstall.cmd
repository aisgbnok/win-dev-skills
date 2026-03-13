@echo off
REM Uninstaller for Windows Development Skills toolkit.
REM No admin privileges required.

echo.
echo ================================================
echo  Windows Development Skills - Uninstall
echo ================================================
echo.

powershell.exe -ExecutionPolicy Bypass -File "%~dp0uninstall.ps1"

if %ERRORLEVEL% EQU 0 (
    echo.
    echo Uninstall completed successfully!
    echo Open a NEW terminal for PATH changes to take effect.
) else (
    echo.
    echo Uninstall encountered an error.
    echo Please check the output above for details.
)

echo.
pause