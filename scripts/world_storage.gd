class_name WorldStorage
extends Node
## Compact binary persistence for world metadata, player state and chunk edits.
## A mutex protects disk access because chunks load on worker threads.

@export var world_directory: String = "user://worlds/default"
@export var world_seed: int = 1337

const WORLD_MAGIC := 0x43505744
const CHUNK_MAGIC := 0x43504348
const FORMAT_VERSION := 1
const WORLD_FILE := "world.bin"
const CHUNK_HEADER_SIZE := 10
const CHUNK_ENTRY_SIZE := 3

var _mutex := Mutex.new()
var _has_player_data := false
var _player_id := 0
var _player_position := Vector3(0.0, 30.0, 0.0)
var _player_rotation := Vector3.ZERO
var _head_pitch := 0.0
var _has_sky_data := false
var _time_of_day := 0.0

func configure(directory: String, seed: int) -> void:
	world_directory = directory
	world_seed = seed
	_ensure_directory()
	_mutex.lock()
	if FileAccess.file_exists(_path(WORLD_FILE)):
		_read_world_unlocked()
	else:
		_write_world_unlocked()
	_mutex.unlock()

func _path(file_name: String) -> String:
	return world_directory.path_join(file_name)

func _ensure_directory() -> void:
	var error := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(world_directory))
	if error != OK:
		push_error("Could not create world save directory: " + world_directory)

func _replace_file_unlocked(temporary_path: String, target_path: String) -> bool:
	var absolute_temp := ProjectSettings.globalize_path(temporary_path)
	var absolute_target := ProjectSettings.globalize_path(target_path)
	if FileAccess.file_exists(target_path):
		var remove_error := DirAccess.remove_absolute(absolute_target)
		if remove_error != OK:
			push_error("Could not replace world save: " + target_path)
			return false
	var rename_error := DirAccess.rename_absolute(absolute_temp, absolute_target)
	if rename_error != OK:
		push_error("Could not finalize world save: " + target_path)
		return false
	return true

func _read_world_unlocked() -> void:
	var file := FileAccess.open(_path(WORLD_FILE), FileAccess.READ)
	if file == null:
		push_error("Could not read binary world save.")
		return
	if file.get_length() < 15:
		push_error("World save is too short or corrupted.")
		return
	if file.get_32() != WORLD_MAGIC:
		push_error("World save has an invalid header.")
		return
	var version := file.get_16()
	if version != FORMAT_VERSION:
		push_error("Unsupported world save version: %d" % version)
		return
	var saved_seed := file.get_64()
	if saved_seed != world_seed:
		push_error("World save seed does not match the selected world.")
		return
	_has_player_data = file.get_8() == 1
	if _has_player_data:
		_player_id = file.get_32()
		_player_position = Vector3(file.get_float(), file.get_float(), file.get_float())
		_player_rotation = Vector3(file.get_float(), file.get_float(), file.get_float())
		_head_pitch = file.get_float()
	_has_sky_data = file.get_8() == 1
	if _has_sky_data:
		_time_of_day = file.get_float()
	if file.get_error() != OK:
		push_error("Could not fully read binary world save.")

func _write_world_unlocked() -> bool:
	_ensure_directory()
	var temporary_path := _path(WORLD_FILE + ".tmp")
	var file := FileAccess.open(temporary_path, FileAccess.WRITE)
	if file == null:
		push_error("Could not write world save: " + temporary_path)
		return false
	file.store_32(WORLD_MAGIC)
	file.store_16(FORMAT_VERSION)
	file.store_64(world_seed)
	file.store_8(1 if _has_player_data else 0)
	if _has_player_data:
		file.store_32(_player_id)
		file.store_float(_player_position.x)
		file.store_float(_player_position.y)
		file.store_float(_player_position.z)
		file.store_float(_player_rotation.x)
		file.store_float(_player_rotation.y)
		file.store_float(_player_rotation.z)
		file.store_float(_head_pitch)
	file.store_8(1 if _has_sky_data else 0)
	if _has_sky_data:
		file.store_float(_time_of_day)
	file.flush()
	file.close()
	return _replace_file_unlocked(temporary_path, _path(WORLD_FILE))

func _chunk_file(chunk: Vector3i) -> String:
	return "chunk_%d_%d_%d.bin" % [chunk.x, chunk.y, chunk.z]

