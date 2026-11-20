@tool
class_name BeamLayer
extends Node2D
## Draws beams as UV-mapped quads (u = distance from the source in cells, v = across the beam).
## The node's shader (shaders/beam.gdshader) turns them into a glowing core + halo with pulses
## flowing away from the source. Hit markers live in HitMarkerLayer.

var result: LightEngine.Result

func _ready() -> void:
	if material is ShaderMaterial:
		(material as ShaderMaterial).set_shader_parameter("core_width", Look.BEAM_WIDTH / Look.BEAM_GLOW_WIDTH)

func show_state(r: LightEngine.Result) -> void:
	result = r
	queue_redraw()

func _draw() -> void:
	if result == null:
		return
	for seg in result.segments:
		var a: Vector2i = seg[0]
		var b: Vector2i = seg[1]
		var step := (b - a).sign()
		var p := a
		var u := 0.0
		while p != b:  # half a cell at a time, so each half takes its own cell's darkness
			var q := p + step
			var mid := (Look.cell_center(p) + Look.cell_center(q)) * 0.5
			_quad(Look.cell_center(p), mid, u, _alpha(p))
			_quad(mid, Look.cell_center(q), u + 0.5, _alpha(q))
			u += 1.0
			p = q

## Corner beams pass through Veil darkness but light nothing there, so draw them faint.
func _alpha(c: Vector2i) -> float:
	return Look.BEAM_IN_DARK if result.veiled[c.y * BoardState.SIZE + c.x] == 1 else 1.0

func _quad(a: Vector2, b: Vector2, u0: float, alpha: float) -> void:
	var dir := (b - a).normalized()
	var n := Vector2(-dir.y, dir.x) * Look.BEAM_GLOW_WIDTH * 0.5
	var u1 := u0 + a.distance_to(b) / Look.CELL
	var col := Look.BEAM
	col.a *= alpha
	draw_polygon(PackedVector2Array([a + n, b + n, b - n, a - n]), PackedColorArray([col, col, col, col]),
		PackedVector2Array([Vector2(u0, 0), Vector2(u1, 0), Vector2(u1, 1), Vector2(u0, 1)]))
