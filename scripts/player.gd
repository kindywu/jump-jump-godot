extends Node3D

const INITIAL_POS := Vector3(0.0, 1.5, 0.0)
const JUMP_SPEED := 3.0
const MAX_SCALE_XZ := 1.3
const MIN_SCALE_Y := 0.6
const CHARGE_XZ_RATE := 0.12
const CHARGE_Y_RATE := 0.15
const FALL_SPEED := 0.7

enum FallType { STRAIGHT, TILT }

var charging := false
var charge_start_time := 0.0

# Jump
var jump_active := false
var jump_start_pos := Vector3.ZERO
var jump_end_pos := Vector3.ZERO
var jump_duration := 0.0
var jump_failed := false

# Fall
var fall_active := false
var fall_type: FallType = FallType.STRAIGHT
var fall_tilt_dir := Vector3.ZERO
var fall_pos := Vector3.ZERO
var fall_tilt_done := false
var fall_played_sound := false

# Audio refs
@onready var accumulation_player: AudioStreamPlayer3D = $AccumulationSound
@onready var success_player: AudioStreamPlayer3D = $SuccessSound
@onready var fall_player: AudioStreamPlayer3D = $FallSound

# Particle ref
@onready var charge_particles: GPUParticles3D = $ChargeParticles
@onready var charge_particle_timer: Timer = $ChargeParticleTimer

func _ready() -> void:
	position = INITIAL_POS
	charge_particle_timer.timeout.connect(_on_charge_particle_timeout)

func _process(delta: float) -> void:
	if GameState.current_state != GameState.State.PLAYING:
		return

	if charging:
		_animate_charge(delta)
	if jump_active:
		_animate_jump(delta)
	if fall_active and not jump_active:
		_animate_fall(delta)

func _unhandled_input(event: InputEvent) -> void:
	if GameState.current_state != GameState.State.PLAYING:
		return

	# Check 200ms prepare timer has elapsed
	var main_node: Node3D = get_parent()
	if main_node and not main_node.get("input_ready"):
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and not jump_active and not fall_active:
			_start_charge()
		elif not event.pressed and charging:
			_do_jump()

func _start_charge() -> void:
	charging = true
	charge_start_time = Time.get_ticks_msec() / 1000.0
	charge_particles.emitting = true
	charge_particle_timer.start()
	accumulation_player.play()

func _do_jump() -> void:
	var main_node: Node3D = get_parent()
	if main_node == null or not main_node.has_method("_on_player_landed"):
		return

	# Access next_platform through the main node
	var next_platform: Node3D = main_node.get("next_platform")
	if next_platform == null:
		return

	var charge_time := Time.get_ticks_msec() / 1000.0 - charge_start_time
	charging = false
	charge_particles.emitting = false
	charge_particle_timer.stop()
	accumulation_player.stop()

	var player_pos := position
	var current_platform: Node3D = main_node.get("current_platform")
	var current_pos := current_platform.position
	var next_pos := next_platform.position

	# Calculate landing position
	var landing_pos: Vector3
	if abs(next_pos.x - current_pos.x) < 0.1:
		landing_pos = Vector3(player_pos.x, INITIAL_POS.y, player_pos.z - JUMP_SPEED * charge_time)
	else:
		landing_pos = Vector3(player_pos.x + JUMP_SPEED * charge_time, INITIAL_POS.y, player_pos.z)

	jump_active = true
	jump_start_pos = player_pos
	jump_end_pos = landing_pos
	jump_duration = max(charge_time / 2.0, 0.5)

	# Landing check
	var landed_next := _is_landed_on(next_platform, landing_pos)
	var landed_current := _is_landed_on(current_platform, landing_pos)

	if landed_next or landed_current:
		jump_failed = false
		if landed_next:
			GameState.add_score()
			GameState.score_up.emit(landing_pos + Vector3.UP * 0.5)
			main_node._on_player_landed()
	else:
		jump_failed = true
		if _is_touched(current_platform, landing_pos, 0.2):
			var fd := Vector3.LEFT if abs(landing_pos.x - player_pos.x) < 0.1 else Vector3.FORWARD
			_start_tilt_fall(landing_pos, fd)
		elif _is_touched(next_platform, landing_pos, 0.2):
			var fd: Vector3
			if abs(landing_pos.x - player_pos.x) < 0.1:
				fd = Vector3.LEFT if landing_pos.z < next_pos.z else Vector3.RIGHT
			else:
				fd = Vector3.BACK if landing_pos.x < next_pos.x else Vector3.FORWARD
			_start_tilt_fall(landing_pos, fd)
		else:
			_start_straight_fall(landing_pos)

