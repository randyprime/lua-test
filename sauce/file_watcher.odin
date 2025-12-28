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

file_watcher: File_Watcher = {
	file_extension = ".odin",
	check_interval = 1.0,
}

// Add a directory to watch (recursively scans for matching files)
file_watcher_add_directory :: proc(directory: string) {
	append(&file_watcher.watch_directories, directory)

	// Scan and add all matching files
	scan_directory_for_files(directory)

	log.infof("File watcher: Added directory '%s'", directory)
}

// Recursively scan a directory for files matching the extension
scan_directory_for_files :: proc(directory: string) {
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

		if file_info.is_dir {
			// Recursively scan subdirectories
			scan_directory_for_files(full_path)
		} else {
			// Check if file matches extension
			ext := filepath.ext(file_info.name)
			if ext == file_watcher.file_extension {
				add_watched_file(full_path)
			}
		}
	}
}

// Add a specific file to watch
add_watched_file :: proc(file_path: string) {
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

	file_watcher.watched_files[path_clone] = watched_file
}

// Check for file changes, returns list of changed files
file_watcher_check :: proc(current_time: f64) -> [dynamic]string {
	changed_files := make([dynamic]string, 0, context.temp_allocator)

	// Only check at intervals
	if current_time - file_watcher.last_check_time < file_watcher.check_interval {
		return changed_files
	}
	file_watcher.last_check_time = current_time

	// Check each watched file
	for key, &file in file_watcher.watched_files {
		file_info, stat_err := os.stat(file.path)
		if stat_err != 0 {
			// File may have been deleted
			continue
		}

		if file_info.modification_time != file.last_modified {
			// File changed!
			log.infof("File watcher: Detected change in '%s'", file.path)
			append(&changed_files, file.path)
			file.last_modified = file_info.modification_time
		}
	}

	return changed_files
}

// Rescan all watched directories (useful if files were added/removed)
file_watcher_rescan :: proc() {
	// Clear current watched files
	clear(&file_watcher.watched_files)

	// Rescan all directories
	for dir in file_watcher.watch_directories {
		scan_directory_for_files(dir)
	}

	log.info("File watcher: Rescanned all directories")
}

// DLL watching for external builds (no recompile needed)
dll_watched_files: map[string]Watched_File

file_watcher_add_dll :: proc(dll_path: string) {
	file_info, stat_err := os.stat(dll_path)
	if stat_err != 0 {
		log.warnf("File watcher: Failed to stat DLL '%s'", dll_path)
		return
	}

	path_clone := strings.clone(dll_path)
	dll_watched_files[path_clone] = Watched_File{
		path = path_clone,
		last_modified = file_info.modification_time,
	}

	log.infof("File watcher: Watching DLL '%s'", dll_path)
}

// Check if any watched DLL has changed, returns true if so (and updates timestamp)
file_watcher_dll_changed :: proc() -> bool {
	changed := false

	for key, &file in dll_watched_files {
		file_info, stat_err := os.stat(file.path)
		if stat_err != 0 {
			continue
		}

		if file_info.modification_time != file.last_modified {
			log.infof("File watcher: DLL changed '%s'", file.path)
			file.last_modified = file_info.modification_time
			changed = true
		}
	}

	return changed
}

