class_name TurnManager
extends Node
## Pass-and-play state machine. Exactly ONE action per turn: draw / place / rotate.
## UI talks to this node only via try_*() / confirm_handoff() and listens to signals.
## Flow: AWAITING_ACTION -> RESOLVING -> HANDOFF -> (confirm) -> AWAITING_ACTION | GAME_OVER

signal turn_started(faction: int)
signal hands_changed(faction: int)
signal board_changed(result: LightEngine.Result, captured: Array)  # captured: Array[Unit]
signal handoff_requested(next_faction: int)
signal action_rejected(reason: String)
signal game_over(winner: int, reason: String)

enum State { SETUP, AWAITING_ACTION, RESOLVING, HANDOFF, GAME_OVER }

var board: BoardState
var result: LightEngine.Result
var state: State = State.SETUP
var active: int = Unit.Faction.LIGHT
var turn_number := 1
var hands := {}        # faction -> Array[int] (Unit.Kind)
var decks := {}
var losses := {}
var zone_streak := {}
var final_turns_left := -1  # starts once both decks are empty; the game ends at 0
var last_captures: Array = []  # [cell, Unit] captured by the most recent action
var _rng := RandomNumberGenerator.new()

func new_game(seed_value := -1) -> void:
	if seed_value >= 0:
		_rng.seed = seed_value
	else:
		_rng.randomize()
	board = BoardState.new()
	result = LightEngine.compute(board)
	active = Unit.Faction.LIGHT
	turn_number = 1
	decks = {
		Unit.Faction.LIGHT: _build_deck(Rules.LIGHT_DECK),
		Unit.Faction.SHADOW: _build_deck(Rules.SHADOW_DECK),
	}
	hands = {Unit.Faction.LIGHT: [], Unit.Faction.SHADOW: []}
	losses = {Unit.Faction.LIGHT: 0, Unit.Faction.SHADOW: 0}
	zone_streak = {Unit.Faction.LIGHT: 0, Unit.Faction.SHADOW: 0}
	final_turns_left = -1
	last_captures = []
	for f in hands.keys():
		for i in Rules.START_HAND:
			hands[f].append(decks[f].pop_back())
	board_changed.emit(result, [])
	hands_changed.emit(Unit.Faction.LIGHT)
	hands_changed.emit(Unit.Faction.SHADOW)
	state = State.AWAITING_ACTION
	turn_started.emit(active)

func _build_deck(spec: Array) -> Array:
	var deck: Array = []
	for entry in spec:
		for i in entry[1]:
			deck.append(entry[0])
	for i in range(deck.size() - 1, 0, -1):  # seeded Fisher-Yates
		var j := _rng.randi_range(0, i)
		var tmp = deck[i]
		deck[i] = deck[j]
		deck[j] = tmp
	return deck

static func opponent(f: int) -> int:
	return Unit.Faction.SHADOW if f == Unit.Faction.LIGHT else Unit.Faction.LIGHT

# ---------------------------------------------------------------- actions

func try_draw() -> bool:
	if not _can_act():
		return false
	if hands[active].size() >= Rules.MAX_HAND:
		return _reject("Hand is full (%d cards)." % Rules.MAX_HAND)
	if decks[active].is_empty():
		return _reject("Your deck is empty.")
	hands[active].append(decks[active].pop_back())
	hands_changed.emit(active)
	_finish_action()
	return true

func try_place(hand_index: int, cell: Vector2i, facing := 0) -> bool:
	if not _can_act():
		return false
	if hand_index < 0 or hand_index >= hands[active].size():
		return _reject("No such card.")
	if not board.in_bounds(cell) or board.get_unit(cell) != null:
		return _reject("Target square must be empty.")
	var kind: int = hands[active][hand_index]
	board.set_unit(cell, Unit.new(kind, active, facing % 4))
	var probe := LightEngine.compute(board)  # suicide check
	if cell in LightEngine.find_violations(board, probe):
		board.remove_unit(cell)
		return _reject("%s would be captured instantly on %s." % [Unit.NAMES[kind], BoardState.cell_name(cell)])
	hands[active].remove_at(hand_index)
	hands_changed.emit(active)
	_finish_action()
	return true

func try_rotate(cell: Vector2i) -> bool:
	if not _can_act():
		return false
	var u: Unit = board.get_unit(cell) if board.in_bounds(cell) else null
	if u == null or u.faction != active or u.permanent:
		return _reject("Select one of your own units to rotate.")
	u.rotate_cw()
	_finish_action()
	return true

func confirm_handoff() -> void:
	if state != State.HANDOFF:
		return
	active = opponent(active)
	turn_number += 1
	state = State.AWAITING_ACTION
	turn_started.emit(active)

# --------------------------------------------------------------- internals

func _can_act() -> bool:
	if state != State.AWAITING_ACTION:
		action_rejected.emit("Not accepting actions right now.")
		return false
	return true

func _reject(msg: String) -> bool:
	action_rejected.emit(msg)
	return false

func _finish_action() -> void:
	state = State.RESOLVING
	var captured := _resolve_board()
	board_changed.emit(result, captured)
	var verdict := _check_victory()
	if not verdict.is_empty():
		state = State.GAME_OVER
		game_over.emit(verdict.winner, verdict.reason)
		return
	state = State.HANDOFF
	handoff_requested.emit(opponent(active))

