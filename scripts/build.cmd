@echo off
echo Building MainModule...
call rojo build build.project.json -o MainModule.rbxm
if %ERRORLEVEL% neq 0 exit /b %ERRORLEVEL%

echo.
echo Done! Output: MainModule.rbxm