func _on_charge_particle_timeout() -> void:
	if charging:
		charge_particles.restart()

func _animate_charge(delta: float) -> void:
	scale.x = minf(scale.x + CHARGE_XZ_RATE * delta, MAX_SCALE_XZ)
	scale.y = maxf(scale.y - CHARGE_Y_RATE * delta, MIN_SCALE_Y)
	scale.z = minf(scale.z + CHARGE_XZ_RATE * delta, MAX_SCALE_XZ)
	# Keep bottom at platform level
	position.y = INITIAL_POS.y + (scale.y - 1.0) * 0.25

func _animate_jump(delta: float) -> void:
	var around_point := (jump_start_pos + jump_end_pos) / 2.0
	var rotate_axis: Vector3
	if abs(jump_end_pos.x - jump_start_pos.x) < 0.1:
		rotate_axis = Vector3.RIGHT
	else:
		rotate_axis = Vector3.BACK

	var angle := -(1.0 / jump_duration) * PI * delta
	var quat := Quaternion(rotate_axis, angle)
	var offset := position - around_point
	var new_pos := around_point + quat * offset

	if new_pos.y < INITIAL_POS.y:
		# Jump complete - land
		position = jump_end_pos
		transform.basis = Basis.IDENTITY
		scale = Vector3.ONE
		jump_active = false
		if not jump_failed:
			success_player.play()
	else:
		position = new_pos
		# Self-rotation (flip)
		var self_angle := -(1.0 / jump_duration) * TAU * delta
		rotate(rotate_axis, self_angle)

func _animate_fall(delta: float) -> void:
	if not fall_played_sound:
		fall_player.play()
		fall_played_sound = true
	match fall_type:
		FallType.STRAIGHT:
			if position.y < 0.5:
				fall_active = false
				GameState.change_state(GameState.State.GAME_OVER)
			else:
				position.y -= FALL_SPEED * delta
		FallType.TILT:
			if not fall_tilt_done:
				var pivot := Vector3(fall_pos.x, INITIAL_POS.y - 0.5, fall_pos.z)
				if position.y < pivot.y:
					fall_tilt_done = true
				else:
					var quat := Quaternion(fall_tilt_dir, PI / 2.0 * delta)
					var off := position - pivot
					position = pivot + quat * off
					transform.basis = Basis(quat) * transform.basis
			else:
				if position.y < 0.2:
					fall_active = false
					GameState.change_state(GameState.State.GAME_OVER)
				else:
					position.y -= FALL_SPEED * delta

func _start_straight_fall(pos: Vector3) -> void:
	fall_active = true
	fall_type = FallType.STRAIGHT
	fall_pos = pos
	fall_played_sound = false

func _start_tilt_fall(pos: Vector3, direction: Vector3) -> void:
	fall_active = true
	fall_type = FallType.TILT
	fall_pos = pos
	fall_tilt_dir = direction
	fall_tilt_done = false
	fall_played_sound = false

static func _is_landed_on(platform: Node3D, pos: Vector3) -> bool:
	if platform == null:
		return false
	var ppos := platform.position
	if platform.has_meta("shape"):
		var shape: String = platform.get_meta("shape")
		match shape:
			"cylinder":
				return abs(pos.x - ppos.x) < 0.75 and abs(pos.z - ppos.z) < 0.75
	return abs(pos.x - ppos.x) < 0.75 and abs(pos.z - ppos.z) < 0.75

static func _is_touched(platform: Node3D, pos: Vector3, radius: float) -> bool:
	if platform == null:
		return false
	var ppos := platform.position
	if platform.has_meta("shape"):
		var shape: String = platform.get_meta("shape")
		match shape:
			"cylinder":
				return abs(pos.x - ppos.x) < (0.75 + radius) and abs(pos.z - ppos.z) < (0.75 + radius)
	return abs(pos.x - ppos.x) < (0.75 + radius) and abs(pos.z - ppos.z) < (0.75 + radius)
