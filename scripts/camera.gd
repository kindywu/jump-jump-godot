extends Camera3D

const INITIAL_POS := Vector3(-5.0, 8.0, 5.0)

func _ready() -> void:
	position = INITIAL_POS
	look_at(Vector3.ZERO, Vector3.UP)

func _process(delta: float) -> void:
	if GameState.current_state != GameState.State.PLAYING:
		return

	var main_node: Node3D = get_parent()
	if main_node == null:
		return

	var player: Node3D = main_node.get("player")
	if player == null:
		return

	var player_pos: Vector3 = player.position

	# Only follow when player is idle
	if player.get("jump_active") or player.get("fall_active"):
		return

	var camera_destination := INITIAL_POS + player_pos
	position = position.lerp(camera_destination, 0.05)
