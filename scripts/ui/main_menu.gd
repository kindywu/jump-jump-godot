class_name MainMenu
extends Control

const TITLE_TEXTURE := preload("res://assets/texture/title.png")
const START_BTN_TEXTURE := preload("res://assets/texture/btn_start.png")

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
	title.texture = TITLE_TEXTURE
	title.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	title.custom_minimum_size = Vector2(200, 100)
	vbox.add_child(title)

	# Start button
	var start_btn := Button.new()
	start_btn.custom_minimum_size = Vector2(150, 60)
	start_btn.icon = START_BTN_TEXTURE
	start_btn.expand_icon = true
	start_btn.pressed.connect(_on_start_pressed)
	vbox.add_child(start_btn)

func _on_start_pressed() -> void:
	Game.change_state(Game.State.PLAYING)
