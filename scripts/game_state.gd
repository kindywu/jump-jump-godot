class_name GameState
extends Node

enum State { MAIN_MENU, PLAYING, GAME_OVER }

signal state_changed(new_state: State)
signal score_changed(new_score: int)
signal score_up(landing_pos: Vector3)

var current_state: State = State.MAIN_MENU
var score: int = 0

func change_state(new_state: State) -> void:
	current_state = new_state
	state_changed.emit(new_state)

func add_score() -> void:
	score += 1
	score_changed.emit(score)

func reset_score() -> void:
	score = 0
	score_changed.emit(score)
