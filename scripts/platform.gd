extends Node3D

var shape: String = "box"
var is_current := false

@onready var box_mesh: MeshInstance3D = $BoxMesh
@onready var cylinder_mesh: MeshInstance3D = $CylinderMesh

func _ready() -> void:
	_randomize()

func _randomize() -> void:
	# Random shape
	if randi() % 2 == 0:
		shape = "box"
		box_mesh.visible = true
		cylinder_mesh.visible = false
	else:
		shape = "cylinder"
		box_mesh.visible = false
		cylinder_mesh.visible = true
	set_meta("shape", shape)

	# Random color
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(randf(), randf(), randf())
	box_mesh.material_override = mat
	cylinder_mesh.material_override = mat.duplicate()
