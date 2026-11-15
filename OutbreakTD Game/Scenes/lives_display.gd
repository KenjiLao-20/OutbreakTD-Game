extends HBoxContainer
## Lives display: a heart icon plus a number. Attach this to the
## HBoxContainer, then drag the Label into the "Count Label" slot.

@export var count_label: Label


func _ready() -> void:
	GameManager.base_health_changed.connect(_on_health_changed)
	# Show the current value right away (also covers scene reloads).
	_on_health_changed(GameManager.current_base_health)


func _on_health_changed(current: int) -> void:
	if count_label:
		count_label.text = str(current)
