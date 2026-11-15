extends Sprite2D
## Attach to your Base node. The sprite sheet has 5 frames in a single
## row (hframes = 5, vframes = 1) — frame index maps directly to the
## damage tier: 0 = No Damage, 1 = Minimal, 2 = Mid, 3 = Heavy, 4 = Destroyed.
##
## Source frames are 512x512; the base displays at 32x32 (2x2 tiles) in-game.
## Scale is computed from the actual texture size rather than hardcoded, so
## if the sprite sheet ever gets swapped for a different resolution, this
## still lands on the right on-screen size automatically.

const FRAME_COUNT: int = 5
@export var target_display_size: float = 32.0  # pixels, in-game footprint


func _ready() -> void:
	hframes = FRAME_COUNT
	vframes = 1

	if texture:
		var frame_width: float = texture.get_width() / float(FRAME_COUNT)
		var computed_scale: float = target_display_size / frame_width
		scale = Vector2(computed_scale, computed_scale)
	else:
		push_warning("HomeBase: no texture assigned yet, can't compute scale.")

	GameManager.base_damage_state_changed.connect(_on_damage_state_changed)
	# Sync immediately in case this scene loaded mid-run (e.g. after a reload).
	_on_damage_state_changed(GameManager.get_current_damage_state())


func _on_damage_state_changed(state: int) -> void:
	if state < 0 or state >= FRAME_COUNT:
		push_warning("HomeBase: damage state %d out of range for a %d-frame sheet" % [state, FRAME_COUNT])
		return

	frame = state
