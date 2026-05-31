extends Control

func _ready() -> void:
	# Center container fills entire screen
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	# VBox for title + button
	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(vbox)

	# Title image
	var title := TextureRect.new()
	title.texture = load("res://assets/texture/title.png")
	title.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	title.custom_minimum_size = Vector2(200, 100)
	vbox.add_child(title)

	# Start button
	var start_btn := Button.new()
	start_btn.custom_minimum_size = Vector2(150, 60)
	start_btn.icon = load("res://assets/texture/btn_start.png")
	start_btn.expand_icon = true
	start_btn.pressed.connect(_on_start_pressed)
	vbox.add_child(start_btn)

func _on_start_pressed() -> void:
	GameState.change_state(GameState.State.PLAYING)
