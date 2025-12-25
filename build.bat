@echo off

pushd mods\core
odin build . -target:freestanding_wasm32 -out:core.wasm -no-bounds-check
popd

rem This package is a build script, see build.odin for more
odin run sauce\build -debug -- testarg