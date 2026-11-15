extends Control
## Main menu. Build the layout in the editor, then drag your two button
## nodes into the slots below in the Inspector. Pick the gameplay scene
## with the file picker on "Game Scene Path" (no typing paths by hand).

@export var play_button: BaseButton
@export var quit_button: BaseButton
@export_file("*.tscn") var game_scene_path: String


func _ready() -> void:
	if play_button:
		play_button.pressed.connect(_on_play_pressed)
	else:
		push_warning("MainMenu: no play_button assigned in the Inspector.")

	if quit_button:
		quit_button.pressed.connect(_on_quit_pressed)
	else:
		push_warning("MainMenu: no quit_button assigned in the Inspector.")


func _on_play_pressed() -> void:
	if game_scene_path.is_empty():
		push_warning("MainMenu: no game_scene_path set in the Inspector.")
		return
	get_tree().paused = false
	GameManager.reset()  # autoload survives scene changes, so start clean
	get_tree().change_scene_to_file(game_scene_path)


func _on_quit_pressed() -> void:
	get_tree().quit()
