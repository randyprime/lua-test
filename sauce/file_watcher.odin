package main

import "core:os"
import "core:log"
import "core:strings"
import "core:path/filepath"
import "core:time"

/*

File Watcher

Monitors directories for file changes to support hot-reload.
Checks file modification times periodically.

*/

Watched_File :: struct {
	path: string,
	last_modified: time.Time,
}

File_Watcher :: struct {
	watched_files: map[string]Watched_File,
	watch_directories: [dynamic]string,
	file_extension: string, // e.g., ".odin"
	check_interval: f64, // seconds
	last_check_time: f64,
}

// Create a new file watcher
file_watcher_create :: proc(extension: string, check_interval: f64 = 1.0) -> File_Watcher {
	return File_Watcher{
		watched_files = make(map[string]Watched_File),
		watch_directories = make([dynamic]string),
		file_extension = extension,
		check_interval = check_interval,
		last_check_time = 0,
	}
}

// Destroy file watcher and free memory
file_watcher_destroy :: proc(watcher: ^File_Watcher) {
	for key, file in watcher.watched_files {
		delete(file.path)
		delete(key)
	}
	delete(watcher.watched_files)
	
	for dir in watcher.watch_directories {
		delete(dir)
	}
	delete(watcher.watch_directories)
}

// Add a directory to watch (recursively scans for matching files)
file_watcher_add_directory :: proc(watcher: ^File_Watcher, directory: string) {
	dir_clone := strings.clone(directory)
	append(&watcher.watch_directories, dir_clone)
	
	// Scan and add all matching files
	scan_directory_for_files(watcher, directory)
	
	log.infof("File watcher: Added directory '%s'", directory)
}

// Recursively scan a directory for files matching the extension
scan_directory_for_files :: proc(watcher: ^File_Watcher, directory: string) {
	dir_handle, open_err := os.open(directory)
	if open_err != 0 {
		log.warnf("File watcher: Failed to open directory '%s'", directory)
		return
	}
	defer os.close(dir_handle)
	
	file_infos, read_err := os.read_dir(dir_handle, -1)
	if read_err != 0 {
		log.warnf("File watcher: Failed to read directory '%s'", directory)
		return
	}
	defer os.file_info_slice_delete(file_infos)
	
	for file_info in file_infos {
		full_path := filepath.join({directory, file_info.name})
		defer delete(full_path)
		
		if file_info.is_dir {
			// Recursively scan subdirectories
			scan_directory_for_files(watcher, full_path)
		} else {
			// Check if file matches extension
			ext := filepath.ext(file_info.name)
			if ext == watcher.file_extension {
				add_watched_file(watcher, full_path)
			}
		}
	}
}

// Add a specific file to watch
add_watched_file :: proc(watcher: ^File_Watcher, file_path: string) {
	// Get initial modification time
	file_info, stat_err := os.stat(file_path)
	if stat_err != 0 {
		log.warnf("File watcher: Failed to stat file '%s'", file_path)
		return
	}
	
	path_clone := strings.clone(file_path)
	watched_file := Watched_File{
		path = path_clone,
		last_modified = file_info.modification_time,
	}
	
	watcher.watched_files[path_clone] = watched_file
}

// Check for file changes, returns list of changed files
file_watcher_check :: proc(watcher: ^File_Watcher, current_time: f64) -> [dynamic]string {
	changed_files := make([dynamic]string, 0, context.temp_allocator)
	
	// Only check at intervals
	if current_time - watcher.last_check_time < watcher.check_interval {
		return changed_files
	}
	watcher.last_check_time = current_time
	
	// Check each watched file
	for key, &file in watcher.watched_files {
		file_info, stat_err := os.stat(file.path)
		if stat_err != 0 {
			// File may have been deleted
			continue
		}
		
		if file_info.modification_time != file.last_modified {
			// File changed!
			log.infof("File watcher: Detected change in '%s'", file.path)
			append(&changed_files, strings.clone(file.path))
			file.last_modified = file_info.modification_time
		}
	}
	
	return changed_files
}

// Rescan all watched directories (useful if files were added/removed)
file_watcher_rescan :: proc(watcher: ^File_Watcher) {
	// Clear current watched files
	for key, file in watcher.watched_files {
		delete(file.path)
		delete(key)
	}
	clear(&watcher.watched_files)
	
	// Rescan all directories
	for dir in watcher.watch_directories {
		scan_directory_for_files(watcher, dir)
	}
	
	log.info("File watcher: Rescanned all directories")
}

