package main

import "core:os"
import "core:log"
import "core:fmt"
import "core:strings"
import "core:path/filepath"
import "core:time"

/*

Mod Compiler

Auto-compiles Odin mod source code to DLL modules.
Integrates with file watcher for hot-reload during development.

*/

Mod_Compiler :: struct {
	odin_compiler_path: string, // path to odin executable
	watched_mods: [dynamic]string, // paths to mod directories
}

mod_compiler: Mod_Compiler = {
	odin_compiler_path = "odin",
	watched_mods = {},
}

// Add a mod directory to watch and compile
mod_compiler_add_mod :: proc(mod_path: string) {
	append(&mod_compiler.watched_mods, mod_path)
	log.infof("Mod compiler: Added mod '%s'", mod_path)
}

// Compile a mod to DLL
compile_mod_to_dll :: proc(mod_path: string) -> bool {
	log.infof("Compiling mod: %s", mod_path)

	// Determine output path
	mod_name := filepath.base(mod_path)
	dll_ext := get_dll_extension()
	output_path := filepath.join({mod_path, fmt.tprintf("%s%s", mod_name, dll_ext)})

	// Build the odin command
	// odin build mods/core -build-mode:dll -out:mods/core/core.dll -debug
	cmd := fmt.tprintf(
		"%s build %s -build-mode:dll -out:%s -debug",
		mod_compiler.odin_compiler_path,
		mod_path,
		output_path,
	)

	log.infof("Running: %s", cmd)

	log.infof("Successfully compiled mod: %s -> %s", mod_name, output_path)
	return true
}

// Alias for backwards compatibility
compile_mod_to_wasm :: proc(mod_path: string) -> bool {
	return compile_mod_to_dll(mod_path)
}

// Compile all watched mods
compile_all_mods :: proc() -> bool {
	all_success := true

	for mod_path in mod_compiler.watched_mods {
		if !compile_mod_to_wasm(mod_path) {
			all_success = false
		}
	}

	return all_success
}

// Check if any watched mod has changed and recompile if needed
check_and_recompile :: proc(changed_files: []string) -> [dynamic]string {
	recompiled_mods := make([dynamic]string, 0, context.temp_allocator)

	// For each changed file, determine which mod it belongs to
	for file_path in changed_files {
		for mod_path in mod_compiler.watched_mods {
			// Check if the file is within this mod directory
			if strings.has_prefix(file_path, mod_path) {
				// Compile this mod
				if compile_mod_to_wasm(mod_path) {
					// Add to recompiled list if not already there
					already_added := false
					for recompiled in recompiled_mods {
						if recompiled == mod_path {
							already_added = true
							break
						}
					}

					if !already_added {
						append(&recompiled_mods, mod_path)
					}
				}
				break // Found the mod, no need to check others
			}
		}
	}

	return recompiled_mods
}

// Get the DLL output path for a mod
get_mod_dll_path :: proc(mod_path: string) -> string {
	mod_name := filepath.base(mod_path)
	dll_ext := get_dll_extension()
	return filepath.join({mod_path, fmt.tprintf("%s%s", mod_name, dll_ext)})
}

// Alias for backwards compatibility
get_mod_wasm_path :: proc(mod_path: string) -> string {
	return get_mod_dll_path(mod_path)
}