func _resolve_board() -> Array:
	var s := settle(board)
	result = s.result
	last_captures = s.removed
	var captured: Array = []
	for e in s.removed:
		var u: Unit = e[1]
		if counts_as_loss(u):
			losses[u.faction] += 1
		captured.append(u)
	return captured

## Broken Veils don't count toward the capture limit unless Rules.BROKEN_VEILS_COUNT is set.
static func counts_as_loss(u: Unit) -> bool:
	return Rules.BROKEN_VEILS_COUNT or u.kind != Unit.Kind.VEIL

## Removes captured units until nothing else is captured (removing a Mirror can darken more units).
## Returns {result, removed: Array of [cell, Unit]}.
static func settle(b: BoardState) -> Dictionary:
	var removed: Array = []
	var r: LightEngine.Result
	while true:
		r = LightEngine.compute(b)
		var bad := LightEngine.find_violations(b, r)
		if bad.is_empty():
			break
		for c in bad:
			removed.append([c, b.remove_unit(c)])
	return {"result": r, "removed": removed}

# ---------------------------------------------------------------- previews
## What a placement would do, on a copy of the board. Returns {} if the action isn't possible, else
## {legal, board, result, unit, captured: Array of [cell, Unit]}. Illegal = captured instantly.
func preview_place(hand_index: int, cell: Vector2i, facing := 0) -> Dictionary:
	if state != State.AWAITING_ACTION or hand_index < 0 or hand_index >= hands[active].size():
		return {}
	if not board.in_bounds(cell) or board.get_unit(cell) != null:
		return {}
	var b := board.copy()
	var u := Unit.new(hands[active][hand_index], active, facing % 4)
	b.set_unit(cell, u)
	var legal := not (cell in LightEngine.find_violations(b, LightEngine.compute(b)))
	var s := settle(b)
	return {"legal": legal, "board": b, "result": s.result, "unit": u, "captured": s.removed}

## What rotating one of your units would do, on a copy of the board. Same keys as preview_place.
func preview_rotate(cell: Vector2i) -> Dictionary:
	if state != State.AWAITING_ACTION or not board.in_bounds(cell):
		return {}
	var real := board.get_unit(cell)
	if real == null or real.faction != active or real.permanent:
		return {}
	var b := board.copy()
	var u := b.get_unit(cell)
	u.rotate_cw()
	var s := settle(b)
	return {"legal": true, "board": b, "result": s.result, "unit": u, "captured": s.removed}

func _zone_holder() -> int:
	var first: int = result.tile_at(Rules.KEY_TILES[0])
	if first == LightEngine.Tile.DIM:
		return Unit.Faction.NEUTRAL
	for c in Rules.KEY_TILES:
		if result.tile_at(c) != first:
			return Unit.Faction.NEUTRAL
	return Unit.Faction.LIGHT if first == LightEngine.Tile.LIGHT else Unit.Faction.SHADOW

## Returns {} or {winner, reason}. Priority: capture > zone > territory > final count / turn limit.
func _check_victory() -> Dictionary:
	var losers: Array[int] = []
	for f in losses.keys():
		if losses[f] >= Rules.CAPTURE_LIMIT:
			losers.append(f)
	if not losers.is_empty():
		var loser: int = active if losers.size() > 1 or active in losers else losers[0]
		return {"winner": opponent(loser), "reason": "Piece capture: %d units lost." % Rules.CAPTURE_LIMIT}

	var holder := _zone_holder()
	for f in zone_streak.keys():
		if holder != f:
			zone_streak[f] = 0
		elif f == active:
			zone_streak[f] += 1
	for f in zone_streak.keys():
		if zone_streak[f] >= Rules.ZONE_TURNS:
			return {"winner": f, "reason": "Zone domination: held the centre for %d turns." % Rules.ZONE_TURNS}

	if LightEngine.count_tiles(result, LightEngine.Tile.LIGHT) >= Rules.TERRITORY_WIN:
		return {"winner": Unit.Faction.LIGHT, "reason": "Territorial control: Light holds %d+ tiles." % Rules.TERRITORY_WIN}
	if LightEngine.count_tiles(result, LightEngine.Tile.SHADOW) >= Rules.TERRITORY_WIN:
		return {"winner": Unit.Faction.SHADOW, "reason": "Territorial control: Shadow holds %d+ tiles." % Rules.TERRITORY_WIN}

	if decks[Unit.Faction.LIGHT].is_empty() and decks[Unit.Faction.SHADOW].is_empty():
		final_turns_left = Rules.FINAL_TURNS if final_turns_left < 0 else final_turns_left - 1
		if final_turns_left == 0:
			return _final_count("Out of cards")
	if turn_number >= Rules.TURN_LIMIT:
		return _final_count("Turn limit (%d)" % Rules.TURN_LIMIT)
	return {}

## Game ran out (cards or turns): more tiles wins, then fewer units lost, else a draw (winner NEUTRAL).
func _final_count(why: String) -> Dictionary:
	var lt := LightEngine.count_tiles(result, LightEngine.Tile.LIGHT)
	var st := LightEngine.count_tiles(result, LightEngine.Tile.SHADOW)
	var L := Unit.Faction.LIGHT
	var S := Unit.Faction.SHADOW
	var winner := Unit.Faction.NEUTRAL
	if lt != st:
		winner = L if lt > st else S
	elif losses[L] != losses[S]:
		winner = L if losses[L] < losses[S] else S
	return {"winner": winner, "reason": "%s. Final count: Light %d · Shadow %d tiles." % [why, lt, st]}
