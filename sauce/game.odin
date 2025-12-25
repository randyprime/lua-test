#+feature dynamic-literals
package main

/*

GAMEPLAY O'CLOCK MEGAFILE

*/

import "utils"
import "utils/shape"
import "utils/color"

import "core:log"
import "core:fmt"
import "core:mem"
import "core:math"
import "core:math/linalg"
import "core:os"
import "core:encoding/cbor"

import sapp "sokol/app"
import spall "core:prof/spall"
import wasm "wasm"

VERSION :string: "v0.0.0"
WINDOW_TITLE :: "Template [bald]"
GAME_RES_WIDTH :: 480
GAME_RES_HEIGHT :: 270
window_w := 1280
window_h := 720

// WASM mod system globals
loaded_mods: map[string]^wasm.Wasm_Mod
mod_compiler: Mod_Compiler
file_watcher: File_Watcher

when NOT_RELEASE {
	// can edit stuff in here to be whatever for testing
	PROFILE :: false
} else {
	// then this makes sure we've got the right settings for release
	PROFILE :: false
}

//
// epic game state

Game_State :: struct {
	ticks: u64,
	game_time_elapsed: f64,
	cam_pos: Vec2, // this is used by the renderer

	// entity system
	entity_top_count: int,
	latest_entity_id: int,
	entities: [MAX_ENTITIES]Entity,
	entity_free_list: [dynamic]int,

	// sloppy state dump
	player_handle: Entity_Handle,

	scratch: struct {
		all_entities: []Entity_Handle,
	}
}

//
// action -> key mapping

action_map: map[Input_Action]Key_Code = {
	.left = .A,
	.right = .D,
	.up = .W,
	.down = .S,
	.click = .LEFT_MOUSE,
	.use = .RIGHT_MOUSE,
	.interact = .E,
}

Input_Action :: enum u8 {
	left,
	right,
	up,
	down,
	click,
	use,
	interact,
}

//
// entity system

Entity :: struct {
	handle: Entity_Handle,

	// Function pointers for update and draw (set once, not serialized)
	update_proc: proc(^Entity) `cbor:"-"`,
	draw_proc: proc(Entity) `cbor:"-"`,

	// WASM entity support - entities are controlled by WASM mods
	is_wasm_entity: bool `cbor:"-"`,
	wasm_script_name: string, // Name of the entity type (e.g., "player", "wanderer")
	wasm_entity_id: u64 `cbor:"-"`, // ID used by WASM mod

	// big sloppy entity state dump.
	// add whatever you need in here.
	pos: Vec2,
	last_known_x_dir: f32,
	flip_x: bool,
	draw_offset: Vec2,
	draw_pivot: utils.Pivot,
	rotation: f32,
	hit_flash: Vec4,
	sprite: Sprite_Name,
	anim_index: int,
  next_frame_end_time: f64,
  loop: bool,
  frame_duration: f32,
	
	// this gets zeroed every frame. Useful for passing data to other systems.
	scratch: struct {
		col_override: Vec4,
	}
}

// Minimal entity setup - just sets function pointers
entity_setup :: proc(e: ^Entity) {
	// Set default function pointers for all entities
	e.draw_proc = draw_entity_default
	e.draw_pivot = .bottom_center
	
	// All entities use WASM-based update
	e.update_proc = proc(e: ^Entity) {
		wasm_call_entity_update(e)
	}
	e.is_wasm_entity = true
	e.wasm_entity_id = u64(e.handle.id)
}

//
// game :draw related things

Quad_Flags :: enum u8 {
	// #shared with the shader.glsl definition
	background_pixels = (1<<0),
	flag2 = (1<<1),
	flag3 = (1<<2),
}

ZLayer :: enum u8 {
	// Can add as many layers as you want in here.
	// Quads get sorted and drawn lowest to highest.
	// When things are on the same layer, they follow normal call order.
	nil,
	background,
	shadow,
	playspace,
	vfx,
	ui,
	tooltip,
	pause_menu,
	top,
}

Sprite_Name :: enum {
	nil,
	bald_logo,
	fmod_logo,
	player_still,
	shadow_medium,
	bg_repeat_tex0,
	player_death,
	player_run,
	player_idle,
	// to add new sprites, just put the .png in the res/images folder
	// and add the name to the enum here
	//
	// we could auto-gen this based on all the .png's in the images folder
	// but I don't really see the point right now. It's not hard to type lol.
}

sprite_data: [Sprite_Name]Sprite_Data = #partial {
	.player_idle = {frame_count=2},
	.player_run = {frame_count=3}
}

Sprite_Data :: struct {
	frame_count: int,
	offset: Vec2,
	pivot: utils.Pivot,
}

