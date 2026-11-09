class_name Generator
extends Node

enum Type {
	NOISE,
	SUPERFLAT,
	DEBUG,
}

@export var type = Type.NOISE
@export var generator_seed: int = 1337

var _continental_noise := FastNoiseLite.new()
var _detail_noise := FastNoiseLite.new()
var _ridge_noise := FastNoiseLite.new()
var _temperature_noise := FastNoiseLite.new()
var _humidity_noise := FastNoiseLite.new()
var _cave_noise := FastNoiseLite.new()
var _tree_noise := FastNoiseLite.new()
var _tree_height_noise := FastNoiseLite.new()
var _flora_noise := FastNoiseLite.new()
var _settings: Dictionary = {}

func _ready() -> void:
	set_seed(generator_seed)

func set_seed(value: int) -> void:
	generator_seed = value
	_settings = GameData.get_definition("worldgen", "default")
	if _settings.is_empty():
		_settings = {
			"sea_level": 10,
			"base_height": 13,
			"continental_amplitude": 15,
			"detail_amplitude": 5,
			"ridge_amplitude": 4,
			"continental_frequency": 0.004,
			"detail_frequency": 0.025,
			"ridge_frequency": 0.012,
			"biome_frequency": 0.0018,
			"cave_frequency": 0.035,
			"tree_frequency": 0.08,
			"flora_frequency": 0.12,
			"cave_threshold": 0.62,
			"forest_tree_threshold": 0.62,
			"plains_tree_threshold": 0.82
		}
	_configure_noise(_continental_noise, _derived_seed(13), float(_settings.get("continental_frequency", 0.004)), 4)
	_configure_noise(_detail_noise, _derived_seed(29), float(_settings.get("detail_frequency", 0.025)), 3)
	_configure_noise(_ridge_noise, _derived_seed(47), float(_settings.get("ridge_frequency", 0.012)), 3)
	_configure_noise(_temperature_noise, _derived_seed(61), float(_settings.get("biome_frequency", 0.0018)), 3)
	_configure_noise(_humidity_noise, _derived_seed(83), float(_settings.get("biome_frequency", 0.0018)) * 1.17, 3)
	_configure_noise(_cave_noise, _derived_seed(101), float(_settings.get("cave_frequency", 0.035)), 3)
	_configure_noise(_tree_noise, _derived_seed(139), float(_settings.get("tree_frequency", 0.08)), 2)
	_configure_noise(_tree_height_noise, _derived_seed(173), 0.16, 2)
	_configure_noise(_flora_noise, _derived_seed(197), float(_settings.get("flora_frequency", 0.12)), 2)

func _derived_seed(salt: int) -> int:
	return int(posmod(generator_seed * 104729 + salt * 7919, 2147483647))

func _configure_noise(noise: FastNoiseLite, noise_seed: int, frequency: float, octaves: int) -> void:
	noise.seed = noise_seed
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	noise.frequency = frequency
	noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise.fractal_octaves = octaves
	noise.fractal_lacunarity = 2.0
	noise.fractal_gain = 0.5

func _surface_height(world_x: int, world_z: int) -> int:
	var continental := _continental_noise.get_noise_2d(world_x, world_z)
	var detail := _detail_noise.get_noise_2d(world_x, world_z)
	var ridge := 1.0 - absf(_ridge_noise.get_noise_2d(world_x, world_z))
	var height := float(_settings.get("base_height", 13))
	height += continental * float(_settings.get("continental_amplitude", 15))
	height += detail * float(_settings.get("detail_amplitude", 5))
	height += ridge * float(_settings.get("ridge_amplitude", 4))
	return clampi(int(round(height)), 3, Chunk.HEIGHT - 12)

func _biome_at(world_x: int, world_z: int) -> String:
	var temperature := _temperature_noise.get_noise_2d(world_x, world_z)
	var humidity := _humidity_noise.get_noise_2d(world_x, world_z)
	if temperature < -0.38:
		return "snowy_plains"
	if temperature > 0.28 and humidity < -0.12:
		return "desert"
	if humidity > 0.18:
		return "forest"
	return "plains"

func _is_cave(world_x: int, world_y: int, world_z: int, surface_y: int) -> bool:
	if world_y < 5 or world_y >= surface_y - 3:
		return false
	return _cave_noise.get_noise_3d(world_x, world_y, world_z) > float(_settings.get("cave_threshold", 0.62))

func _put_world_block(blocks: Dictionary[Vector3i, Block.Type], chunk_index: Vector3i, world_x: int, world_y: int, world_z: int, block_type: Block.Type, only_if_empty: bool = false) -> void:
	var local_index := Vector3i(
		world_x - chunk_index.x * Chunk.WIDTH,
		world_y - chunk_index.y * Chunk.HEIGHT,
		world_z - chunk_index.z * Chunk.WIDTH
	)
	if not Chunk.in_bounds(local_index):
		return
	if only_if_empty and blocks.has(local_index):
		return
	blocks[local_index] = block_type

