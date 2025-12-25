package wasm

/*

Minimal Odin bindings for Wasmtime C API
Only includes what we're actually using - verified against headers

*/

import "core:c"

when ODIN_OS == .Windows {
	foreign import wasmtime "wasmtime-c/lib/wasmtime.dll.lib"
} else when ODIN_OS == .Darwin {
	foreign import wasmtime "system:wasmtime"
} else when ODIN_OS == .Linux {
	foreign import wasmtime "system:wasmtime"
}

// ============================================================================
// Basic types from wasm.h
// ============================================================================

wasm_byte_t :: c.uchar
wasm_byte_vec_t :: struct {
	size: c.size_t,
	data: [^]wasm_byte_t,
}
wasm_name_t :: wasm_byte_vec_t

// Opaque types (passed as pointers)
wasm_engine_t :: struct {}
wasm_trap_t :: struct {}
wasm_functype_t :: struct {}
wasm_valtype_t :: struct {}

// Vector type for valtypes
wasm_valtype_vec_t :: struct {
	size: c.size_t,
	data: [^]^wasm_valtype_t,
}

// Aliases for consistency
wasmtime_engine_t :: wasm_engine_t
wasmtime_trap_t :: wasm_trap_t

// ============================================================================
// Wasmtime types
// ============================================================================

// Opaque pointer types
wasmtime_error_t :: struct {}
wasmtime_store_t :: struct {}
wasmtime_context_t :: struct {}
wasmtime_caller_t :: struct {} // Caller context for host functions
wasmtime_module_t :: struct {}
wasmtime_linker_t :: struct {}

// Value structs (not pointers!)
wasmtime_instance_t :: struct {
	store_id: u64,
	__private: rawptr,  // void* not size_t!
}

wasmtime_func_t :: struct {
	store_id: u64,
	__private: rawptr,  // void* not size_t!
}

wasmtime_memory_t :: struct {
	store_id: u64,
	__private: rawptr,  // void* not size_t!
}

// Value kinds
wasmtime_valkind_t :: enum c.uint8_t {
	I32,
	I64,
	F32,
	F64,
	V128,
	FUNCREF,
	EXTERNREF,
	ANYREF,
}

// Raw value (16 bytes, used for unchecked calls)
wasmtime_val_raw_t :: struct #raw_union {
	i32: i32,
	i64: i64,
	f32: f32,
	f64: f64,
	v128: [16]u8,
	funcref: wasmtime_func_t,
	externref: rawptr,
	anyref: rawptr,
}

// Value union
wasmtime_valunion_t :: struct #raw_union {
	i32: i32,
	i64: i64,
	f32: f32,
	f64: f64,
	// Note: We omit the complex ref types for now since we don't use them
}

// Value type
wasmtime_val_t :: struct {
	kind: wasmtime_valkind_t,
	of: wasmtime_valunion_t,
}

// Extern kinds
wasmtime_extern_kind_t :: enum c.uint8_t {
	FUNC,
	GLOBAL,
	TABLE,
	MEMORY,
	INSTANCE,
	MODULE,
}

// Extern union
wasmtime_extern_union_t :: struct #raw_union {
	func: wasmtime_func_t,
	memory: wasmtime_memory_t,
	// Note: We omit other types since we only use func and memory
}

// Extern type
wasmtime_extern_t :: struct {
	kind: wasmtime_extern_kind_t,
	of: wasmtime_extern_union_t,
}

// ============================================================================
// Foreign functions - only what we actually call
// ============================================================================

