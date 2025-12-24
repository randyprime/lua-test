package string_store

// use a string to store data immediately.
// very useful for ooga booga gameplay code and just haphazardly storing something in a string
// will auto delete the memory when it's no longer called every frame

import "core:log"

Store :: struct {
	initialized: bool,
	table: map[string]Entry,
}

Entry :: struct {
	last_tick: u64,
	
	//
	// big sloppie storage dump

	user_ptr: rawptr, // todo, move everything into here instead? that way we handle all the specifics inline at the callsite
	
	next_run_time: f64,
	is_active: bool,
	
	state: enum { nil, fade_in, hold, fade_out },
	alpha: f32,
	alpha_target: f32,
	end_time: f64,
	
	scratch: struct {
		hit_this_frame: bool,
	}
}

init_first_time :: proc(store: ^Store) {
	if store.initialized {
		return
	}
	store.table = make(map[string]Entry, 1024, allocator=context.allocator)
	store.initialized = true
}

stash :: proc(store: ^Store, hash: string, tick_count: u64) -> (entry: ^Entry, first_time: bool) #optional_ok {
	init_first_time(store)
	
	found: bool
	entry, found = &store.table[hash]
	if !found {
		// insert new entry
		store.table[hash] = {}
		entry, _ = &store.table[hash]
		first_time = true
	}
	entry.last_tick = tick_count
	return
}

// call this at the end of every frame
clear_store :: proc(store: ^Store, tick_count: u64) {
	init_first_time(store)
	
	for key, &value in store.table {
		// reset frame
		value.scratch = {}
		
		// clear out stale guys
		if value.last_tick < tick_count {
			delete_key(&store.table, key)
		}
	}
}