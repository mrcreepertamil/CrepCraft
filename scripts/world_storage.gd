class_name WorldStorage
extends Node
## CrepCraft's versioned, Minecraft-inspired binary world format.
## level.dat stores world metadata, region files store chunks, and playerdata stores players.

@export var world_directory: String = "user://worlds/default"
@export var world_seed: int = 1337

const LEVEL_MAGIC := 0x43504C56
const PLAYER_MAGIC := 0x43505044
const REGION_MAGIC := 0x43505247
const FORMAT_VERSION := 1
const LEVEL_FILE := "level.dat"
const PLAYER_DIRECTORY := "playerdata"
const REGION_DIRECTORY := "region"
const REGION_SIZE := 32
const REGION_HEADER_SIZE := 8
const REGION_CHUNK_HEADER_SIZE := 6
const BLOCK_ENTRY_SIZE := 3

var _mutex := Mutex.new()
var _has_sky_data := false
var _time_of_day := 0.0

func configure(directory: String, seed: int) -> void:
	world_directory = directory
	world_seed = seed
	_ensure_directories()
	_mutex.lock()
	if FileAccess.file_exists(_path(LEVEL_FILE)):
		_read_level_unlocked()
	else:
		_write_level_unlocked()
	_mutex.unlock()

func _path(file_name: String) -> String:
	return world_directory.path_join(file_name)

func _region_path(region_x: int, region_z: int) -> String:
	return _path(REGION_DIRECTORY).path_join("r.%d.%d.ccr" % [region_x, region_z])

func _player_path(player_id: int) -> String:
	return _path(PLAYER_DIRECTORY).path_join("%d.dat" % player_id)

func _ensure_directories() -> void:
	for directory in [world_directory, _path(REGION_DIRECTORY), _path(PLAYER_DIRECTORY)]:
		var error := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
		if error != OK:
			push_error("Could not create world save directory: " + directory)

func _replace_file_unlocked(temporary_path: String, target_path: String) -> bool:
	var absolute_temp := ProjectSettings.globalize_path(temporary_path)
	var absolute_target := ProjectSettings.globalize_path(target_path)
	if FileAccess.file_exists(target_path):
		var remove_error := DirAccess.remove_absolute(absolute_target)
		if remove_error != OK:
			push_error("Could not replace save file: " + target_path)
			return false
	var rename_error := DirAccess.rename_absolute(absolute_temp, absolute_target)
	if rename_error != OK:
		push_error("Could not finalize save file: " + target_path)
		return false
	return true

func _read_level_unlocked() -> void:
	var file := FileAccess.open(_path(LEVEL_FILE), FileAccess.READ)
	if file == null:
		push_error("Could not read level.dat.")
		return
	if file.get_length() < 15 or file.get_32() != LEVEL_MAGIC:
		push_error("level.dat has an invalid or truncated header.")
		file.close()
		return
	var version := file.get_16()
	var saved_seed := file.get_64()
	_has_sky_data = file.get_8() == 1
	if _has_sky_data:
		_time_of_day = file.get_float()
	file.close()
	if version != FORMAT_VERSION:
		push_error("Unsupported level.dat version: %d" % version)
	elif saved_seed != world_seed:
		push_error("level.dat seed does not match the selected world.")

func _write_level_unlocked() -> bool:
	var temporary_path := _path(LEVEL_FILE + ".tmp")
	var file := FileAccess.open(temporary_path, FileAccess.WRITE)
	if file == null:
		push_error("Could not write level.dat.")
		return false
	file.store_32(LEVEL_MAGIC)
	file.store_16(FORMAT_VERSION)
	file.store_64(world_seed)
	file.store_8(1 if _has_sky_data else 0)
	if _has_sky_data:
		file.store_float(_time_of_day)
	file.flush()
	file.close()
	return _replace_file_unlocked(temporary_path, _path(LEVEL_FILE))

func _read_region_unlocked(region_x: int, region_z: int) -> Dictionary:
	var chunks: Dictionary = {}
	var path := _region_path(region_x, region_z)
	if not FileAccess.file_exists(path):
		return chunks
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Could not read region file: " + path)
		return chunks
	if file.get_length() < REGION_HEADER_SIZE or file.get_32() != REGION_MAGIC:
		push_error("Invalid region file header: " + path)
		file.close()
		return chunks
	var version := file.get_16()
	var chunk_count := int(file.get_16())
	if version != FORMAT_VERSION or chunk_count > REGION_SIZE * REGION_SIZE:
		push_error("Unsupported or invalid region file: " + path)
		file.close()
		return chunks
	for _chunk_index in range(chunk_count):
		if file.get_position() + REGION_CHUNK_HEADER_SIZE > file.get_length():
			push_error("Truncated region file: " + path)
			break
		var local_x := int(file.get_8())
		var local_z := int(file.get_8())
		var block_count := int(file.get_32())
		if local_x >= REGION_SIZE or local_z >= REGION_SIZE or block_count > Chunk.WIDTH * Chunk.HEIGHT * Chunk.WIDTH:
			push_error("Invalid chunk entry in region: " + path)
			break
		if file.get_position() + block_count * BLOCK_ENTRY_SIZE > file.get_length():
			push_error("Truncated chunk data in region: " + path)
			break
		var blocks: Dictionary = {}
		for _block_index in range(block_count):
			var local_index := int(file.get_16())
			var block_type := int(file.get_8())
			if local_index < Chunk.WIDTH * Chunk.HEIGHT * Chunk.WIDTH and block_type <= Block.Type.EMPTY:
				blocks[local_index] = block_type
		chunks[local_z * REGION_SIZE + local_x] = blocks
	file.close()
	return chunks

