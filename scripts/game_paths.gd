extends Node
## Resolves writable game-data folders for desktop and Android.
## Settings intentionally remain in Godot's internal user:// directory.

const GAME_FOLDER_NAME := "Games/CrepCraft"
const LEGACY_WORLDS := "user://worlds"
const LEGACY_RESOURCE_PACKS := "user://resource_packs"

var _game_directory := ""

func _ready() -> void:
	_game_directory = _resolve_game_directory()
	_make_directory(_game_directory)
	_make_directory(get_worlds_directory())
	_make_directory(get_resource_packs_directory())
	_migrate_legacy_directory(LEGACY_WORLDS, get_worlds_directory())
	_migrate_legacy_directory(LEGACY_RESOURCE_PACKS, get_resource_packs_directory())

func _resolve_game_directory() -> String:
	if OS.has_feature("android"):
		if Engine.has_singleton("CrepCraftStorage"):
			var android_storage = Engine.get_singleton("CrepCraftStorage")
			var external_files_dir := str(android_storage.getExternalFilesDir())
			if not external_files_dir.is_empty():
				return external_files_dir.path_join(GAME_FOLDER_NAME)
			push_warning("Android external files directory is unavailable; using internal storage.")
		else:
			push_warning("CrepCraftStorage Android plugin is unavailable; using internal storage.")
		return "user://Games/CrepCraft"

	if OS.has_feature("editor"):
		return ProjectSettings.globalize_path("res://").path_join(GAME_FOLDER_NAME)

	return OS.get_executable_path().get_base_dir().path_join(GAME_FOLDER_NAME)

func get_game_directory() -> String:
	return _game_directory

func get_worlds_directory() -> String:
	return _game_directory.path_join("worlds")

func get_resource_packs_directory() -> String:
	return _game_directory.path_join("resource_packs")

func _make_directory(path: String) -> void:
	var absolute_path := ProjectSettings.globalize_path(path)
	var error := DirAccess.make_dir_recursive_absolute(absolute_path)
	if error != OK and error != ERR_ALREADY_EXISTS:
		push_error("Could not create game data directory: " + absolute_path)

func _migrate_legacy_directory(source: String, destination: String) -> void:
	var source_absolute := ProjectSettings.globalize_path(source)
	var destination_absolute := ProjectSettings.globalize_path(destination)
	if not DirAccess.dir_exists_absolute(source_absolute):
		return
	if _directory_has_entries(destination_absolute):
		return
	_copy_directory_contents(source_absolute, destination_absolute)

func _directory_has_entries(path: String) -> bool:
	if not DirAccess.dir_exists_absolute(path):
		return false
	var dir := DirAccess.open(path)
	if dir == null:
		return false
	dir.list_dir_begin()
	var entry := dir.get_next()
	while not entry.is_empty():
		if entry != "." and entry != "..":
			dir.list_dir_end()
			return true
		entry = dir.get_next()
	dir.list_dir_end()
	return false

func _copy_directory_contents(source: String, destination: String) -> void:
	_make_directory(destination)
	var dir := DirAccess.open(source)
	if dir == null:
		push_warning("Could not open legacy data directory: " + source)
		return
	dir.list_dir_begin()
	var entry := dir.get_next()
	while not entry.is_empty():
		if entry != "." and entry != "..":
			var source_path := source.path_join(entry)
			var destination_path := destination.path_join(entry)
			if dir.current_is_dir():
				_copy_directory_contents(source_path, destination_path)
			elif not FileAccess.file_exists(destination_path):
				var bytes := FileAccess.get_file_as_bytes(source_path)
				var output := FileAccess.open(destination_path, FileAccess.WRITE)
				if output != null:
					output.store_buffer(bytes)
					output.flush()
					output.close()
				else:
					push_warning("Could not migrate legacy file: " + source_path)
		entry = dir.get_next()
	dir.list_dir_end()
