extends Camera3D

const INITIAL_POS := Vector3(-5.0, 8.0, 5.0)

var camera_step := Vector3.ZERO
var tracked_player_pos := Vector3(0.0, 1.5, 0.0)

func _ready() -> void:
	position = INITIAL_POS
	look_at(Vector3(0.0, 1.0, 0.0), Vector3.UP)

func _process(_delta: float) -> void:
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

	if tracked_player_pos.distance_to(player_pos) > 0.1:
		var delta_vector := camera_destination - position
		camera_step = 0.05 * delta_vector
		tracked_player_pos = player_pos

	if position.distance_to(camera_destination) > Vector3.ZERO.distance_to(camera_step):
		position += camera_step
