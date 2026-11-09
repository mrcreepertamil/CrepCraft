extends Node

const WORLD_SCENE = preload("res://scenes/world.tscn")
const MENU_PANORAMA_SCRIPT = preload("res://scripts/menu_panorama.gd")

@onready var _menu_layer: CanvasLayer = $MenuLayer
var _seed_input: LineEdit

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
	panorama_viewport.add_child(panorama)
	panorama.set_world_seed(_load_last_seed())

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
	# Keep the original default save intact for existing installations.
	storage.configure("user://worlds/seed_%d" % world_seed, world_seed)
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
