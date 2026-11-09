extends Control

const JOYSTICK_RADIUS := 76.0
const BUTTON_RADIUS := 34.0

var _joystick_id := -1
var _joystick_origin := Vector2.ZERO
var _joystick_position := Vector2.ZERO
var _pressed_touches: Dictionary = {}

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			if event.position.x < size.x * 0.45 and event.position.y > size.y * 0.52 and _joystick_id == -1:
				_joystick_id = event.index
				_joystick_origin = event.position
				_joystick_position = event.position
				_update_movement()
				queue_redraw()
			else:
				_handle_button_touch(event.index, event.position, true)
		else:
				if event.index == _joystick_id:
					_joystick_id = -1
					_release_movement()
					queue_redraw()
				_release_button_touch(event.index)
	elif event is InputEventScreenDrag:
		if event.index == _joystick_id:
			_joystick_position = event.position
			_update_movement()
			queue_redraw()

func _handle_button_touch(index: int, position: Vector2, pressed: bool) -> void:
	var action := ""
	if position.x > size.x * 0.68 and position.y > size.y * 0.68:
		if position.x > size.x * 0.84:
			action = "jump"
		else:
			action = "crouch"
	elif position.x > size.x * 0.68 and position.y > size.y * 0.43:
		if position.x > size.x * 0.84:
			action = "place"
		else:
			action = "break"
	if action != "":
		_pressed_touches[index] = action
		Input.action_press(action)

func _release_button_touch(index: int) -> void:
	if _pressed_touches.has(index):
		Input.action_release(_pressed_touches[index])
		_pressed_touches.erase(index)

func _update_movement() -> void:
	var offset := _joystick_position - _joystick_origin
	var vector := offset.limit_length(JOYSTICK_RADIUS) / JOYSTICK_RADIUS
	Input.action_release("forward")
	Input.action_release("back")
	Input.action_release("left")
	Input.action_release("right")
	if vector.y < -0.15:
		Input.action_press("forward", -vector.y)
	elif vector.y > 0.15:
		Input.action_press("back", vector.y)
	if vector.x < -0.15:
		Input.action_press("left", -vector.x)
	elif vector.x > 0.15:
		Input.action_press("right", vector.x)

func _release_movement() -> void:
	for action in ["forward", "back", "left", "right"]:
		Input.action_release(action)

func _draw() -> void:
	if _joystick_id != -1:
		draw_circle(_joystick_origin, JOYSTICK_RADIUS, Color(0.1, 0.1, 0.1, 0.28))
		draw_circle(_joystick_position, 30.0, Color(0.85, 0.85, 0.85, 0.55))
	var base := Vector2(size.x * 0.78, size.y * 0.57)
	_draw_button(base, "BREAK")
	_draw_button(base + Vector2(size.x * 0.15, 0), "PLACE")
	_draw_button(Vector2(size.x * 0.78, size.y * 0.82), "CROUCH")
	_draw_button(Vector2(size.x * 0.93, size.y * 0.82), "JUMP")

func _draw_button(position: Vector2, label: String) -> void:
	draw_circle(position, BUTTON_RADIUS, Color(0.08, 0.08, 0.08, 0.38))
	draw_string(ThemeDB.fallback_font, position + Vector2(-BUTTON_RADIUS + 5, 5), label, HORIZONTAL_ALIGNMENT_CENTER, BUTTON_RADIUS * 2 - 10, 12, Color.WHITE)
