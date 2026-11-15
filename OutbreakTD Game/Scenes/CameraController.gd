extends Camera2D

@export var pan_speed: float = 500.0

@export var zoom_step: float = 0.1
@export var min_zoom: float = 0.5  # smaller = zoomed in further
@export var max_zoom: float = 2.5  # larger = zoomed out further

## If true, limit_left/top/right/bottom are calculated automatically from
## every TileMapLayer sibling's actual painted area on _ready(), so the
## camera can never scroll past the edge of the real map. Turn this off if
## you'd rather set the four Limit fields by hand instead.
@export var auto_detect_bounds: bool = true

## Leave empty to combine every TileMapLayer sibling (can be too generous if
## you have decorative/background tiles painted beyond the playable area).
## Set this to the exact node name of your main Ground/Path layer to use
## ONLY that layer's painted extent, ignoring decoration overflow.
@export var bounds_layer_name: String = ""


func _ready() -> void:
	make_current()
	if auto_detect_bounds:
		_auto_set_limits()


func _auto_set_limits() -> void:
	var combined_rect := Rect2()
	var found_any := false

	for sibling in get_parent().get_children():
		if not sibling is TileMapLayer:
			continue
		if bounds_layer_name != "" and sibling.name != bounds_layer_name:
			continue  # skip decorative/other layers when a specific one is named

		var layer := sibling as TileMapLayer
		var used_cells := layer.get_used_rect()
		if used_cells.size == Vector2i.ZERO:
			continue

		var tile_size: Vector2 = Vector2(layer.tile_set.tile_size) if layer.tile_set else Vector2(16, 16)
		var top_left: Vector2 = layer.to_global(layer.map_to_local(used_cells.position)) - tile_size * 0.5
		var world_rect := Rect2(top_left, Vector2(used_cells.size) * tile_size)

		combined_rect = world_rect if not found_any else combined_rect.merge(world_rect)
		found_any = true

	if found_any:
		limit_left = int(combined_rect.position.x)
		limit_top = int(combined_rect.position.y)
		limit_right = int(combined_rect.position.x + combined_rect.size.x)
		limit_bottom = int(combined_rect.position.y + combined_rect.size.y)
		_clamp_zoom_to_map_size(combined_rect.size)
	else:
		push_warning("CameraController: no TileMapLayer found to auto-detect bounds from. Set Limit fields manually or add a TileMapLayer sibling.")


## Caps max_zoom so the camera can never show more world than the map
## actually has — otherwise grey out-of-bounds space is visible no matter
## how tightly limit_left/top/right/bottom are set, any time the visible
## area (viewport_size * zoom) exceeds the map's real pixel size.
func _clamp_zoom_to_map_size(map_size: Vector2) -> void:
	var viewport_size := get_viewport_rect().size
	if map_size.x <= 0.0 or map_size.y <= 0.0:
		return

	# The zoom level at which the view exactly fits the map on its tighter axis.
	var fit_zoom: float = min(map_size.x / viewport_size.x, map_size.y / viewport_size.y)

	# Hard ceiling: never zoom out past the original window framing (1.0),
	# even if the bounds layer itself is larger than the viewport.
	max_zoom = min(max_zoom, fit_zoom, 1.0)
	if min_zoom > max_zoom:
		min_zoom = max_zoom

	# If the map is smaller than the viewport even at zoom 1, the starting
	# zoom needs to shrink to fit_zoom right away, not just be capped on
	# the next scroll.
	zoom.x = clamp(zoom.x, min_zoom, max_zoom)
	zoom.y = zoom.x


func _process(delta: float) -> void:
	_handle_wasd_pan(delta)


func _handle_wasd_pan(delta: float) -> void:
	var pan_dir := Vector2.ZERO

	if Input.is_key_pressed(KEY_A):
		pan_dir.x -= 1
	if Input.is_key_pressed(KEY_D):
		pan_dir.x += 1
	if Input.is_key_pressed(KEY_W):
		pan_dir.y -= 1
	if Input.is_key_pressed(KEY_S):
		pan_dir.y += 1

	if pan_dir != Vector2.ZERO:
		# Divide by zoom so panning speed feels consistent whether zoomed in or out.
		position += pan_dir.normalized() * pan_speed * delta / zoom.x


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom_by(-zoom_step)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom_by(zoom_step)


func _zoom_by(amount: float) -> void:
	var new_zoom: float = clamp(zoom.x + amount, min_zoom, max_zoom)
	zoom = Vector2(new_zoom, new_zoom)
