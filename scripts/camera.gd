class_name GameCamera
extends Camera3D

const INITIAL_POS := Vector3(-5.0, 8.0, 5.0)

func _ready() -> void:
	set_process(false)
	Game.state_changed.connect(_on_state_changed)
	position = INITIAL_POS
	look_at(Vector3.ZERO, Vector3.UP)

func _on_state_changed(new_state: Game.State) -> void:
	set_process(new_state == Game.State.PLAYING)

func _process(delta: float) -> void:

	var main_node := get_parent() as Main
	if main_node == null:
		return

	var player: Player = main_node.player
	if player == null:
		return

	var player_pos: Vector3 = player.position

	# Only follow when player is idle
	if player.jump_active or player.fall_active:
		return

	var camera_destination := INITIAL_POS + player_pos
	position = position.lerp(camera_destination, 0.05)