func _generate_terrain(index: Vector3i, blocks: Dictionary[Vector3i, Block.Type]) -> void:
	var sea_level := int(_settings.get("sea_level", 10))
	var world_start_x := index.x * Chunk.WIDTH
	var world_start_z := index.z * Chunk.WIDTH
	var world_start_y := index.y * Chunk.HEIGHT
	for local_x in range(Chunk.WIDTH):
		for local_z in range(Chunk.WIDTH):
			var world_x := world_start_x + local_x
			var world_z := world_start_z + local_z
			var surface_y := _surface_height(world_x, world_z)
			var biome := _biome_at(world_x, world_z)
			var top_block: Block.Type = Block.Type.SAND if biome == "desert" else Block.Type.GRASS
			var fill_top := maxi(surface_y, sea_level)
			for world_y in range(world_start_y, mini(world_start_y + Chunk.HEIGHT, fill_top + 1)):
				if world_y > surface_y:
					blocks[Vector3i(local_x, world_y - world_start_y, local_z)] = Block.Type.WATER
					continue
				if _is_cave(world_x, world_y, world_z, surface_y):
					continue
				var block_type: Block.Type = Block.Type.STONE
				if world_y == surface_y:
					block_type = top_block
				elif biome == "desert" and world_y >= surface_y - 4:
					block_type = Block.Type.SAND
				elif world_y >= surface_y - 3:
					block_type = Block.Type.DIRT
				blocks[Vector3i(local_x, world_y - world_start_y, local_z)] = block_type

func _generate_trees(index: Vector3i, blocks: Dictionary[Vector3i, Block.Type]) -> void:
	var start_x := index.x * Chunk.WIDTH
	var start_z := index.z * Chunk.WIDTH
	# Check a two-block border around this chunk so canopies are consistent
	# when a tree crosses a chunk boundary.
	for world_x in range(start_x - 2, start_x + Chunk.WIDTH + 2):
		for world_z in range(start_z - 2, start_z + Chunk.WIDTH + 2):
			var biome := _biome_at(world_x, world_z)
			if biome == "desert" or biome == "snowy_plains":
				continue
			var threshold := float(_settings.get("forest_tree_threshold", 0.62))
			if biome == "plains":
				threshold = float(_settings.get("plains_tree_threshold", 0.82))
			if _tree_noise.get_noise_2d(world_x, world_z) < threshold:
				continue
			var ground_y := _surface_height(world_x, world_z)
			var height_value := (_tree_height_noise.get_noise_2d(world_x, world_z) + 1.0) * 1.5
			var tree_height := 4 + int(height_value)
			for offset_y in range(tree_height):
				_put_world_block(blocks, index, world_x, ground_y + 1 + offset_y, world_z, Block.Type.LOG, true)
			for offset_x in range(-2, 3):
				for offset_y in range(-2, 3):
					for offset_z in range(-2, 3):
						if abs(offset_x) + abs(offset_y) + abs(offset_z) > 3:
							continue
						var leaf_y := ground_y + tree_height - 2 + offset_y
					if leaf_y <= ground_y:
						continue
					_put_world_block(blocks, index, world_x + offset_x, leaf_y, world_z + offset_z, Block.Type.LEAVES, true)

func _generate_foliage(index: Vector3i, blocks: Dictionary[Vector3i, Block.Type]) -> void:
	var start_x := index.x * Chunk.WIDTH
	var start_z := index.z * Chunk.WIDTH
	for local_x in range(Chunk.WIDTH):
		for local_z in range(Chunk.WIDTH):
			var world_x := start_x + local_x
			var world_z := start_z + local_z
			var biome := _biome_at(world_x, world_z)
			if biome == "desert" or biome == "snowy_plains":
				continue
			var ground_y := _surface_height(world_x, world_z)
			var local_ground := Vector3i(local_x, ground_y - index.y * Chunk.HEIGHT, local_z)
			var local_plant := local_ground + Vector3i.UP
			if not blocks.has(local_ground) or blocks[local_ground] != Block.Type.GRASS:
				continue
			if blocks.has(local_plant):
				continue
			var value := (_flora_noise.get_noise_2d(world_x, world_z) + 1.0) * 0.5
			var plant: Block.Type = Block.Type.EMPTY
			if value > 0.58 and value < 0.70:
				plant = Block.Type.BUSH
			elif value > 0.73 and value < 0.76:
				plant = Block.Type.POPPY
			elif value > 0.78 and value < 0.81:
				plant = Block.Type.DANDELION
			elif value > 0.83 and value < 0.86:
				plant = Block.Type.DAISY
			elif value > 0.88 and value < 0.90:
				plant = Block.Type.CORNFLOWER
			elif value > 0.92 and value < 0.94:
				plant = Block.Type.MARIGOLD
			elif value > 0.96:
				plant = Block.Type.LAVENDER
			if plant != Block.Type.EMPTY:
				blocks[local_plant] = plant

func _noise(index: Vector3i, blocks: Dictionary[Vector3i, Block.Type]) -> void:
	_generate_terrain(index, blocks)
	_generate_trees(index, blocks)
	_generate_foliage(index, blocks)

func _debug(_index: Vector3i, _blocks: Dictionary[Vector3i, Block.Type]) -> void:
	_blocks[Vector3i(0, 0, 0)] = Block.Type.GRASS

func _superflat(index: Vector3i, blocks: Dictionary[Vector3i, Block.Type]) -> void:
	if index.y != 0:
		return
	for x in range(Chunk.WIDTH):
		for z in range(Chunk.WIDTH):
			blocks[Vector3i(x, 0, z)] = Block.Type.STONE
			blocks[Vector3i(x, 1, z)] = Block.Type.STONE
			blocks[Vector3i(x, 2, z)] = Block.Type.STONE
			blocks[Vector3i(x, 3, z)] = Block.Type.DIRT
			blocks[Vector3i(x, 4, z)] = Block.Type.GRASS

func generate(index: Vector3i) -> Dictionary[Vector3i, Block.Type]:
	var blocks: Dictionary[Vector3i, Block.Type] = {}
	match type:
		Type.NOISE:
			_noise(index, blocks)
		Type.SUPERFLAT:
			_superflat(index, blocks)
		Type.DEBUG:
			_debug(index, blocks)
	assert(not blocks.is_empty())
	return blocks
