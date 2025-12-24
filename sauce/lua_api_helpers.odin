package main

/*

Lua API Helpers

Basic type conversion utilities for Lua bindings.

*/

import "core:reflect"
import "core:strings"
import "core:fmt"
import "base:intrinsics"
import lua "vendor:lua/5.4"

// === Type Converters: Lua -> Odin ===

lua_to_f32 :: proc(L: ^lua.State, index: i32) -> f32 {
	return f32(lua.tonumber(L, index))
}

lua_to_bool :: proc(L: ^lua.State, index: i32) -> bool {
	return bool(lua.toboolean(L, index))
}

lua_to_string :: proc(L: ^lua.State, index: i32) -> string {
	return string(lua.tostring(L, index))
}

lua_to_vec2 :: proc(L: ^lua.State, index: i32) -> (Vec2, bool) {
	if !lua.istable(L, index) {
		return {}, false
	}
	
	lua.getfield(L, index, "x")
	x := f32(lua.tonumber(L, -1))
	lua.pop(L, 1)
	
	lua.getfield(L, index, "y")
	y := f32(lua.tonumber(L, -1))
	lua.pop(L, 1)
	
	return Vec2{x, y}, true
}

// === Type Converters: Odin -> Lua ===

push_f32 :: proc(L: ^lua.State, value: f32) {
	lua.pushnumber(L, lua.Number(value))
}

push_bool :: proc(L: ^lua.State, value: bool) {
	lua.pushboolean(L, b32(value))
}

push_string :: proc(L: ^lua.State, value: string) {
	cstr := fmt.ctprintf("%s", value)
	lua.pushstring(L, cstr)
}

push_vec2 :: proc(L: ^lua.State, value: Vec2) {
	lua.createtable(L, 0, 2)
	lua.pushnumber(L, lua.Number(value.x))
	lua.setfield(L, -2, "x")
	lua.pushnumber(L, lua.Number(value.y))
	lua.setfield(L, -2, "y")
}

// === Common Patterns ===

// Get current entity with safety check
current_entity_or_nil :: #force_inline proc(L: ^lua.State) -> (^Entity, bool) {
	entity := lua_get_current_entity()
	if entity == nil {
		lua.pushnil(L)
		return nil, false
	}
	return entity, true
}

// Check if we have enough arguments
check_args :: #force_inline proc(L: ^lua.State, count: i32) -> bool {
	return lua.gettop(L) >= count
}

