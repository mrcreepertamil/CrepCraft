class_name WorldStorage
extends Node
## JSON-based per-world persistence. All disk access is protected because
## chunk generation reads saved block overrides from worker threads.

@export var world_directory: String = "user://worlds/default"
@export var world_seed: int = 1337

var _mutex := Mutex.new()
var _format_version := 1

func configure(directory: String, seed: int) -> void:
	world_directory = directory
	world_seed = seed
	_ensure_directory()
	_mutex.lock()
	var metadata_path := _path("world.json")
	if not FileAccess.file_exists(metadata_path):
		_write_json_unlocked(metadata_path, {
			"format_version": _format_version,
			"seed": world_seed,
			"created_at": Time.get_datetime_string_from_system()
		})
	_mutex.unlock()

func _path(file_name: String) -> String:
	return world_directory.path_join(file_name)

func _ensure_directory() -> void:
	var absolute_path := ProjectSettings.globalize_path(world_directory)
	var error := DirAccess.make_dir_recursive_absolute(absolute_path)
	if error != OK:
		push_error("Could not create world save directory: " + world_directory)

func _read_json_unlocked(path: String, fallback: Variant) -> Variant:
	if not FileAccess.file_exists(path):
		return fallback
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Could not read world save: " + path)
		return fallback
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if parsed == null:
		push_error("Invalid JSON world save: " + path)
		return fallback
	return parsed

func _write_json_unlocked(path: String, data: Variant) -> bool:
	_ensure_directory()
	var temporary_path := path + ".tmp"
	var file := FileAccess.open(temporary_path, FileAccess.WRITE)
	if file == null:
		push_error("Could not write world save: " + temporary_path)
		return false
	file.store_string(JSON.stringify(data))
	file.flush()
	file.close()
	var absolute_temp := ProjectSettings.globalize_path(temporary_path)
	var absolute_target := ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(path):
		var remove_error := DirAccess.remove_absolute(absolute_target)
		if remove_error != OK:
			push_error("Could not replace world save: " + path)
			return false
	var rename_error := DirAccess.rename_absolute(absolute_temp, absolute_target)
	if rename_error != OK:
		push_error("Could not finalize world save: " + path)
		return false
	return true

func _chunk_file(chunk: Vector3i) -> String:
	return "chunk_%d_%d_%d.json" % [chunk.x, chunk.y, chunk.z]

func _block_key(block: Vector3i) -> String:
	return "%d_%d_%d" % [block.x, block.y, block.z]

func get_blocks(chunk: Vector3i) -> Array:
	_mutex.lock()
	var data: Variant = _read_json_unlocked(_path(_chunk_file(chunk)), {})
	var saved_blocks: Variant = data.get("blocks", {}) if data is Dictionary else {}
	var result: Array = []
	if saved_blocks is Dictionary:
		for key in saved_blocks:
			var coordinates := str(key).split("_")
			if coordinates.size() != 3:
				continue
			var block_type := int(saved_blocks[key])
			if block_type == Block.Type.EMPTY:
				continue
			result.append({
				"block_x": int(coordinates[0]),
				"block_y": int(coordinates[1]),
				"block_z": int(coordinates[2]),
				"type": block_type
			})
	_mutex.unlock()
	return result

func set_block(chunk: Vector3i, block: Vector3i, type: Block.Type) -> void:
	_mutex.lock()
	var path := _path(_chunk_file(chunk))
	var data: Variant = _read_json_unlocked(path, {})
	if not data is Dictionary:
		data = {}
	var saved_blocks: Dictionary = data.get("blocks", {})
	var key := _block_key(block)
	if type == Block.Type.EMPTY:
		saved_blocks.erase(key)
	else:
		saved_blocks[key] = int(type)
	data["format_version"] = _format_version
	data["blocks"] = saved_blocks
	_write_json_unlocked(path, data)
	_mutex.unlock()

func save_player(player: Player, id: int = 0) -> void:
	_mutex.lock()
	_write_json_unlocked(_path("player.json"), {
		"format_version": _format_version,
		"id": id,
		"position": [player.position.x, player.position.y, player.position.z],
		"rotation": [player.rotation.x, player.rotation.y, player.rotation.z]
	})
	_mutex.unlock()

func load_player(player: Player, id: int = 0) -> void:
	_mutex.lock()
	var data: Variant = _read_json_unlocked(_path("player.json"), {})
	if data is Dictionary and int(data.get("id", id)) == id:
		var position: Variant = data.get("position", [])
		var rotation: Variant = data.get("rotation", [])
		if position is Array and position.size() == 3:
			player.position = Vector3(float(position[0]), float(position[1]), float(position[2]))
		if rotation is Array and rotation.size() == 3:
			player.rotation = Vector3(float(rotation[0]), float(rotation[1]), float(rotation[2]))
	_mutex.unlock()

func save_sky(sky: GDCraftSky) -> void:
	_mutex.lock()
	_write_json_unlocked(_path("environment.json"), {
		"format_version": _format_version,
		"time_of_day": sky.time_of_day
	})
	_mutex.unlock()

func load_sky(sky: GDCraftSky) -> void:
	_mutex.lock()
	var data: Variant = _read_json_unlocked(_path("environment.json"), {})
	if data is Dictionary and data.has("time_of_day"):
		sky.time_of_day = float(data["time_of_day"])
	_mutex.unlock()
