extends HBoxContainer
## Tower slot bar. Builds one slot per entry in main_map's tower_scenes
## array, using your TowerSlot frame PNG with a tower icon and its price.
## Clicking a slot = pressing that number key. Clicking the active slot
## again cancels placement. Slots you can't afford turn dark red.
##
## Tower Icons must be in the SAME ORDER as Tower Scenes on the MainMap
## root (index 0 = key 1 = first slot).

## Leave empty: it finds the MainMap root automatically. Only drag the
## MainMap root node in here if you get a "no builder" warning.
@export var builder: Node

@export var slot_texture: Texture2D
@export var tower_icons: Array[Texture2D] = []
@export var slot_size: Vector2 = Vector2(28, 28)
@export var icon_padding: float = 4.0
@export var slot_gap: int = 4
@export var price_font_size: int = 8
@export var selected_tint: Color = Color(1.0, 1.0, 1.0)
@export var unselected_tint: Color = Color(0.7, 0.7, 0.7)
@export var unaffordable_tint: Color = Color(0.45, 0.3, 0.3)

var _slots: Array[TextureButton] = []


func _ready() -> void:
	if builder == null:
		builder = owner

	if builder == null or builder.get("tower_scenes") == null:
		push_warning("TowerBar: couldn't find tower_scenes. Drag the MainMap root node into the Builder slot.")
		return

	add_theme_constant_override("separation", slot_gap)

	var count: int = builder.tower_scenes.size()
	for i in range(count):
		_slots.append(_make_slot(i))


func _make_slot(index: int) -> TextureButton:
	var slot := TextureButton.new()
	slot.texture_normal = slot_texture
	slot.ignore_texture_size = true
	slot.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	slot.custom_minimum_size = slot_size
	slot.focus_mode = Control.FOCUS_NONE  # keeps number keys/space from being eaten by the button
	add_child(slot)

	if index < tower_icons.size() and tower_icons[index] != null:
		var icon := TextureRect.new()
		icon.texture = tower_icons[index]
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE  # clicks go to the slot underneath
		icon.anchor_right = 1.0
		icon.anchor_bottom = 1.0
		icon.offset_left = icon_padding
		icon.offset_top = icon_padding
		icon.offset_right = -icon_padding
		icon.offset_bottom = -icon_padding
		slot.add_child(icon)

	var cost: int = builder.get_tower_cost(builder.tower_scenes[index])
	if cost > 0:
		var price := Label.new()
		price.text = str(cost)
		price.add_theme_font_size_override("font_size", price_font_size)
		price.add_theme_color_override("font_outline_color", Color.BLACK)
		price.add_theme_constant_override("outline_size", 2)
		price.mouse_filter = Control.MOUSE_FILTER_IGNORE
		price.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		price.anchor_left = 0.0
		price.anchor_right = 1.0
		price.anchor_top = 1.0
		price.anchor_bottom = 1.0
		price.grow_vertical = Control.GROW_DIRECTION_BEGIN  # grows upward from the bottom edge
		slot.add_child(price)

	slot.pressed.connect(_on_slot_pressed.bind(index))
	return slot


func _on_slot_pressed(index: int) -> void:
	var scene: PackedScene = builder.tower_scenes[index]
	if builder.is_placing and builder.tower_scene == scene:
		builder.cancel_placement()
	else:
		builder.select_tower_to_build(scene)  # does nothing if you can't afford it


func _process(_delta: float) -> void:
	if builder == null or _slots.is_empty():
		return
	for i in range(_slots.size()):
		var scene: PackedScene = builder.tower_scenes[i]
		var selected: bool = builder.is_placing and builder.tower_scene == scene
		var affordable: bool = GameManager.can_afford(builder.get_tower_cost(scene))

		if selected:
			_slots[i].modulate = selected_tint
		elif not affordable:
			_slots[i].modulate = unaffordable_tint
		else:
			_slots[i].modulate = unselected_tint
