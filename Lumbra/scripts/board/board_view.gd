@tool
class_name BoardView
extends Node2D
## Composes the board from layers: Tiles -> Beams -> HitMarkers -> Units -> Preview.
## Emits cell_clicked / cell_hovered, and can show a move preview without touching the real pieces.
## Shows a starting-position preview in the editor.

signal cell_clicked(cell: Vector2i)
signal cell_hovered(cell: Vector2i)  # Vector2i(-1, -1) when the mouse leaves the board
signal piece_placed
signal piece_rotated
signal piece_captured

const UNIT_SCENES := {
	Unit.Kind.EMITTER: preload("res://scenes/units/emitter.tscn"),
	Unit.Kind.MIRROR: preload("res://scenes/units/mirror.tscn"),
	Unit.Kind.PRISM: preload("res://scenes/units/prism.tscn"),
	Unit.Kind.BLOCKER: preload("res://scenes/units/blocker.tscn"),
	Unit.Kind.VEIL: preload("res://scenes/units/veil.tscn"),
}

@onready var tiles: TileLayer = $Tiles
@onready var beams: BeamLayer = $Beams
@onready var markers: HitMarkerLayer = $HitMarkers
@onready var units: Node2D = $Units
@onready var preview_layer: Node2D = $Preview
var board: BoardState
var _result: LightEngine.Result
var _views := {}  # Unit -> UnitView, kept between refreshes so pieces can animate
var _hover := Vector2i(-1, -1)
var _ghost: UnitView
var _hidden: UnitView   # real view hidden while its rotation is previewed
var _doomed: Array = [] # [UnitView, Tween] pulsing red during a preview
var _previewing := false

func _ready() -> void:
	if Engine.is_editor_hint():
		var b := BoardState.new()
		refresh(b, LightEngine.compute(b))

func refresh(b: BoardState, r: LightEngine.Result) -> void:
	clear_preview()
	var fresh := b != board
	if fresh:  # new game: drop the old pieces without capture animations
		for v in _views.values():
			v.queue_free()
		_views.clear()
	board = b
	_result = r
	tiles.show_state(b, r)
	beams.show_state(r)
	markers.show_state(r)
	var animate := not Engine.is_editor_hint() and Settings.animations
	var seen := {}
	for cell in b.all_cells():
		var u := b.get_unit(cell)
		if u == null:
			continue
		seen[u] = true
		var view: UnitView = _views.get(u)
		if view == null:
			view = UNIT_SCENES[u.kind].instantiate()
			units.add_child(view)
			view.setup(u)
			_views[u] = view
			if animate:
				view.play_place()
			if not fresh:
				piece_placed.emit()
		elif view.sync():
			piece_rotated.emit()
		view.position = Look.cell_center(cell)
	for u in _views.keys():  # captured since the last refresh
		if not seen.has(u):
			var gone: UnitView = _views[u]
			_views.erase(u)
			piece_captured.emit()
			if animate:
				gone.play_capture()
			else:
				gone.queue_free()

## p comes from TurnManager.preview_place / preview_rotate: {legal, board, result, unit, captured}.
func show_preview(p: Dictionary, cell: Vector2i) -> void:
	clear_preview()
	if p.is_empty():
		return
	_previewing = true
	if p.legal:  # show the light as it would be after the move
		tiles.show_state(p.board, p.result)
		beams.show_state(p.result)
		markers.show_state(p.result)
	_hidden = _views.get(board.get_unit(cell))  # rotating: the ghost replaces the real piece
	if _hidden != null:
		_hidden.visible = false
	_ghost = UNIT_SCENES[p.unit.kind].instantiate()
	preview_layer.add_child(_ghost)
	_ghost.setup(p.unit)
	_ghost.position = Look.cell_center(cell)
	_ghost.modulate = Look.PREVIEW_GHOST if p.legal else Look.PREVIEW_BAD
	if not p.legal:
		return
	for e in p.captured:
		var v: UnitView = _ghost if e[0] == cell else _views.get(board.get_unit(e[0]))
		if v == null:
			continue
		var t := v.create_tween().set_loops()
		t.tween_property(v, "modulate", Look.PREVIEW_DOOMED, 0.3)
		t.tween_property(v, "modulate", Color.WHITE, 0.3)
		_doomed.append([v, t])

func clear_preview() -> void:
	if not _previewing:
		return
	_previewing = false
	for d in _doomed:
		(d[1] as Tween).kill()
		if is_instance_valid(d[0]):
			(d[0] as UnitView).modulate = Color.WHITE
	_doomed.clear()
	if _ghost != null:
		_ghost.queue_free()
		_ghost = null
	if _hidden != null and is_instance_valid(_hidden):
		_hidden.visible = true
	_hidden = null
	if board != null and _result != null:
		tiles.show_state(board, _result)
		beams.show_state(_result)
		markers.show_state(_result)

func _unhandled_input(e: InputEvent) -> void:
	if Engine.is_editor_hint():
		return
	if e is InputEventMouseMotion:
		var h := _cell_under_mouse()
		if h != _hover:
			_hover = h
			cell_hovered.emit(h)
	elif e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		var c := _cell_under_mouse()
		if c.x >= 0:
			cell_clicked.emit(c)

func _cell_under_mouse() -> Vector2i:
	var p := get_local_mouse_position()
	var c := Vector2i(floori(p.x / Look.CELL), floori(p.y / Look.CELL))
	return c if visible and board != null and board.in_bounds(c) else Vector2i(-1, -1)