func get_blocks(chunk: Vector3i) -> Array:
	_mutex.lock()
	var path := _path(_chunk_file(chunk))
	var result: Array = []
	if not FileAccess.file_exists(path):
		_mutex.unlock()
		return result
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Could not read chunk save: " + path)
		_mutex.unlock()
		return result
	if file.get_length() < CHUNK_HEADER_SIZE or file.get_32() != CHUNK_MAGIC:
		push_error("Invalid chunk save header: " + path)
		_mutex.unlock()
		return result
	var version := file.get_16()
	var count := file.get_32()
	if version != FORMAT_VERSION or count > Chunk.WIDTH * Chunk.HEIGHT * Chunk.WIDTH:
		push_error("Unsupported or invalid chunk save: " + path)
		_mutex.unlock()
		return result
	if file.get_length() < CHUNK_HEADER_SIZE + count * CHUNK_ENTRY_SIZE:
		push_error("Chunk save is truncated: " + path)
		_mutex.unlock()
		return result
	for _i in range(count):
		var local_index := int(file.get_16())
		var block_type := int(file.get_8())
		if local_index >= Chunk.WIDTH * Chunk.HEIGHT * Chunk.WIDTH or block_type > Block.Type.EMPTY:
			continue
		var x := local_index % Chunk.WIDTH
		var z := (local_index / Chunk.WIDTH) % Chunk.WIDTH
		var y := local_index / (Chunk.WIDTH * Chunk.WIDTH)
		result.append({
			"block_x": x,
			"block_y": y,
			"block_z": z,
			"type": block_type
		})
	_mutex.unlock()
	return result

func set_block(chunk: Vector3i, block: Vector3i, type: Block.Type) -> void:
	_mutex.lock()
	var path := _path(_chunk_file(chunk))
	var saved_blocks: Dictionary = {}
	if FileAccess.file_exists(path):
		var existing := FileAccess.open(path, FileAccess.READ)
		if existing != null and existing.get_length() >= CHUNK_HEADER_SIZE and existing.get_32() == CHUNK_MAGIC:
			var version := existing.get_16()
			var count := existing.get_32()
			if version == FORMAT_VERSION and count <= Chunk.WIDTH * Chunk.HEIGHT * Chunk.WIDTH and existing.get_length() >= CHUNK_HEADER_SIZE + count * CHUNK_ENTRY_SIZE:
				for _i in range(count):
					var local_index := int(existing.get_16())
					var block_type := int(existing.get_8())
					if local_index < Chunk.WIDTH * Chunk.HEIGHT * Chunk.WIDTH and block_type <= Block.Type.EMPTY:
						saved_blocks[local_index] = block_type
	var local_index := block.y * Chunk.WIDTH * Chunk.WIDTH + block.z * Chunk.WIDTH + block.x
	saved_blocks[local_index] = int(type)
	var temporary_path := path + ".tmp"
	var file := FileAccess.open(temporary_path, FileAccess.WRITE)
	if file == null:
		push_error("Could not write chunk save: " + temporary_path)
		_mutex.unlock()
		return
	file.store_32(CHUNK_MAGIC)
	file.store_16(FORMAT_VERSION)
	file.store_32(saved_blocks.size())
	for index in saved_blocks:
		file.store_16(int(index))
		file.store_8(int(saved_blocks[index]))
	file.flush()
	file.close()
	_replace_file_unlocked(temporary_path, path)
	_mutex.unlock()

func load_player(player: Player, id: int = 0) -> void:
	_mutex.lock()
	if _has_player_data and _player_id == id:
		player.position = _player_position
		player.rotation = _player_rotation
		player.get_node("Head").rotation.x = _head_pitch
	_mutex.unlock()

func load_sky(sky: GDCraftSky) -> void:
	_mutex.lock()
	if _has_sky_data:
		sky.time_of_day = _time_of_day
	_mutex.unlock()

func save_session(player: Player, sky: GDCraftSky, id: int = 0) -> void:
	_mutex.lock()
	_player_id = id
	_player_position = player.position
	_player_rotation = player.rotation
	_head_pitch = player.get_node("Head").rotation.x
	_has_player_data = true
	_time_of_day = sky.time_of_day
	_has_sky_data = true
	_write_world_unlocked()
	_mutex.unlock()
