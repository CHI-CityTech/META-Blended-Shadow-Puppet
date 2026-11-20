@tool
class_name HitMarkerLayer
extends Node2D
## Dashed violet bars on each side a beam struck a Blocker or entered a Veil's darkness.
## A second side means the piece is captured. Dashed and violet so they never read as beams.

var result: LightEngine.Result

func show_state(r: LightEngine.Result) -> void:
	result = r
	queue_redraw()

func _draw() -> void:
	if result == null:
		return
	for bi in result.hits:
		_mark_sides(bi, result.hits[bi], 0.5, 0.4)
	for vi in result.veil_hits:
		_mark_sides(vi, result.veil_hits[vi], LightEngine.VEIL_RADIUS + 0.5, LightEngine.VEIL_RADIUS + 0.4)

## reach: centre-to-edge distance in cells; half_len: half the bar length in cells.
func _mark_sides(i: int, dirs: Dictionary, reach: float, half_len: float) -> void:
	var c := Look.cell_center(_cell(i))
	for d in dirs:
		var dir := Vector2(BoardState.DIRS[d])
		var edge := c - dir * Look.CELL * reach
		var side := Vector2(-dir.y, dir.x) * Look.CELL * half_len
		draw_dashed_line(edge + side, edge - side, Look.HIT_MARK, Look.HIT_MARK_WIDTH, Look.HIT_MARK_DASH)

func _cell(i: int) -> Vector2i:
	return Vector2i(i % BoardState.SIZE, floori(float(i) / BoardState.SIZE))
