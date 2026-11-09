extends Node
## Loads Minecraft-style, data-driven content definitions from JSON files.

const DATA_FILES := {
	"blocks": "res://data/blocks.json",
	"items": "res://data/items.json",
	"biomes": "res://data/biomes.json",
	"recipes": "res://data/recipes.json",
	"mobs": "res://data/mobs.json",
	"worldgen": "res://data/worldgen.json",
}

var _data: Dictionary = {}

func _ready() -> void:
	for category in DATA_FILES:
		_load_category(category, DATA_FILES[category])

func _load_category(category: String, path: String) -> void:
	if not FileAccess.file_exists(path):
		push_error("Missing JSON data file: " + path)
		return
	var parser := JSON.new()
	var error := parser.parse(FileAccess.get_file_as_string(path))
	if error != OK:
		push_error("JSON parse error in %s at line %d: %s" % [
			path, parser.get_error_line(), parser.get_error_message()
		])
		return
	if typeof(parser.data) != TYPE_DICTIONARY:
		push_error("JSON data root must be an object: " + path)
		return
	_data[category] = parser.data

func get_category(category: String) -> Dictionary:
	return _data.get(category, {}).duplicate(true)

func get_definition(category: String, id: String) -> Dictionary:
	var definitions: Dictionary = _data.get(category, {})
	var definition: Variant = definitions.get(id, {})
	if typeof(definition) != TYPE_DICTIONARY:
		return {}
	return definition.duplicate(true)

func has_definition(category: String, id: String) -> bool:
	var definitions: Dictionary = _data.get(category, {})
	return definitions.has(id)

func get_ids(category: String) -> PackedStringArray:
	var definitions: Dictionary = _data.get(category, {})
	var ids := PackedStringArray()
	for id in definitions.keys():
		ids.append(str(id))
	ids.sort()
	return ids

func reload() -> void:
	_data.clear()
	for category in DATA_FILES:
		_load_category(category, DATA_FILES[category])
