class_name Scoreboard
extends Control

const NUM_FONT := preload("res://assets/fonts/num.ttf")

var score_label: Label = null
var score_up_labels: Array[Label] = []

func _ready() -> void:
	set_process(false)
	Game.state_changed.connect(_on_state_changed)
	Game.score_changed.connect(_on_score_changed)
	Game.score_up.connect(_on_score_up)

	# Score label at top-left
	score_label = Label.new()
	score_label.add_theme_font_override("font", NUM_FONT)
	score_label.add_theme_font_size_override("font_size", 40)
	score_label.add_theme_color_override("font_color", Color(0.5, 0.5, 1.0))
	score_label.position = Vector2(30, 30)
	add_child(score_label)

func _on_score_changed(new_score: int) -> void:
	score_label.text = str(new_score)

func _on_score_up(landing_pos: Vector3) -> void:
	var label := Label.new()
	label.add_theme_font_override("font", NUM_FONT)
	label.add_theme_font_size_override("font_size", 40)
	label.add_theme_color_override("font_color", Color(0.5, 0.5, 1.0))
	label.text = "+1"

	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera:
		var screen_pos := camera.unproject_position(landing_pos)
		label.position = screen_pos

	add_child(label)
	score_up_labels.append(label)

func _on_state_changed(new_state: Game.State) -> void:
	set_process(new_state == Game.State.PLAYING)
	if new_state != Game.State.PLAYING:
		# Clean up floating labels on state change
		for label in score_up_labels:
			if is_instance_valid(label):
				label.queue_free()
		score_up_labels.clear()

func _process(delta: float) -> void:
	var to_remove: Array[int] = []
	for i in range(score_up_labels.size()):
		var label := score_up_labels[i]
		if not is_instance_valid(label):
			to_remove.append(i)
			continue

		label.position.y -= 100.0 * delta
		var color := label.get_theme_color("font_color", "Label")
		color.a *= 0.97
		label.add_theme_color_override("font_color", color)

		if color.a < 0.05:
			to_remove.append(i)

	to_remove.reverse()
	for i in to_remove:
		if is_instance_valid(score_up_labels[i]):
			score_up_labels[i].queue_free()
		score_up_labels.remove_at(i)
