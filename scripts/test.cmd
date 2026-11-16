@echo off
cd /d "%~dp0.."

echo Building test place...
call rojo build test.project.json -o test-place.rbxl
if %ERRORLEVEL% neq 0 exit /b %ERRORLEVEL%

echo.
echo Running tests...
call run-in-roblox --place test-place.rbxl --script test/TestRunner.server.lua

echo.
echo Cleaning up...
del /f test-place.rbxl 2>nul

echo Done!
