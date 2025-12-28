@echo off

rem Check if game.lib exists
if not exist "build\windows_debug\game.lib" (
    echo Error: game.lib not found. Run build_game.bat first.
    exit /b 1
)

echo Building mod...
pushd mods\core
odin build . -build-mode:dll -out:core.dll -debug
popd

if %ERRORLEVEL% EQU 0 (
    echo Mod build successful!
) else (
    echo Mod build failed!
    exit /b 1
)
