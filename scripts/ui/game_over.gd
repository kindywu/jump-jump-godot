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

	# Buttons row
	var hbox := HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(hbox)

	# Home button
	var home_btn := Button.new()
	home_btn.custom_minimum_size = Vector2(40, 40)
	home_btn.icon = load("res://assets/texture/btn_home.png")
	home_btn.expand_icon = true
	home_btn.pressed.connect(_on_home_pressed)
	hbox.add_child(home_btn)

	# Restart button
	var restart_btn := Button.new()
	restart_btn.custom_minimum_size = Vector2(150, 60)
	restart_btn.icon = load("res://assets/texture/btn_restart.png")
	restart_btn.expand_icon = true
	restart_btn.pressed.connect(_on_restart_pressed)
	hbox.add_child(restart_btn)

func _on_home_pressed() -> void:
	GameState.change_state(GameState.State.MAIN_MENU)

func _on_restart_pressed() -> void:
	GameState.change_state(GameState.State.PLAYING)
