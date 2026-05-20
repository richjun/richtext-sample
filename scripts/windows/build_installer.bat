@echo off
REM Build Flutter Windows release and package as Inno Setup installer.
REM Run this from a Windows machine with Flutter SDK + Inno Setup 6 installed.

setlocal EnableDelayedExpansion

REM --- Resolve project root (two levels up from this script) ---
set "SCRIPT_DIR=%~dp0"
pushd "%SCRIPT_DIR%..\.." || exit /b 1
set "PROJECT_ROOT=%cd%"

echo.
echo [1/3] flutter pub get
call flutter pub get || goto :fail

echo.
echo [2/3] flutter build windows --release
call flutter build windows --release || goto :fail

REM --- Locate Inno Setup compiler (ISCC.exe) ---
set "ISCC="
for %%P in (
    "%ProgramFiles(x86)%\Inno Setup 6\ISCC.exe"
    "%ProgramFiles%\Inno Setup 6\ISCC.exe"
    "%ProgramFiles(x86)%\Inno Setup 5\ISCC.exe"
) do (
    if exist %%P set "ISCC=%%~P"
)

if not defined ISCC (
    echo.
    echo ERROR: Inno Setup ^(ISCC.exe^) not found.
    echo Install from https://jrsoftware.org/isdl.php and retry.
    goto :fail
)

echo.
echo [3/3] Building installer with: "!ISCC!"
"!ISCC!" "%SCRIPT_DIR%installer.iss" || goto :fail

echo.
echo === DONE ===
echo Installer: %PROJECT_ROOT%\build\installer\
dir /b "%PROJECT_ROOT%\build\installer\*.exe"
popd
exit /b 0

:fail
echo.
echo *** BUILD FAILED ***
popd
exit /b 1