get_sprite_offset :: proc(img: Sprite_Name) -> (offset: Vec2, pivot: utils.Pivot) {
	data := sprite_data[img]
	offset = data.offset
	pivot = data.pivot
	return
}

// #cleanup todo, this is kinda yuckie living in the bald-user
get_frame_count :: proc(sprite: Sprite_Name) -> int {
	frame_count := sprite_data[sprite].frame_count
	if frame_count == 0 {
		frame_count = 1
	}
	return frame_count
}

get_sprite_center_mass :: proc(img: Sprite_Name) -> Vec2 {
	size := get_sprite_size(img)
	
	offset, pivot := get_sprite_offset(img)
	
	center := size * utils.scale_from_pivot(pivot)
	center -= offset
	
	return center
}

//
// main game procs

app_init :: proc() {
	// Initialize WASM runtime
	wasm_runtime_init()
	
	// Set host context for API calls
	wasm.set_host_context(&ctx, &our_context)
	
	// Initialize mod compiler
	mod_compiler = mod_compiler_create()
	mod_compiler_add_mod(&mod_compiler, "mods/core")
	
	// Compile core mod
	if !compile_mod_to_wasm(&mod_compiler, "mods/core") {
		log.error("Failed to compile core mod!")
	}
	
	// Load core mod
	wasm_path := get_mod_wasm_path("mods/core")
	defer delete(wasm_path)
	core_mod, core_ok := wasm.load_wasm_mod(wasm_path, "core")
	if !core_ok {
		log.error("Failed to load core mod!")
	} else {
		loaded_mods["core"] = core_mod
		wasm.call_mod_init(core_mod)
		log.info("Core mod loaded and initialized")
	}
	
	// Initialize file watcher for hot-reload
	file_watcher = file_watcher_create(".odin", 1.0)
	file_watcher_add_directory(&file_watcher, "mods")
}

app_frame :: proc() {

	// right now we are just calling the game update, but in future this is where you'd do a big
	// "UX" switch for startup splash, main menu, settings, in-game, etc

	{
		// ui space example
		push_coord_space(get_screen_space())

		x, y := screen_pivot(.top_left)
		x += 2
		y -= 2
		draw_text({x, y}, "hello world.", z_layer=.ui, pivot=utils.Pivot.top_left)
	}

	sound_play_continuously("event:/ambiance", "")

	game_update()
	game_draw()

	volume :f32= 0.75
	sound_update(get_player().pos, volume)
}

app_shutdown :: proc() {
	// called on exit
	
	// Unload all mods
	for name, mod in loaded_mods {
		wasm.unload_wasm_mod(mod)
	}
	delete(loaded_mods)
	
	// Cleanup systems
	file_watcher_destroy(&file_watcher)
	mod_compiler_destroy(&mod_compiler)
	wasm.wasm_runtime_shutdown()
}

game_update :: proc() {
	ctx.gs.scratch = {} // auto-zero scratch for each update
	defer {
		// update at the end
		ctx.gs.game_time_elapsed += f64(ctx.delta_t)
		ctx.gs.ticks += 1
	}

	// this'll be using the last frame's camera position, but it's fine for most things
	push_coord_space(get_world_space())

	// setup world for first game tick
	if ctx.gs.ticks == 0 {
		// Entities are now spawned by the core WASM mod in mod_init
		log.info("Game initialized - entities spawned by core mod")
		
		// Find the player entity (spawned by mod)
		for &e in ctx.gs.entities {
			if !is_valid(e) do continue
			if e.wasm_script_name == "player" {
				ctx.gs.player_handle = e.handle
				log.info("Found player entity")
				break
			}
		}
	}
	
	// Hot-reload check
	{
		current_time := utils.seconds_since_init()
		changed_files := file_watcher_check(&file_watcher, current_time)
		defer {
			for file in changed_files {
				delete(file)
			}
			delete(changed_files)
		}
		
		if len(changed_files) > 0 {
			log.info("Files changed, recompiling mods...")
			recompiled := check_and_recompile(&mod_compiler, changed_files[:])
			defer {
				for mod_path in recompiled {
					delete(mod_path)
				}
				delete(recompiled)
			}
			
			// Reload the recompiled mods
			for mod_path in recompiled {
				mod_name := "core" // For now, we only have core mod
				if mod, ok := loaded_mods[mod_name]; ok {
					if wasm.reload_wasm_mod(mod) {
						log.infof("Hot-reloaded mod: %s", mod_name)
					}
				}
			}
		}
	}

	rebuild_scratch_helpers()
	
	// big :update time
	for handle in get_all_ents() {
		e := entity_from_handle(handle)

		update_entity_animation(e)

		// Call WASM entity update or native update_proc
		if e.is_wasm_entity {
			// Call the WASM mod's entity_update_by_name function
			if core_mod, ok := loaded_mods["core"]; ok {
				wasm.call_entity_update_by_name(core_mod, e.wasm_script_name, e.wasm_entity_id, ctx.delta_t)
			}
		} else if e.update_proc != nil {
			e.update_proc(e)
		}
	}

	if key_pressed(.LEFT_MOUSE) {
		consume_key_pressed(.LEFT_MOUSE)

		pos := mouse_pos_in_current_space()
		log.info("schloop at", pos)
		sound_play("event:/schloop", pos=pos)
	}

	// Save/Load system hotkeys
	if key_pressed(.F) && key_down(.LEFT_ALT) {
		consume_key_pressed(.F)
		save_game_to_disk()
		log.info("=== GAME SAVED ===")
	}

	if key_pressed(.V) && key_down(.LEFT_ALT) {
		consume_key_pressed(.V)
		clear_game_state()
		load_game_from_disk()
		log.info("=== GAME LOADED ===")
	}

	utils.animate_to_target_v2(&ctx.gs.cam_pos, get_player().pos, ctx.delta_t, rate=10)

	// ... add whatever other systems you need here to make epic game
}

