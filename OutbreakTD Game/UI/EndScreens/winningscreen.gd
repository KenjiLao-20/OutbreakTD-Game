extends Control
## Winning screen. Build the layout in the editor, then drag your two button
## nodes into the slots in the Inspector. Stays hidden until GameManager
## emits game_won.

const MAIN_MENU_PATH := "res://UI/MainMenu.tscn"

@export var retry_button: BaseButton
@export var exit_button: BaseButton


func _ready() -> void:
	visible = false

	if retry_button:
		retry_button.pressed.connect(_on_retry_pressed)
	else:
		push_warning("WinningScreen: no retry_button assigned in the Inspector.")

	if exit_button:
		exit_button.pressed.connect(_on_exit_pressed)
	else:
		push_warning("WinningScreen: no exit_button assigned in the Inspector.")

	GameManager.game_won.connect(_on_game_won)


func _on_game_won() -> void:
	visible = true
	get_tree().paused = true


func _on_retry_pressed() -> void:
	get_tree().paused = false
	GameManager.reset()
	get_tree().reload_current_scene()


func _on_exit_pressed() -> void:
	get_tree().paused = false
	GameManager.reset()
	get_tree().change_scene_to_file(MAIN_MENU_PATH)
