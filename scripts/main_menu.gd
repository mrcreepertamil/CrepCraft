extends Node

const WORLD_SCENE = preload("res://scenes/world.tscn")
const MENU_PANORAMA_SCRIPT = preload("res://scripts/menu_panorama.gd")

@onready var _menu_layer: CanvasLayer = $MenuLayer
var _seed_input: LineEdit
var _pack_picker: OptionButton
var _pack_window: Window

func _ready() -> void:
	_build_menu()
	_seed_input.text = str(_load_last_seed())

func _build_menu() -> void:
	var viewport_container := SubViewportContainer.new()
	viewport_container.name = "PanoramaView"
	viewport_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	viewport_container.stretch = true
	viewport_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$MenuLayer.add_child(viewport_container)

	var panorama_viewport := SubViewport.new()
	panorama_viewport.size = Vector2i(1600, 900)
	panorama_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	panorama_viewport.handle_input_locally = false
	viewport_container.add_child(panorama_viewport)

	var panorama := Node3D.new()
	panorama.name = "MenuPanorama"
	panorama.set_script(MENU_PANORAMA_SCRIPT)
	panorama.set("world_seed", _load_last_seed())
	panorama_viewport.add_child(panorama)

	var background := ColorRect.new()
	background.color = Color(0.015, 0.025, 0.04, 0.38)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$MenuLayer.add_child(background)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	$MenuLayer.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(420, 0)
	center.add_child(panel)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 16)
	panel.add_child(layout)

	var title := Label.new()
	title.text = "CREPCRAFT"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 38)
	layout.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "A world of your own."
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	layout.add_child(subtitle)

	var seed_label := Label.new()
	seed_label.text = "World Seed"
	layout.add_child(seed_label)

	_seed_input = LineEdit.new()
	_seed_input.placeholder_text = "Enter a number or generate one"
	_seed_input.clear_button_enabled = true
	_seed_input.text = str(randi_range(1, 2147483647))
	layout.add_child(_seed_input)

	var random_button := Button.new()
	random_button.text = "Random Seed"
	random_button.pressed.connect(_on_random_seed_pressed)
	layout.add_child(random_button)

	var play_button := Button.new()
	play_button.text = "Play / Load World"
	play_button.custom_minimum_size.y = 48
	play_button.pressed.connect(_on_play_pressed)
	layout.add_child(play_button)

	var packs_button := Button.new()
	packs_button.text = "Resource Packs"
	packs_button.pressed.connect(_open_resource_packs)
	layout.add_child(packs_button)

	var hint := Label.new()
	hint.text = "Using the same seed opens the same saved world."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	layout.add_child(hint)

	var quit_button := Button.new()
	quit_button.text = "Quit"
	quit_button.pressed.connect(get_tree().quit)
	layout.add_child(quit_button)

func _on_random_seed_pressed() -> void:
	_seed_input.text = str(randi_range(1, 2147483647))

func _on_play_pressed() -> void:
	var seed_text := _seed_input.text.strip_edges()
	if seed_text.is_empty():
		seed_text = str(randi_range(1, 2147483647))
	if not seed_text.is_valid_int():
		_seed_input.text = ""
		_seed_input.placeholder_text = "Enter a whole-number seed"
		return

	var world_seed := int(seed_text)
	if world_seed < -2147483648 or world_seed > 2147483647:
		_seed_input.text = ""
		_seed_input.placeholder_text = "Seed must be between -2147483648 and 2147483647"
		return
	var world := WORLD_SCENE.instantiate() as World
	var generator := world.get_node("Generator") as Generator
	var storage := world.get_node("Storage") as WorldStorage
	generator.set_seed(world_seed)
	# Legacy user:// worlds are copied into this folder on startup.
	storage.configure(GamePaths.get_worlds_directory().path_join("seed_%d" % world_seed), world_seed)
	_save_last_seed(world_seed)
	_menu_layer.hide()
	add_child(world)

func _load_last_seed() -> int:
	var config := ConfigFile.new()
	if config.load("user://crepcraft_settings.cfg") == OK:
		return int(config.get_value("world", "last_seed", 1337))
	return 1337

func _save_last_seed(value: int) -> void:
	var config := ConfigFile.new()
	config.set_value("world", "last_seed", value)
	var error := config.save("user://crepcraft_settings.cfg")
	if error != OK:
		push_warning("Could not save the last used world seed.")

func _open_resource_packs() -> void:
	if _pack_window == null:
		_build_resource_pack_window()
	_refresh_resource_pack_list()
	_pack_window.popup_centered()

func _build_resource_pack_window() -> void:
	_pack_window = Window.new()
	_pack_window.title = "Global Resource Packs"
	_pack_window.size = Vector2i(440, 230)
	_pack_window.transient = true
	_pack_window.exclusive = true
	add_child(_pack_window)

	var layout := VBoxContainer.new()
	layout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layout.add_theme_constant_override("separation", 12)
	layout.add_theme_constant_override("margin_left", 16)
	layout.add_theme_constant_override("margin_top", 16)
	layout.add_theme_constant_override("margin_right", 16)
	layout.add_theme_constant_override("margin_bottom", 16)
	_pack_window.add_child(layout)

	var description := Label.new()
	description.text = "Choose a pack to change textures throughout CrepCraft."
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	layout.add_child(description)

	_pack_picker = OptionButton.new()
	layout.add_child(_pack_picker)

	var apply_button := Button.new()
	apply_button.text = "Apply Resource Pack"
	apply_button.pressed.connect(_apply_resource_pack)
	layout.add_child(apply_button)

	var folder_button := Button.new()
	folder_button.text = "Open Resource Packs Folder"
	folder_button.pressed.connect(_open_resource_pack_folder)
	layout.add_child(folder_button)

func _refresh_resource_pack_list() -> void:
	_pack_picker.clear()
	var packs := GDCraftResources.get_available_packs()
	for pack in packs:
		_pack_picker.add_item(pack)
		if pack == GDCraftResources.active_pack:
			_pack_picker.select(_pack_picker.item_count - 1)

func _apply_resource_pack() -> void:
	var selected := _pack_picker.get_item_text(_pack_picker.selected)
	if GDCraftResources.set_active_pack(selected):
		_pack_window.title = "Applied: " + selected
		_pack_window.hide()

func _open_resource_pack_folder() -> void:
	var folder := ProjectSettings.globalize_path(GDCraftResources.get_pack_directory())
	DirAccess.make_dir_recursive_absolute(folder)
	OS.shell_open(folder)