rebuild_scratch_helpers :: proc() {
	// construct the list of all entities on the temp allocator
	// that way it's easier to loop over later on
	all_ents := make([dynamic]Entity_Handle, 0, len(ctx.gs.entities), allocator=context.temp_allocator)
	for &e in ctx.gs.entities {
		if !is_valid(e) do continue
		append(&all_ents, e.handle)
	}
	ctx.gs.scratch.all_entities = all_ents[:]
}

game_draw :: proc() {

	// this is so we can get the current pixel in the shader in world space (VERYYY useful)
	draw_frame.ndc_to_world_xform = get_world_space_camera() * linalg.inverse(get_world_space_proj())
	draw_frame.bg_repeat_tex0_atlas_uv = atlas_uv_from_sprite(.bg_repeat_tex0)

	// background thing
	{
		// identity matrices, so we're in clip space
		push_coord_space({proj=Matrix4(1), camera=Matrix4(1)})

		// draw rect that covers the whole screen
		draw_rect(shape.Rect{ -1, -1, 1, 1}, flags=.background_pixels) // we leave it in the hands of the shader
	}

	// world
	{
		push_coord_space(get_world_space())
		
		draw_sprite({10, 10}, .player_still, col_override=Vec4{1,0,0,0.4})
		draw_sprite({-10, 10}, .player_still)

		draw_text({0, -50}, "sugon", pivot=.bottom_center, col={0,0,0,0.1}, drop_shadow_col={})

		for handle in get_all_ents() {
			e := entity_from_handle(handle)
			e.draw_proc(e^)
		}
	}
}

// note, this needs to be in the game layer because it varies from game to game.
// Specifically, stuff like anim_index and whatnot aren't guarenteed to be named the same or actually even be on the base entity.
// (in terrafactor, it's inside a sub state struct)
draw_entity_default :: proc(e: Entity) {
	e := e // need this bc we can't take a reference from a procedure parameter directly

	if e.sprite == nil {
		return
	}

	xform := utils.xform_rotate(e.rotation)

	draw_sprite_entity(&e, e.pos, e.sprite, xform=xform, anim_index=e.anim_index, draw_offset=e.draw_offset, flip_x=e.flip_x, pivot=e.draw_pivot)
}

// helper for drawing a sprite that's based on an entity.
// useful for systems-based draw overrides, like having the concept of a hit_flash across all entities
draw_sprite_entity :: proc(
	entity: ^Entity,

	pos: Vec2,
	sprite: Sprite_Name,
	pivot:=utils.Pivot.center_center,
	flip_x:=false,
	draw_offset:=Vec2{},
	xform:=Matrix4(1),
	anim_index:=0,
	col:=color.WHITE,
	col_override:Vec4={},
	z_layer:ZLayer={},
	flags:Quad_Flags={},
	params:Vec4={},
	crop_top:f32=0.0,
	crop_left:f32=0.0,
	crop_bottom:f32=0.0,
	crop_right:f32=0.0,
	z_layer_queue:=-1,
) {

	col_override := col_override

	col_override = entity.scratch.col_override
	if entity.hit_flash.a != 0 {
		col_override.xyz = entity.hit_flash.xyz
		col_override.a = max(col_override.a, entity.hit_flash.a)
	}

	draw_sprite(pos, sprite, pivot, flip_x, draw_offset, xform, anim_index, col, col_override, z_layer, flags, params, crop_top, crop_left, crop_bottom, crop_right)
}

