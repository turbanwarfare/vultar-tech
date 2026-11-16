@echo off
echo Running Selene linter...
call selene src/
if %ERRORLEVEL% neq 0 exit /b %ERRORLEVEL%

echo.
echo Lint passed!
