extends HBoxContainer
## Coin display: a coin icon plus a number. Attach this to the
## HBoxContainer, then drag the Label into the "Count Label" slot.

@export var count_label: Label


func _ready() -> void:
	GameManager.coins_changed.connect(_on_coins_changed)
	# Show the current value right away (also covers scene reloads).
	_on_coins_changed(GameManager.coins)


func _on_coins_changed(total: int) -> void:
	if count_label:
		count_label.text = str(total)
