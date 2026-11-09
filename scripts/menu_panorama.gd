extends Node3D

const VIEW_RADIUS := 30
const WORLD_SIZE := VIEW_RADIUS * 2
const CAMERA_HEIGHT := 22.0
const CAMERA_DISTANCE := 0.0
const ROTATION_SPEED := 0.035

var _pivot: Node3D
var _generator: Generator
var world_seed := 1337

func _ready() -> void:
	_build_scene()

func _process(delta: float) -> void:
	if is_instance_valid(_pivot):
		_pivot.rotate_y(ROTATION_SPEED * delta)

func set_world_seed(value: int) -> void:
	if is_instance_valid(_generator):
		_generator.set_seed(value)
		_rebuild_terrain()

func _build_scene() -> void:
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(0.12, 0.28, 0.48)
	sky_material.sky_horizon_color = Color(0.62, 0.76, 0.88)
	sky_material.ground_bottom_color = Color(0.12, 0.16, 0.12)
	sky_material.ground_horizon_color = Color(0.48, 0.55, 0.42)
	sky.sky_material = sky_material
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.15
	environment.environment = env
	add_child(environment)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48.0, -32.0, 0.0)
	sun.light_energy = 1.15
	sun.shadow_enabled = true
	add_child(sun)

	_pivot = Node3D.new()
	_pivot.position = Vector3(0.0, 0.0, 0.0)
	add_child(_pivot)

	var camera := Camera3D.new()
	camera.position = Vector3(0.0, CAMERA_HEIGHT, 0.0)
	camera.rotation_degrees = Vector3(-12.0, 0.0, 0.0)
	camera.fov = 78.0
	camera.current = true
	_pivot.add_child(camera)

	_generator = Generator.new()
	_generator.type = Generator.Type.NOISE
	add_child(_generator)
	_generator.set_seed(world_seed)
	_rebuild_terrain()

func _rebuild_terrain() -> void:
	var old := get_node_or_null("Terrain")
	if old:
		remove_child(old)
		old.queue_free()

	var blocks: Dictionary[Vector3i, Block.Type] = {}
	for x in range(-VIEW_RADIUS, VIEW_RADIUS):
		for z in range(-VIEW_RADIUS, VIEW_RADIUS):
			var height := _generator._surface_height(x, z)
			var biome := _generator._biome_at(x, z)
			for y in range(height + 1):
				var kind: Block.Type = Block.Type.STONE
				if y == height:
					kind = Block.Type.SAND if biome == "desert" else Block.Type.GRASS
				elif biome == "desert" and y >= height - 4:
					kind = Block.Type.SAND
				elif y >= height - 3:
					kind = Block.Type.DIRT
				blocks[Vector3i(x, y, z)] = kind

	# Add a lightweight scattering of simple voxel trees.
	var tree_noise := FastNoiseLite.new()
	tree_noise.seed = _generator.generator_seed + 7919
	tree_noise.frequency = 0.11
	var tree_height_noise := FastNoiseLite.new()
	tree_height_noise.seed = _generator.generator_seed + 173
	tree_height_noise.frequency = 0.16
	for x in range(-VIEW_RADIUS + 3, VIEW_RADIUS - 3, 3):
		for z in range(-VIEW_RADIUS + 3, VIEW_RADIUS - 3, 3):
			if _generator._biome_at(x, z) != "forest" and _generator._biome_at(x, z) != "plains":
				continue
			if tree_noise.get_noise_2d(x, z) < 0.38:
				continue
			var ground := _generator._surface_height(x, z)
			var trunk_height := 4 + int((tree_height_noise.get_noise_2d(x, z) + 1.0) * 1.5)
			for ty in range(1, trunk_height + 1):
				blocks[Vector3i(x, ground + ty, z)] = Block.Type.LOG
			for ox in range(-2, 3):
				for oy in range(-2, 3):
					for oz in range(-2, 3):
						if abs(ox) + abs(oy) + abs(oz) > 3:
							continue
						var leaf_pos := Vector3i(x + ox, ground + trunk_height - 1 + oy, z + oz)
						if not blocks.has(leaf_pos):
							blocks[leaf_pos] = Block.Type.LEAVES

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array()
	arrays[Mesh.ARRAY_NORMAL] = PackedVector3Array()
	arrays[Mesh.ARRAY_TEX_UV] = PackedVector2Array()
	arrays[Mesh.ARRAY_TEX_UV2] = PackedVector2Array()
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array()

	for pos in blocks:
		var kind: Block.Type = blocks[pos]
		for face in range(Face.Type.COUNT):
			var neighbor := pos + Face.get_vector(face)
			if blocks.has(neighbor):
				continue
			_append_face(arrays, pos, kind, face)

	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var terrain := MeshInstance3D.new()
	terrain.name = "Terrain"
	terrain.mesh = mesh
	terrain.material_override = GDCraftResources.opaque_material
	add_child(terrain)

func _append_face(arrays: Array, pos: Vector3i, kind: Block.Type, face: int) -> void:
	var start := arrays[Mesh.ARRAY_VERTEX].size()
	var origin := Vector3(pos)
	for i in range(4):
		arrays[Mesh.ARRAY_VERTEX].append(origin + Block.get_vertex(kind, face, i))
		arrays[Mesh.ARRAY_NORMAL].append(Block.get_normal(kind, face))
		arrays[Mesh.ARRAY_TEX_UV].append(Block.get_texcoord(kind, face))
		arrays[Mesh.ARRAY_TEX_UV2].append(Block.get_texcoord2(kind, face, i))
	for index in Block.get_indices():
		arrays[Mesh.ARRAY_INDEX].append(start + index)