@(default_calling_convention="c")
foreign wasmtime {
	// Engine
	wasm_engine_new :: proc() -> ^wasm_engine_t ---
	wasm_engine_delete :: proc(engine: ^wasm_engine_t) ---
	
	// Valtype creation (needed for functypes)
	wasm_valtype_new :: proc(kind: c.uint8_t) -> ^wasm_valtype_t ---
	wasm_valtype_delete :: proc(vt: ^wasm_valtype_t) ---
	
	// Valtype vector
	wasm_valtype_vec_new_empty :: proc(out: ^wasm_valtype_vec_t) ---
	wasm_valtype_vec_new :: proc(out: ^wasm_valtype_vec_t, size: c.size_t, data: [^]^wasm_valtype_t) ---
	wasm_valtype_vec_delete :: proc(vec: ^wasm_valtype_vec_t) ---
	
	// Functype creation
	wasm_functype_new :: proc(params: ^wasm_valtype_vec_t, results: ^wasm_valtype_vec_t) -> ^wasm_functype_t ---
	wasm_functype_delete :: proc(ft: ^wasm_functype_t) ---

	// Store
	wasmtime_store_new :: proc(
		engine: ^wasm_engine_t,
		data: rawptr,
		finalizer: proc "c" (rawptr),
	) -> ^wasmtime_store_t ---
	wasmtime_store_delete :: proc(store: ^wasmtime_store_t) ---
	wasmtime_store_context :: proc(store: ^wasmtime_store_t) -> ^wasmtime_context_t ---

	// Module
	wasmtime_module_new :: proc(
		engine: ^wasm_engine_t,
		wasm: [^]u8,
		wasm_len: c.size_t,
		module_out: ^^wasmtime_module_t,
	) -> ^wasmtime_error_t ---
	wasmtime_module_delete :: proc(module: ^wasmtime_module_t) ---

	// Linker
	wasmtime_linker_new :: proc(engine: ^wasm_engine_t) -> ^wasmtime_linker_t ---
	wasmtime_linker_delete :: proc(linker: ^wasmtime_linker_t) ---
	
	// Define host functions in linker
	wasmtime_linker_define_func :: proc(
		linker: ^wasmtime_linker_t,
		module: [^]u8,
		module_len: c.size_t,
		name: [^]u8,
		name_len: c.size_t,
		ty: ^wasm_functype_t,
		callback: proc "c" (env: rawptr, caller: ^wasmtime_caller_t, args: [^]wasmtime_val_t, nargs: c.size_t, results: [^]wasmtime_val_t, nresults: c.size_t) -> ^wasm_trap_t,
		data: rawptr,
		finalizer: proc "c" (rawptr),
	) -> ^wasmtime_error_t ---
	
	wasmtime_linker_instantiate :: proc(
		linker: ^wasmtime_linker_t,
		store: ^wasmtime_context_t,
		module: ^wasmtime_module_t,
		instance: ^wasmtime_instance_t,
		trap: ^^wasm_trap_t,
	) -> ^wasmtime_error_t ---

	// Function calls
	wasmtime_func_call :: proc(
		store: ^wasmtime_context_t,
		func: ^wasmtime_func_t,
		args: [^]wasmtime_val_t,
		nargs: c.size_t,
		results: [^]wasmtime_val_t,
		nresults: c.size_t,
		trap: ^^wasm_trap_t,
	) -> ^wasmtime_error_t ---

	// Instance exports
	wasmtime_instance_export_get :: proc(
		store: ^wasmtime_context_t,
		instance: ^wasmtime_instance_t,
		name: [^]u8,
		name_len: c.size_t,
		item: ^wasmtime_extern_t,
	) -> c.bool ---

	// Memory access (for future use)
	wasmtime_memory_data :: proc(
		store: ^wasmtime_context_t,
		memory: ^wasmtime_memory_t,
	) -> [^]u8 ---
	wasmtime_memory_data_size :: proc(
		store: ^wasmtime_context_t,
		memory: ^wasmtime_memory_t,
	) -> c.size_t ---

	// Error handling
	wasmtime_error_message :: proc(
		error: ^wasmtime_error_t,
		message: ^wasm_name_t,
	) ---
	wasmtime_error_delete :: proc(error: ^wasmtime_error_t) ---

	// Trap handling
	wasm_trap_message :: proc(
		trap: ^wasm_trap_t,
		message: ^wasm_name_t,
	) ---
	wasm_trap_delete :: proc(trap: ^wasm_trap_t) ---
}

// Convenience aliases
wasmtime_engine_new :: wasm_engine_new
wasmtime_engine_delete :: wasm_engine_delete
wasmtime_trap_message :: wasm_trap_message
wasmtime_trap_delete :: wasm_trap_delete

// Valtype kind constants
WASM_I32 :: 0
WASM_I64 :: 1
WASM_F32 :: 2
WASM_F64 :: 3

// Helper to create a functype (e.g., for (i64, i32, i32) -> ())
make_functype :: proc(param_kinds: []c.uint8_t, result_kinds: []c.uint8_t) -> ^wasm_functype_t {
	// Create param valtypes
	param_valtypes := make([dynamic]^wasm_valtype_t, 0, len(param_kinds))
	defer delete(param_valtypes)
	for kind in param_kinds {
		append(&param_valtypes, wasm_valtype_new(kind))
	}
	
	// Create result valtypes
	result_valtypes := make([dynamic]^wasm_valtype_t, 0, len(result_kinds))
	defer delete(result_valtypes)
	for kind in result_kinds {
		append(&result_valtypes, wasm_valtype_new(kind))
	}
	
	// Create vectors
	params: wasm_valtype_vec_t
	results: wasm_valtype_vec_t
	
	if len(param_valtypes) > 0 {
		wasm_valtype_vec_new(&params, c.size_t(len(param_valtypes)), raw_data(param_valtypes))
	} else {
		wasm_valtype_vec_new_empty(&params)
	}
	
	if len(result_valtypes) > 0 {
		wasm_valtype_vec_new(&results, c.size_t(len(result_valtypes)), raw_data(result_valtypes))
	} else {
		wasm_valtype_vec_new_empty(&results)
	}
	
	// Create functype (takes ownership of vectors)
	return wasm_functype_new(&params, &results)
}
