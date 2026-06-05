class_name GameOverUI
extends Control

const TITLE_TEXTURE := preload("res://assets/texture/title.png")
const HOME_BTN_TEXTURE := preload("res://assets/texture/btn_home.png")
const RESTART_BTN_TEXTURE := preload("res://assets/texture/btn_restart.png")

func _ready() -> void:
	# Center container fills entire screen
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	# VBox for title + buttons
	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(vbox)

	# Title image
	var title := TextureRect.new()
	title.texture = TITLE_TEXTURE
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
	home_btn.icon = HOME_BTN_TEXTURE
	home_btn.expand_icon = true
	home_btn.pressed.connect(_on_home_pressed)
	hbox.add_child(home_btn)

	# Restart button
	var restart_btn := Button.new()
	restart_btn.custom_minimum_size = Vector2(150, 60)
	restart_btn.icon = RESTART_BTN_TEXTURE
	restart_btn.expand_icon = true
	restart_btn.pressed.connect(_on_restart_pressed)
	hbox.add_child(restart_btn)

func _on_home_pressed() -> void:
	Game.change_state(Game.State.MAIN_MENU)

func _on_restart_pressed() -> void:
	Game.change_state(Game.State.PLAYING)
