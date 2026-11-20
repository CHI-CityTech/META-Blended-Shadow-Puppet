@tool
class_name TileLayer
extends Node2D
## Draws the board plate, the 64 tiles, key-tile outlines and A-H / 1-8 labels.
## Put a shader on this node to restyle tiles.

var board: BoardState
var result: LightEngine.Result

func show_state(b: BoardState, r: LightEngine.Result) -> void:
	board = b
	result = r
	queue_redraw()

func _draw() -> void:
	if board == null:
		return
	var font := ThemeDB.fallback_font
	var plate := Rect2(Vector2.ZERO, Vector2.ONE * BoardState.SIZE * Look.CELL).grow(Look.BOARD_MARGIN)
	for i in range(5, 0, -1):  # soft drop shadow, wider rings drawn first
		draw_rect(plate.grow(i * 5.0).abs(), Look.BOARD_SHADOW)
	draw_rect(plate, Look.BOARD_BASE)
	draw_rect(plate, Look.BOARD_RIM, false, 2.0)
	for cell in board.all_cells():
		var rect := Rect2(Vector2(cell) * Look.CELL + Vector2(Look.GAP, Look.GAP) * 0.5, Vector2.ONE * (Look.CELL - Look.GAP))
		draw_rect(rect, Look.TILE[result.tile_at(cell)])
		if cell in Rules.KEY_TILES:
			draw_rect(rect, Look.KEY_OUTLINE, false, 3.0)
	for i in BoardState.SIZE:
		draw_string(font, Vector2(i * Look.CELL + Look.CELL * 0.5 - 4, BoardState.SIZE * Look.CELL + 18), char(65 + i), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Look.LABEL)
		draw_string(font, Vector2(-18, i * Look.CELL + Look.CELL * 0.5 + 5), str(BoardState.SIZE - i), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Look.LABEL)
