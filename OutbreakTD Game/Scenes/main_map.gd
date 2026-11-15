extends Node2D

## Fill this in the Inspector, in keybind order: index 0 = key "1",
## index 1 = key "2", index 2 = key "3", index 3 = key "4", and so on.
@export var tower_scenes: Array[PackedScene] = []

## Gold cost of each tower, in the SAME ORDER as tower_scenes above
## (first number = first tower = key 1). Tune these freely.
@export var tower_costs: Array[int] = []

var tower_scene: PackedScene = null  # currently selected tower to place

# Stores all TileMapLayers in the scene
var tile_layers: Array[TileMapLayer] = []

# Placement state
var ghost_tower: BaseTower = null
var is_placing: bool = false
var placed_towers: Array = []
var min_tower_distance: float = 16.0
var pulse_time: float = 0.0

func _ready() -> void:
	for child in get_children():
		if child is TileMapLayer:
			tile_layers.append(child)

	if not tower_scenes.is_empty():
		select_tower_to_build(tower_scenes[0])

## Gold cost for a given tower scene (0 if no cost is set for it).
func get_tower_cost(scene: PackedScene) -> int:
	var idx := tower_scenes.find(scene)
	if idx == -1 or idx >= tower_costs.size():
		return 0
	return tower_costs[idx]

## Call this from a keybind or a UI button. Cancels whatever ghost is
## currently out (if any) and starts a fresh one with the new scene.
## Does nothing if you can't afford the tower.
func select_tower_to_build(scene: PackedScene) -> void:
	if scene == null:
		return
	if not GameManager.can_afford(get_tower_cost(scene)):
		return
	cancel_placement()
	tower_scene = scene
	start_tower_placement()

func start_tower_placement() -> void:
	if tower_scene == null or is_placing:
		return

	is_placing = true
	pulse_time = 0.0
	ghost_tower = tower_scene.instantiate()

	# Set preview state BEFORE adding to the tree. BaseTower's _ready() re-
	# applies preview visuals at the end regardless of timing, and critically
	# this lets _ready() see is_preview == true and skip the deploy animation
	# for ghosts — deploy should only ever play on a real, placed tower.
	ghost_tower.is_preview = true
	ghost_tower.is_valid_placement = true

	add_child(ghost_tower)

	# Disable gameplay processing, but leave the node visible and drawing.
	ghost_tower.process_mode = Node.PROCESS_MODE_DISABLED

	# Keep the root untinted: root modulate multiplies into the range circle
	# and would wash it out. Tinting happens on the sprites below.
	ghost_tower.modulate = Color.WHITE

func _process(delta: float) -> void:
	if not is_placing or ghost_tower == null:
		return

	var mouse_pos := get_global_mouse_position()
	ghost_tower.global_position = mouse_pos

	var valid := is_location_valid(mouse_pos)

	# Drives both the turret tint and the range circle color inside the turret script.
	ghost_tower.is_valid_placement = valid

	# Pulse only the sprites, never the root, so the circle keeps its own alpha.
	var tint: Color
	if valid:
		pulse_time = 0.0
		tint = Color(1.0, 1.0, 1.0, 0.5)
	else:
		pulse_time += delta
		var alpha_pulse: float = 0.4 + (sin(pulse_time * 15.0) + 1.0) * 0.3
		tint = Color(2.0, 0.0, 0.0, alpha_pulse)

	_tint_ghost_sprites(tint)

func _tint_ghost_sprites(tint: Color) -> void:
	var base := ghost_tower.get_node_or_null("BaseSprite") as CanvasItem
	var head := ghost_tower.get_node_or_null("TurretHead/HeadSprite") as CanvasItem
	if base:
		base.modulate = tint
	if head:
		head.modulate = tint

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var index := _tower_index_for_keycode(event.keycode)
		if index != -1 and index < tower_scenes.size():
			select_tower_to_build(tower_scenes[index])
			return

	if not is_placing:
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		cancel_placement()
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var mouse_pos := get_global_mouse_position()
		if is_location_valid(mouse_pos):
			confirm_placement(mouse_pos)

func _tower_index_for_keycode(keycode: int) -> int:
	match keycode:
		KEY_1: return 0
		KEY_2: return 1
		KEY_3: return 2
		KEY_4: return 3
		KEY_5: return 4
		KEY_6: return 5
		KEY_7: return 6
		KEY_8: return 7
		KEY_9: return 8
		_: return -1

func is_location_valid(pos: Vector2) -> bool:
	if tile_layers.is_empty():
		return false

	# Path-only towers (e.g. Mine Tower) need the OPPOSITE rule from normal
	# towers: valid only on a tile explicitly marked unbuildable (the path),
	# invalid on anything buildable (grass).
	var wants_path_tile := ghost_tower != null and ghost_tower.requires_path_tile

	var found_any_tile := false

	for layer in tile_layers:
		if not layer.visible:
			continue

		var local_pos := layer.to_local(pos)
		var cell_pos := layer.local_to_map(local_pos)
		var tile_data := layer.get_cell_tile_data(cell_pos)

		if tile_data == null:
			continue

		found_any_tile = true

		var is_buildable: bool = tile_data.get_custom_data("buildable") == true

		if wants_path_tile:
			if is_buildable:
				return false  # a mine standing on grass is invalid
		else:
			if not is_buildable:
				return false  # a normal tower standing on the path is invalid

	if not found_any_tile:
		return false

	for existing_tower in placed_towers:
		if is_instance_valid(existing_tower):
			if pos.distance_to(existing_tower.global_position) < min_tower_distance:
				return false

	return true

func confirm_placement(pos: Vector2) -> void:
	# Pay first. If the gold isn't there, nothing gets placed.
	if not GameManager.spend_coins(get_tower_cost(tower_scene)):
		return

	var new_tower = tower_scene.instantiate()
	new_tower.global_position = pos
	add_child(new_tower)
	new_tower.is_preview = false
	placed_towers.append(new_tower)

	cancel_placement()

func cancel_placement() -> void:
	if ghost_tower != null:
		ghost_tower.queue_free()
		ghost_tower = null
	is_placing = false