func _write_region_unlocked(region_x: int, region_z: int, chunks: Dictionary) -> bool:
	var path := _region_path(region_x, region_z)
	var temporary_path := path + ".tmp"
	var file := FileAccess.open(temporary_path, FileAccess.WRITE)
	if file == null:
		push_error("Could not write region file: " + temporary_path)
		return false
	file.store_32(REGION_MAGIC)
	file.store_16(FORMAT_VERSION)
	file.store_16(chunks.size())
	for chunk_key in chunks:
		var local_x := int(chunk_key) % REGION_SIZE
		var local_z := int(chunk_key) / REGION_SIZE
		var blocks: Dictionary = chunks[chunk_key]
		file.store_8(local_x)
		file.store_8(local_z)
		file.store_32(blocks.size())
		for local_index in blocks:
			file.store_16(int(local_index))
			file.store_8(int(blocks[local_index]))
	file.flush()
	file.close()
	return _replace_file_unlocked(temporary_path, path)

func _get_region_coordinates(chunk: Vector3i) -> Vector2i:
	return Vector2i(floori(float(chunk.x) / REGION_SIZE), floori(float(chunk.z) / REGION_SIZE))

func _get_region_key(chunk: Vector3i) -> int:
	var local_x := posmod(chunk.x, REGION_SIZE)
	var local_z := posmod(chunk.z, REGION_SIZE)
	return local_z * REGION_SIZE + local_x

func get_blocks(chunk: Vector3i) -> Array:
	_mutex.lock()
	var region := _get_region_coordinates(chunk)
	var chunks := _read_region_unlocked(region.x, region.y)
	var saved_blocks: Dictionary = chunks.get(_get_region_key(chunk), {})
	var result: Array = []
	for local_index in saved_blocks:
		var index := int(local_index)
		result.append({
			"block_x": index % Chunk.WIDTH,
			"block_y": index / (Chunk.WIDTH * Chunk.WIDTH),
			"block_z": (index / Chunk.WIDTH) % Chunk.WIDTH,
			"type": int(saved_blocks[local_index])
		})
	_mutex.unlock()
	return result

func set_block(chunk: Vector3i, block: Vector3i, type: Block.Type) -> void:
	_mutex.lock()
	var region := _get_region_coordinates(chunk)
	var chunks := _read_region_unlocked(region.x, region.y)
	var region_key := _get_region_key(chunk)
	var saved_blocks: Dictionary = chunks.get(region_key, {})
	var local_index := block.y * Chunk.WIDTH * Chunk.WIDTH + block.z * Chunk.WIDTH + block.x
	# EMPTY is deliberately stored: it overrides a generated block on reload.
	saved_blocks[local_index] = int(type)
	chunks[region_key] = saved_blocks
	_write_region_unlocked(region.x, region.y, chunks)
	_mutex.unlock()

func load_player(player: Player, id: int = 0) -> void:
	_mutex.lock()
	var path := _player_path(id)
	if not FileAccess.file_exists(path):
		_mutex.unlock()
		return
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Could not read player data: " + path)
		_mutex.unlock()
		return
	if file.get_length() < 38 or file.get_32() != PLAYER_MAGIC:
		push_error("Invalid player data file: " + path)
		file.close()
		_mutex.unlock()
		return
	var version := file.get_16()
	var saved_id := file.get_32()
	if version == FORMAT_VERSION and saved_id == id:
		player.position = Vector3(file.get_float(), file.get_float(), file.get_float())
		player.rotation = Vector3(file.get_float(), file.get_float(), file.get_float())
		player.get_node("Head").rotation.x = file.get_float()
	file.close()
	_mutex.unlock()

func load_sky(sky: GDCraftSky) -> void:
	_mutex.lock()
	if _has_sky_data:
		sky.time_of_day = _time_of_day
	_mutex.unlock()

func save_session(player: Player, sky: GDCraftSky, id: int = 0) -> void:
	_mutex.lock()
	_time_of_day = sky.time_of_day
	_has_sky_data = true
	_write_level_unlocked()
	var path := _player_path(id)
	var temporary_path := path + ".tmp"
	var file := FileAccess.open(temporary_path, FileAccess.WRITE)
	if file == null:
		push_error("Could not write player data: " + temporary_path)
		_mutex.unlock()
		return
	file.store_32(PLAYER_MAGIC)
	file.store_16(FORMAT_VERSION)
	file.store_32(id)
	file.store_float(player.position.x)
	file.store_float(player.position.y)
	file.store_float(player.position.z)
	file.store_float(player.rotation.x)
	file.store_float(player.rotation.y)
	file.store_float(player.rotation.z)
	file.store_float(player.get_node("Head").rotation.x)
	file.flush()
	file.close()
	_replace_file_unlocked(temporary_path, path)
	_mutex.unlock()
