package main

/*

Lua API Helpers - Reduce Boilerplate

These helpers eliminate repetitive patterns when creating Lua bindings.

*/

import "core:log"
import "core:fmt"
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

// === MACROS: Simple Getters ===

// GETTER_F32: Returns a single f32 value
// Usage: return GETTER_F32(L, entity.rotation)
GETTER_F32 :: #force_inline proc(L: ^lua.State, value: f32) -> i32 {
	push_f32(L, value)
	return 1
}

// GETTER_BOOL: Returns a single bool value
// Usage: return GETTER_BOOL(L, entity.flip_x)
GETTER_BOOL :: #force_inline proc(L: ^lua.State, value: bool) -> i32 {
	push_bool(L, value)
	return 1
}

// GETTER_VEC2: Returns a Vec2 as {x, y} table
// Usage: return GETTER_VEC2(L, entity.pos)
GETTER_VEC2 :: #force_inline proc(L: ^lua.State, value: Vec2) -> i32 {
	push_vec2(L, value)
	return 1
}

// === MACROS: Simple Setters ===

// SETTER_F32: Sets a single f32 value from arg 1
// Usage: SETTER_F32(L, &entity.rotation)
SETTER_F32 :: #force_inline proc(L: ^lua.State, target: ^f32) {
	if check_args(L, 1) {
		target^ = lua_to_f32(L, 1)
	}
}

// SETTER_BOOL: Sets a single bool value from arg 1
// Usage: SETTER_BOOL(L, &entity.flip_x)
SETTER_BOOL :: #force_inline proc(L: ^lua.State, target: ^bool) {
	if check_args(L, 1) {
		target^ = lua_to_bool(L, 1)
	}
}

// SETTER_VEC2: Sets a Vec2 from args (x, y)
// Usage: SETTER_VEC2(L, &entity.pos)
SETTER_VEC2 :: #force_inline proc(L: ^lua.State, target: ^Vec2) {
	if check_args(L, 2) {
		target.x = lua_to_f32(L, 1)
		target.y = lua_to_f32(L, 2)
	}
}

// === MACRO: Complete Getter Function ===

// Creates a complete getter function with entity check
// Returns the specified field from current entity
ENTITY_GETTER :: proc(L: ^lua.State, $T: typeid, getter: proc(^Entity) -> T, pusher: proc(^lua.State, T)) -> i32 {
	context = runtime_context()
	entity, ok := current_entity_or_nil(L)
	if !ok do return 1
	
	value := getter(entity)
	pusher(L, value)
	return 1
}

// === MACRO: Complete Setter Function ===

// Creates a complete setter function with entity check
ENTITY_SETTER :: proc(L: ^lua.State, $T: typeid, min_args: i32, extractor: proc(^lua.State) -> T, setter: proc(^Entity, T)) -> i32 {
	context = runtime_context()
	entity, ok := current_entity_or_nil(L)
	if !ok do return 0
	
	if !check_args(L, min_args) do return 0
	
	value := extractor(L)
	setter(entity, value)
	return 0
}

// === Action/Input Helpers ===

// Convert string to Input_Action enum
string_to_action :: proc(action_name: cstring) -> (Input_Action, bool) {
	switch action_name {
	case "left": return .left, true
	case "right": return .right, true
	case "up": return .up, true
	case "down": return .down, true
	case "click": return .click, true
	case "use": return .use, true
	case "interact": return .interact, true
	}
	return .left, false
}

// Convert string to Sprite_Name enum
string_to_sprite :: proc(sprite_name: cstring) -> (Sprite_Name, bool) {
	switch sprite_name {
	case "player_idle": return .player_idle, true
	case "player_run": return .player_run, true
	case "player_still": return .player_still, true
	case "player_death": return .player_death, true
	case "shadow_medium": return .shadow_medium, true
	case "bald_logo": return .bald_logo, true
	case "fmod_logo": return .fmod_logo, true
	case "bg_repeat_tex0": return .bg_repeat_tex0, true
	}
	return .nil, false
}

