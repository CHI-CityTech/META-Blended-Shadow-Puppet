@tool
class_name UnitView
extends Node2D
## One placed piece. Every scene in scenes/units/ uses this script with a different Sprite texture.
## Call setup() AFTER add_child(). BoardView keeps one view per Unit and calls sync() on every
## refresh, so place / rotate / capture can animate.

@onready var sprite: Sprite2D = $Sprite
var unit: Unit
var _facing := -1

func setup(u: Unit) -> void:
	unit = u
	_facing = u.facing
	sprite.scale = Vector2.ONE * (Look.CELL * 0.78 / 128.0)
	sprite.modulate = Look.UNIT[u.faction]
	_apply_facing()

## Spins a quarter turn when the unit was rotated since the last refresh. Returns true if it did.
func sync() -> bool:
	if unit.facing == _facing:
		return false
	_facing = unit.facing
	_apply_facing()
	rotation = -PI / 2.0  # start at the old orientation, swing clockwise into the new one
	if Engine.is_editor_hint() or Settings.animations:
		create_tween().tween_property(self, "rotation", 0.0, Look.ANIM_ROTATE) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	else:
		rotation = 0.0
	return true

func play_place() -> void:
	scale = Vector2.ONE * 0.3
	modulate.a = 0.0
	var t := create_tween().set_parallel()
	t.tween_property(self, "scale", Vector2.ONE, Look.ANIM_PLACE).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(self, "modulate:a", 1.0, Look.ANIM_PLACE * 0.6)

## Bursts outward, flares and fades, then frees itself.
func play_capture() -> void:
	var t := create_tween().set_parallel()
	t.tween_property(self, "scale", Vector2.ONE * 1.6, Look.ANIM_CAPTURE).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(self, "modulate", Color(2.0, 2.0, 2.0, 0.0), Look.ANIM_CAPTURE)
	t.chain().tween_callback(queue_free)

func _apply_facing() -> void:
	sprite.rotation = 0.0 if unit.kind == Unit.Kind.EMITTER else unit.facing * PI / 2.0
	queue_redraw()

func _draw() -> void:  # dark plate under the sprite; emitters also show their beam directions
	if unit == null:
		return
	draw_circle(Vector2.ZERO, Look.CELL * Look.UNIT_PLATE_RADIUS, Look.UNIT_PLATE)
	if unit.kind != Unit.Kind.EMITTER:
		return
	var col: Color = Look.UNIT[unit.faction]
	for d in unit.emit_dirs():  # dark outline first so the arrow reads on lit tiles
		var dir := Vector2(BoardState.DIRS[d])
		var tip := dir * Look.CELL * 0.47
		var side := Vector2(-dir.y, dir.x)
		var o := Look.ARROW_OUTLINE_WIDTH
		draw_line(dir * Look.CELL * 0.30, tip, Look.ARROW_OUTLINE, 3.0 + o * 2.0)
		draw_colored_polygon(PackedVector2Array([tip + dir * (4.0 + o * 1.6), tip - dir * (6.0 + o) + side * (6.0 + o * 1.8), tip - dir * (6.0 + o) - side * (6.0 + o * 1.8)]), Look.ARROW_OUTLINE)
		draw_line(dir * Look.CELL * 0.30, tip, col, 3.0)
		draw_colored_polygon(PackedVector2Array([tip + dir * 4.0, tip - dir * 6.0 + side * 6.0, tip - dir * 6.0 - side * 6.0]), col)
