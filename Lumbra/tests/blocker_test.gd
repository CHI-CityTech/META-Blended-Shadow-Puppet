extends SceneTree
## Headless check of the Blocker crush rule.
## Run:  godot --headless -s tests/blocker_test.gd
## Expected: crush {27: true} and violations [(3, 3)]

func _init() -> void:
	var b := BoardState.new()
	b.set_unit(Vector2i(1, 3), Unit.new(Unit.Kind.EMITTER, Unit.Faction.LIGHT, 1))  # beam east
	b.set_unit(Vector2i(6, 3), Unit.new(Unit.Kind.EMITTER, Unit.Faction.LIGHT, 3))  # beam west
	b.set_unit(Vector2i(3, 3), Unit.new(Unit.Kind.BLOCKER, Unit.Faction.SHADOW, 0))
	var r := LightEngine.compute(b)
	print("hits: ", r.hits)
	print("crush: ", r.crush)
	print("violations: ", LightEngine.find_violations(b, r))
	quit()
