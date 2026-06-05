class_name Main
extends Node3D

var player_scene: PackedScene = preload("res://scenes/player.tscn")
var platform_scene: PackedScene = preload("res://scenes/platform.tscn")

var player: Player = null
var current_platform: Platform = null
var next_platform: Platform = null
var rng := RandomNumberGenerator.new()

@onready var platforms_container: Node3D = $Platforms
@onready var start_sound: AudioStreamPlayer = $StartSound
@onready var prepare_timer: Timer = $PrepareTimer

var input_ready := false

func _ready() -> void:
	rng.randomize()
	set_process(false)
	Game.state_changed.connect(_on_state_changed)
	prepare_timer.timeout.connect(_on_prepare_timer_timeout)
	_enter_main_menu()

func _process(delta: float) -> void:
	# Animate current platform sinking/spring-back
	if current_platform:
		if player and player.charging:
			current_platform.scale.y = maxf(current_platform.scale.y - 0.15 * delta, 0.6)
		elif current_platform.scale.y < 1.0:
			current_platform.scale.y = lerpf(current_platform.scale.y, 1.0, 5.0 * delta)
			if current_platform.scale.y > 0.99:
				current_platform.scale.y = 1.0

func _on_state_changed(new_state: Game.State) -> void:
	match new_state:
		Game.State.MAIN_MENU:
			_enter_main_menu()
		Game.State.PLAYING:
			_enter_playing()
		Game.State.GAME_OVER:
			_enter_game_over()

func _enter_main_menu() -> void:
	set_process(false)
	_clear_player()
	_clear_platforms()
	$UI/MainMenu.visible = true
	$UI/GameOver.visible = false
	$UI/Scoreboard.visible = false

func _enter_playing() -> void:
	set_process(true)
	_clear_player()
	_clear_platforms()
	$UI/MainMenu.visible = false
	$UI/GameOver.visible = false
	$UI/Scoreboard.visible = true

	Game.reset_score()

	# Spawn first platform at origin
	current_platform = _spawn_platform(Vector3(0.0, 0.5, 0.0), true)

	# Spawn player
	player = player_scene.instantiate() as Player
	add_child(player)
	player.player_landed.connect(_on_player_landed)
	player.position = Vector3(0.0, 1.5, 0.0)

	# Generate first next platform
	_generate_next_platform()

	# Start delay timer (200ms before accepting input)
	input_ready = false
	prepare_timer.start()
	start_sound.play()

func _enter_game_over() -> void:
	set_process(false)
	$UI/GameOver.visible = true
	$UI/Scoreboard.visible = false

func _clear_player() -> void:
	if player:
		player.queue_free()
		player = null

func _clear_platforms() -> void:
	for child in platforms_container.get_children():
		child.queue_free()
	current_platform = null
	next_platform = null

func _spawn_platform(pos: Vector3, is_current: bool) -> Platform:
	var p := platform_scene.instantiate() as Platform
	p.position = pos
	p.is_current = is_current
	platforms_container.add_child(p)
	return p

func _generate_next_platform() -> void:
	if current_platform == null:
		return

	var current_pos := current_platform.position
	var rand_distance := rng.randf() * 1.5 + 2.5  # 2.5 ~ 4.0

	var next_pos: Vector3
	if rng.randi() % 2 == 0:
		next_pos = Vector3(current_pos.x + rand_distance, 0.5, current_pos.z)
	else:
		next_pos = Vector3(current_pos.x, 0.5, current_pos.z - rand_distance)

	next_platform = _spawn_platform(next_pos, false)

func _on_player_landed() -> void:
	if current_platform:
		current_platform.is_current = false
	current_platform = next_platform
	if current_platform:
		current_platform.is_current = true
	next_platform = null
	_generate_next_platform()

func _on_prepare_timer_timeout() -> void:
	input_ready = true
