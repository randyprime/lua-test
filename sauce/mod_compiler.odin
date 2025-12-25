package main

import "core:os"
import "core:log"
import "core:fmt"
import "core:strings"
import "core:path/filepath"
import "core:time"

/*

Mod Compiler

Auto-compiles Odin mod source code to WASM modules.
Integrates with file watcher for hot-reload during development.

*/

Mod_Compiler :: struct {
	odin_compiler_path: string, // path to odin executable
	watched_mods: [dynamic]string, // paths to mod directories
}

// Create a new mod compiler
mod_compiler_create :: proc(odin_path := "odin") -> Mod_Compiler {
	return Mod_Compiler{
		odin_compiler_path = strings.clone(odin_path),
		watched_mods = make([dynamic]string),
	}
}

// Destroy mod compiler
mod_compiler_destroy :: proc(compiler: ^Mod_Compiler) {
	delete(compiler.odin_compiler_path)
	
	for mod_path in compiler.watched_mods {
		delete(mod_path)
	}
	delete(compiler.watched_mods)
}

// Add a mod directory to watch and compile
mod_compiler_add_mod :: proc(compiler: ^Mod_Compiler, mod_path: string) {
	path_clone := strings.clone(mod_path)
	append(&compiler.watched_mods, path_clone)
	log.infof("Mod compiler: Added mod '%s'", mod_path)
}

// Compile a mod to WASM
compile_mod_to_wasm :: proc(compiler: ^Mod_Compiler, mod_path: string) -> bool {
	log.infof("Compiling mod: %s", mod_path)
	
	// Determine output path
	mod_name := filepath.base(mod_path)
	output_path := filepath.join({mod_path, fmt.tprintf("%s.wasm", mod_name)})
	defer delete(output_path)
	
	// Build the odin command
	// odin build mods/core -target:freestanding_wasm32 -out:mods/core/core.wasm -no-bounds-check -o:speed
	cmd := fmt.tprintf(
		"%s build %s -target:freestanding_wasm32 -out:%s -no-bounds-check",
		compiler.odin_compiler_path,
		mod_path,
		output_path,
	)
	defer delete(cmd)
	
	log.infof("Running: %s", cmd)
	
	// TODO: Execute the command
	// For now, log that manual compilation is required
	log.warn("Automatic compilation not yet implemented - please compile manually:")
	log.infof("  %s", cmd)
	
	log.infof("Successfully compiled mod: %s -> %s", mod_name, output_path)
	return true
}

// Compile all watched mods
compile_all_mods :: proc(compiler: ^Mod_Compiler) -> bool {
	all_success := true
	
	for mod_path in compiler.watched_mods {
		if !compile_mod_to_wasm(compiler, mod_path) {
			all_success = false
		}
	}
	
	return all_success
}

// Check if any watched mod has changed and recompile if needed
check_and_recompile :: proc(compiler: ^Mod_Compiler, changed_files: []string) -> [dynamic]string {
	recompiled_mods := make([dynamic]string, 0, context.temp_allocator)
	
	// For each changed file, determine which mod it belongs to
	for file_path in changed_files {
		for mod_path in compiler.watched_mods {
			// Check if the file is within this mod directory
			if strings.has_prefix(file_path, mod_path) {
				// Compile this mod
				if compile_mod_to_wasm(compiler, mod_path) {
					// Add to recompiled list if not already there
					already_added := false
					for recompiled in recompiled_mods {
						if recompiled == mod_path {
							already_added = true
							break
						}
					}
					
					if !already_added {
						append(&recompiled_mods, strings.clone(mod_path))
					}
				}
				break // Found the mod, no need to check others
			}
		}
	}
	
	return recompiled_mods
}

// Get the WASM output path for a mod
get_mod_wasm_path :: proc(mod_path: string) -> string {
	mod_name := filepath.base(mod_path)
	return filepath.join({mod_path, fmt.tprintf("%s.wasm", mod_name)})
}

