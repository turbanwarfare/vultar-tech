@echo off
cd /d "%~dp0.."

echo Current directory: %CD%
echo.

echo Installing rokit tools...
rokit install
if %ERRORLEVEL% neq 0 (
    echo Rokit install failed!
    exit /b %ERRORLEVEL%
)

echo.
echo Installing wally packages...
wally install
if %ERRORLEVEL% neq 0 (
    echo Wally install failed!
    exit /b %ERRORLEVEL%
)

echo.
echo Done! All dependencies installed.
