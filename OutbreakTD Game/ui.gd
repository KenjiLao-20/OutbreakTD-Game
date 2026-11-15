extends CanvasLayer

@onready var wave_label: Label = $WaveLabel

func _ready() -> void:
	update_wave_display(GameManager.current_wave)
	GameManager.wave_changed.connect(update_wave_display)

func update_wave_display(new_wave: int) -> void:
	wave_label.text = "Wave " + str(new_wave)