//
// ~ Gameplay Slop Waterline ~
//
// From here on out, it's gameplay slop time.
// Structure beyond this point just slows things down.
//
// No point trying to make things 'reusable' for future projects.
// It's trivially easy to just copy and paste when needed.
//

// shorthand for getting the player
get_player :: proc() -> ^Entity {
	return entity_from_handle(ctx.gs.player_handle)
}

entity_set_animation :: proc(e: ^Entity, sprite: Sprite_Name, frame_duration: f32, looping:=true) {
	if e.sprite != sprite {
		e.sprite = sprite
		e.loop = looping
		e.frame_duration = frame_duration
		e.anim_index = 0
		e.next_frame_end_time = 0
	}
}
update_entity_animation :: proc(e: ^Entity) {
	if e.frame_duration == 0 do return

	frame_count := get_frame_count(e.sprite)

	is_playing := true
	if !e.loop {
		is_playing = e.anim_index + 1 <= frame_count
	}

	if is_playing {
	
		if e.next_frame_end_time == 0 {
			e.next_frame_end_time = now() + f64(e.frame_duration)
		}
	
		if end_time_up(e.next_frame_end_time) {
			e.anim_index += 1
			e.next_frame_end_time = 0
			//e.did_frame_advance = true
			if e.anim_index >= frame_count {

				if e.loop {
					e.anim_index = 0
				}

			}
		}
	}
}

//
// Save / Load System
//

// Serializable game state that can be saved to disk
Game_State_Save :: struct {
	gs: Game_State,
	// TODO: WASM entity state serialization
}

save_game_to_disk :: proc() {
	utils.make_directory_if_not_exist("worlds")
	
	log.info("Saving game state...")
	
	// Create save data structure using temporary allocator to avoid stack overflow
	save_data := new(Game_State_Save, context.temp_allocator)
	
	save_data.gs = ctx.gs^
	
	// TODO: Extract WASM entity data
	// For now, entities will respawn from mod_init on load
	
	// Serialize to CBOR using temp allocator
	cbor_data, marshal_err := cbor.marshal_into_bytes(save_data^, cbor.ENCODE_FULLY_DETERMINISTIC, context.temp_allocator)
	if marshal_err != nil {
		log.errorf("Failed to marshal game state: %v", marshal_err)
		return
	}
	
	// Write to disk
	write_ok := os.write_entire_file("worlds/save.cbor", cbor_data)
	if !write_ok {
		log.error("Failed to write save file")
		return
	}
	
	log.infof("Game saved successfully (%d bytes)", len(cbor_data))
}

load_game_from_disk :: proc() {
	log.info("Loading game state...")
	
	// Read from disk using temp allocator (file data is temporary)
	file_data, read_ok := os.read_entire_file("worlds/save.cbor", context.temp_allocator)
	if !read_ok {
		log.error("Failed to read save file")
		return
	}
	
	// Deserialize from CBOR - use temp allocator for the save_data wrapper
	// but CBOR will use the default allocator for nested structures
	save_data := new(Game_State_Save, context.temp_allocator)
	
	unmarshal_err := cbor.unmarshal(file_data, save_data)
	if unmarshal_err != nil {
		log.errorf("Failed to unmarshal game state: %v", unmarshal_err)
		return
	}
	// Note: save_data itself uses temp allocator, but nested allocations
	// (like entity_free_list in Game_State) use the default allocator and persist
	
	// Restore game state
	ctx.gs^ = save_data.gs
	
	// TODO: Restore WASM entity data
	// For now, just setup function pointers
	for &e in ctx.gs.entities {
		if !is_valid(e) do continue
		entity_setup(&e)
	}
	
	log.info("Game loaded successfully")
}

clear_game_state :: proc() {
	log.info("Clearing game state...")
	
	// Destroy all entities
	for &e in ctx.gs.entities {
		if !is_valid(e) do continue
		entity_destroy(&e)
	}
	
	// Reset the game state
	ctx.gs^ = {}
	
	log.info("Game state cleared")
}

// Helper to call WASM entity update
wasm_call_entity_update :: proc(e: ^Entity) {
	if !e.is_wasm_entity do return
	
	// Call the core mod's entity_update_by_name function
	if core_mod, ok := loaded_mods["core"]; ok {
		wasm.call_entity_update_by_name(core_mod, e.wasm_script_name, e.wasm_entity_id, ctx.delta_t)
	}
}

// Initialize WASM runtime
wasm_runtime_init :: proc() -> bool {
	loaded_mods = make(map[string]^wasm.Wasm_Mod)
	return wasm.wasm_runtime_init()
}