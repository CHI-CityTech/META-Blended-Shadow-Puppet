@tool
class_name BoardState
extends RefCounted
## Pure data: 8x8 grid of Unit (or null). Cell = Vector2i(x, y), (0,0) = A8 (top-left).

const SIZE := 8
const DIRS: Array[Vector2i] = [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]

var cells: Array = []

func _init() -> void:
	cells.resize(SIZE * SIZE)
	cells.fill(null)
	# Neutral corner emitters, each firing inward along both adjacent edges.
	set_unit(Vector2i(0, 0), Unit.new(Unit.Kind.EMITTER, Unit.Faction.NEUTRAL, 1, true, true))             # A8: E+S
	set_unit(Vector2i(SIZE - 1, 0), Unit.new(Unit.Kind.EMITTER, Unit.Faction.NEUTRAL, 2, true, true))      # H8: S+W
	set_unit(Vector2i(SIZE - 1, SIZE - 1), Unit.new(Unit.Kind.EMITTER, Unit.Faction.NEUTRAL, 3, true, true)) # H1: W+N
	set_unit(Vector2i(0, SIZE - 1), Unit.new(Unit.Kind.EMITTER, Unit.Faction.NEUTRAL, 0, true, true))      # A1: N+E

func idx(c: Vector2i) -> int:
	return c.y * SIZE + c.x

func in_bounds(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < SIZE and c.y < SIZE

func get_unit(c: Vector2i) -> Unit:
	return cells[idx(c)]

func set_unit(c: Vector2i, u: Unit) -> void:
	cells[idx(c)] = u

func remove_unit(c: Vector2i) -> Unit:
	var u: Unit = cells[idx(c)]
	cells[idx(c)] = null
	return u

## Deep copy (units are copied too), for previews that must not touch the real board.
func copy() -> BoardState:
	var b := BoardState.new()
	for i in cells.size():
		var u: Unit = cells[i]
		b.cells[i] = null if u == null else u.copy()
	return b

func all_cells() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for y in SIZE:
		for x in SIZE:
			out.append(Vector2i(x, y))
	return out

static func cell_name(c: Vector2i) -> String:
	return char(65 + c.x) + str(SIZE - c.y)
