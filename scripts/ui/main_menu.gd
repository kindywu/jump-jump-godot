extends Control

func _ready() -> void:
	# Center VBox
	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.anchor_left = 0.5
	vbox.anchor_right = 0.5
	vbox.anchor_top = 0.5
	vbox.anchor_bottom = 0.5
	vbox.offset_left = -150
	vbox.offset_top = -100
	vbox.offset_right = 150
	vbox.offset_bottom = 100
	add_child(vbox)

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
