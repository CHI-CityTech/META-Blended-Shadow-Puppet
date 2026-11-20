extends SceneTree
## Headless self-play to check balance. Both sides use a greedy one-move-ahead bot.
## Run:  godot --headless -s tests/balance_sim.gd -- <games> <first_seed> [light_bot] [shadow_bot]
## Bots: greedy (default) or random. Prints one CSV line per game:
##   GAME,seed,winner,reason,turns,light_lost,shadow_lost,light_tiles,shadow_tiles

const MAX_TURNS := 200
const L := Unit.Faction.LIGHT
const S := Unit.Faction.SHADOW

var rng := RandomNumberGenerator.new()

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var games := int(args[0]) if args.size() > 0 else 10
	var first := int(args[1]) if args.size() > 1 else 1
	var bots := {L: args[2] if args.size() > 2 else "greedy", S: args[3] if args.size() > 3 else "greedy"}
	for g in games:
		_play(first + g, bots)
	quit()

func _play(seed_value: int, bots: Dictionary) -> void:
	rng.seed = seed_value * 7919 + 1
	var tm := TurnManager.new()
	var over := {"winner": -1, "reason": ""}
	tm.game_over.connect(func(w, why):
		over.winner = w
		over.reason = why)
	tm.new_game(seed_value)
	var stuck := false
	while over.winner < 0 and tm.turn_number <= MAX_TURNS:
		var acted := _take_turn(tm, bots[tm.active])
		if not acted:
			stuck = true
			break
		if over.winner < 0:
			tm.confirm_handoff()
	var reason: String = over.reason.split(":")[0] if over.winner >= 0 else ("stuck" if stuck else "turn cap")
	var winner: String = Unit.FACTION_NAMES[over.winner] if over.winner >= 0 else "none"
	print("GAME,%d,%s,%s,%d,%d,%d,%d,%d" % [seed_value, winner, reason, tm.turn_number,
		tm.losses[L], tm.losses[S],
		LightEngine.count_tiles(tm.result, LightEngine.Tile.LIGHT),
		LightEngine.count_tiles(tm.result, LightEngine.Tile.SHADOW)])
	tm.free()

# ------------------------------------------------------------------ bots

## Returns false when the active side has no legal action at all.
func _take_turn(tm: TurnManager, bot: String) -> bool:
	var actions := _legal_actions(tm)
	if actions.is_empty():
		return false
	var pick: Dictionary
	if bot == "random":
		pick = actions[rng.randi_range(0, actions.size() - 1)]
	else:
		var best := -INF
		for a in actions:
			var s := _score(tm, a) + rng.randf() * 0.5  # small noise breaks ties, varies games
			if s > best:
				best = s
				pick = a
	match pick.type:
		"draw":
			return tm.try_draw()
		"place":
			return tm.try_place(pick.hand, pick.cell, pick.facing)
		_:
			return tm.try_rotate(pick.cell)

func _legal_actions(tm: TurnManager) -> Array:
	var out: Array = []
	var f := tm.active
	if tm.hands[f].size() < Rules.MAX_HAND and not tm.decks[f].is_empty():
		out.append({"type": "draw"})
	var seen := {}
	for i in tm.hands[f].size():
		var kind: int = tm.hands[f][i]
		if seen.has(kind):
			continue
		seen[kind] = true
		for cell in tm.board.all_cells():
			if tm.board.get_unit(cell) != null:
				continue
			for facing in _facings(kind):
				var b := _clone(tm.board)
				b.set_unit(cell, Unit.new(kind, f, facing))
				if cell in LightEngine.find_violations(b, LightEngine.compute(b)):
					continue  # suicide placement, TurnManager rejects it
				out.append({"type": "place", "hand": i, "kind": kind, "cell": cell, "facing": facing})
	for cell in tm.board.all_cells():
		var u := tm.board.get_unit(cell)
		if u != null and u.faction == f and not u.permanent:
			out.append({"type": "rotate", "cell": cell})  # Blocker/Veil rotation is a legal no-op (a pass)
	return out

func _facings(kind: int) -> Array:
	match kind:
		Unit.Kind.EMITTER, Unit.Kind.PRISM:
			return [0, 1, 2, 3]
		Unit.Kind.MIRROR:
			return [0, 1]
		_:
			return [0]

## Score the position after action `a` from the active side's point of view.
func _score(tm: TurnManager, a: Dictionary) -> float:
	var f := tm.active
	var o := TurnManager.opponent(f)
	if a.type == "draw":
		var r0 := tm.result
		return _eval(tm, f, o, r0, 0, 0) + 1.5  # a card in hand is worth a little
	var b := _clone(tm.board)
	if a.type == "place":
		b.set_unit(a.cell, Unit.new(a.kind, f, a.facing))
	else:
		b.get_unit(a.cell).rotate_cw()
	var lost := {L: 0, S: 0}
	var r: LightEngine.Result
	while true:
		r = LightEngine.compute(b)
		var bad := LightEngine.find_violations(b, r)
		if bad.is_empty():
			break
		for c in bad:
			var gone := b.remove_unit(c)
			if TurnManager.counts_as_loss(gone):
				lost[gone.faction] += 1
	return _eval(tm, f, o, r, lost[f], lost[o])

func _eval(tm: TurnManager, f: int, o: int, r: LightEngine.Result, my_new_loss: int, their_new_loss: int) -> float:
	var my_loss: int = tm.losses[f] + my_new_loss
	var their_loss: int = tm.losses[o] + their_new_loss
	if my_loss >= Rules.CAPTURE_LIMIT:
		return -10000.0
	if their_loss >= Rules.CAPTURE_LIMIT:
		return 10000.0
	var my_tile := LightEngine.Tile.LIGHT if f == L else LightEngine.Tile.SHADOW
	var their_tile := LightEngine.Tile.SHADOW if f == L else LightEngine.Tile.LIGHT
	var mine := LightEngine.count_tiles(r, my_tile)
	var theirs := LightEngine.count_tiles(r, their_tile)
	if mine >= Rules.TERRITORY_WIN:
		return 9000.0
	var my_centre := 0
	var their_centre := 0
	for c in Rules.KEY_TILES:
		if r.tile_at(c) == my_tile:
			my_centre += 1
		elif r.tile_at(c) == their_tile:
			their_centre += 1
	if my_centre == 4 and tm.zone_streak[f] + 1 >= Rules.ZONE_TURNS:
		return 9000.0
	var s := float(mine - theirs)
	s += 3.0 * my_centre - 3.0 * their_centre
	if my_centre == 4:
		s += 6.0 * (tm.zone_streak[f] + 1)
	if their_centre == 4:
		s -= 6.0 * (tm.zone_streak[o] + 1)
	if theirs >= Rules.TERRITORY_WIN - 3:
		s -= 20.0
	s += 12.0 * (their_new_loss - my_new_loss)
	return s

func _clone(b: BoardState) -> BoardState:
	var c := BoardState.new()
	for i in b.cells.size():
		var u: Unit = b.cells[i]
		c.cells[i] = null if u == null else Unit.new(u.kind, u.faction, u.facing, u.permanent, u.dual)
	return c
