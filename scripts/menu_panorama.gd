extends Node3D

# Six-face image panorama. Place the supplied PNGs in res://assets/menu_panorama/.
# Horizontal order follows the uploaded image order; top is image 5? See mapping below.
const FACE_PATHS := {
	"front": "res://assets/menu_panorama/front.png",
	"right": "res://assets/menu_panorama/right.png",
	"back": "res://assets/menu_panorama/back.png",
	"left": "res://assets/menu_panorama/left.png",
	"top": "res://assets/menu_panorama/top.png",
	"bottom": "res://assets/menu_panorama/bottom.png",
}
const BOX_SIZE := 180.0
const ROTATION_SPEED := 0.035

var _pivot: Node3D

func _ready() -> void:
	_build_panorama()

func _process(delta: float) -> void:
	if is_instance_valid(_pivot):
		_pivot.rotate_y(ROTATION_SPEED * delta)

func _build_panorama() -> void:
	_pivot = Node3D.new()
	_pivot.name = "PanoramaRotation"
	add_child(_pivot)

	# Camera stays at the center while the six textured walls rotate around it.
	_add_face("front", Vector3(0, 0, -BOX_SIZE * 0.5), Vector3(0, 0, 0))
	_add_face("right", Vector3(BOX_SIZE * 0.5, 0, 0), Vector3(0, -90, 0))
	_add_face("back", Vector3(0, 0, BOX_SIZE * 0.5), Vector3(0, 180, 0))
	_add_face("left", Vector3(-BOX_SIZE * 0.5, 0, 0), Vector3(0, 90, 0))
	_add_face("top", Vector3(0, BOX_SIZE * 0.5, 0), Vector3(90, 0, 0))
	_add_face("bottom", Vector3(0, -BOX_SIZE * 0.5, 0), Vector3(-90, 0, 0))

	var camera := Camera3D.new()
	camera.name = "PanoramaCamera"
	camera.position = Vector3.ZERO
	camera.fov = 78.0
	camera.current = true
	_pivot.add_child(camera)

func _add_face(face_name: String, face_position: Vector3, face_rotation: Vector3) -> void:
	var path: String = FACE_PATHS[face_name]
	if not ResourceLoader.exists(path):
		push_warning("Missing panorama face: " + path)
		return

	var texture := load(path) as Texture2D
	if texture == null:
		push_warning("Could not load panorama face: " + path)
		return

	var quad := QuadMesh.new()
	quad.size = Vector2(BOX_SIZE, BOX_SIZE)

	var material := StandardMaterial3D.new()
	material.albedo_texture = texture
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR

	var face := MeshInstance3D.new()
	face.name = face_name.capitalize() + "Face"
	face.mesh = quad
	face.material_override = material
	face.position = face_position
	face.rotation_degrees = face_rotation
	_pivot.add_child(face)
