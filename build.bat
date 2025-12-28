@echo off

rem Build main game first (creates game.exe with exported functions)
odin run sauce\build -debug -- testarg

rem Build core mod as DLL (links against game.exe)
pushd mods\core
odin build . -build-mode:dll -out:core.dll -debug
popd

rem Build example mod as DLL
pushd mods\example_mod
odin build . -build-mode:dll -out:example_mod.dll -debug
popd