extends Node

const DEFAULT_SPRITESHEET := preload("res://resources/spritesheet.png")
const OPAQUE_SHADER = preload("res://resources/opaque.gdshader")
const TRANSPARENT_SHADER = preload("res://resources/transparent.gdshader")
const SPRITE_SHADER = preload("res://resources/sprite.gdshader")
const SIZE := 16
const PACKS_DIR := "user://resource_packs"
const SETTINGS_PATH := "user://crepcraft_settings.cfg"

var opaque_material: ShaderMaterial
var transparent_material: ShaderMaterial
var sprite_material: ShaderMaterial
var active_pack := "Default"

func _ready() -> void:
	_load_active_pack()
	_rebuild_materials()

func get_available_packs() -> PackedStringArray:
	var packs := PackedStringArray(["Default"])
	var absolute_dir := ProjectSettings.globalize_path(PACKS_DIR)
	if not DirAccess.dir_exists_absolute(absolute_dir):
		DirAccess.make_dir_recursive_absolute(absolute_dir)
	var dir := DirAccess.open(PACKS_DIR)
	if dir == null:
		return packs
	dir.list_dir_begin()
	var entry := dir.get_next()
	while not entry.is_empty():
		if dir.current_is_dir() and not entry.begins_with("."):
			if FileAccess.file_exists(PACKS_DIR.path_join(entry).path_join("spritesheet.png")):
				packs.append(entry)
		entry = dir.get_next()
	dir.list_dir_end()
	packs.sort()
	if packs.has("Default"):
		packs.erase("Default")
		packs.insert(0, "Default")
	return packs

func set_active_pack(pack_name: String) -> bool:
	if not get_available_packs().has(pack_name):
		push_warning("Unknown resource pack: " + pack_name)
		return false
	active_pack = pack_name
	var config := ConfigFile.new()
	config.load(SETTINGS_PATH)
	config.set_value("resources", "active_pack", active_pack)
	var error := config.save(SETTINGS_PATH)
	if error != OK:
		push_warning("Could not save active resource pack.")
		return false
	_rebuild_materials()
	return true

func get_pack_directory() -> String:
	return PACKS_DIR

func _load_active_pack() -> void:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) == OK:
		var requested := str(config.get_value("resources", "active_pack", "Default"))
		if get_available_packs().has(requested):
			active_pack = requested

func _rebuild_materials() -> void:
	var spritesheet: Texture2D = DEFAULT_SPRITESHEET
	if active_pack != "Default":
		var path := PACKS_DIR.path_join(active_pack).path_join("spritesheet.png")
		var image := Image.load_from_file(path)
		if image != null and not image.is_empty():
			spritesheet = ImageTexture.create_from_image(image)
		else:
			push_warning("Resource pack texture could not be loaded; using Default.")
	var texture_array := _create_spritesheet(spritesheet)
	opaque_material = ShaderMaterial.new()
	opaque_material.shader = OPAQUE_SHADER
	opaque_material.set_shader_parameter("spritesheet", texture_array)
	transparent_material = ShaderMaterial.new()
	transparent_material.shader = TRANSPARENT_SHADER
	transparent_material.set_shader_parameter("spritesheet", texture_array)
	transparent_material.render_priority = 1
	sprite_material = ShaderMaterial.new()
	sprite_material.shader = SPRITE_SHADER
	sprite_material.set_shader_parameter("spritesheet", texture_array)

func _create_spritesheet(source: Texture2D) -> Texture2DArray:
	var image := source.get_image()
	if image.is_compressed():
		var error := image.decompress()
		if error != OK:
			push_error("Could not decompress the resource pack spritesheet.")
			return Texture2DArray.new()
	if image.get_width() % SIZE != 0 or image.get_height() % SIZE != 0:
		push_error("Resource pack spritesheet dimensions must be multiples of 16.")
		return Texture2DArray.new()
	var columns := image.get_width() / SIZE
	var rows := image.get_height() / SIZE
	var images: Array[Image] = []
	for y in range(rows):
		for x in range(columns):
			var layer := Image.create_empty(SIZE, SIZE, true, image.get_format())
			for px in range(SIZE):
				for py in range(SIZE):
					layer.set_pixel(px, py, image.get_pixel(x * SIZE + px, y * SIZE + py))
			layer.generate_mipmaps()
			images.append(layer)
	var texture_array := Texture2DArray.new()
	var error := texture_array.create_from_images(images)
	if error != OK:
		push_error("Could not create resource pack texture array.")
	return texture_array
