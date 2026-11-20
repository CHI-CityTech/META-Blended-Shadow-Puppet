extends Node2D
## Thin controller: owns the selection state and wires TurnManager <-> Board <-> HUD <-> overlays.
## Starts on the StartMenu; Play begins a game, the HUD's Menu button returns to it.

const ARROWS := ["↑", "→", "↓", "←"]

@onready var board_view: BoardView = $Board
@onready var tm: TurnManager = $TurnManager
@onready var hud: HUD = $UI/HUD
@onready var handoff: HandoffScreen = $HandoffScreen
@onready var game_over: GameOverScreen = $GameOverScreen
@onready var start_menu: StartMenu = $StartMenu
@onready var ui: CanvasLayer = $UI
@onready var post_fx: CanvasLayer = $PostFX
@onready var sound: Sound = $Sound

var selected := -1       # hand index of the card being placed
var rotate_mode := false
var facing := 0
var msg := ""
var notice := ""         # what the last action captured; shown on the handoff screen and into the next turn
var hover := Vector2i(-1, -1)
var preview_hint := ""   # what the hovered move would do; overrides the other messages

func _ready() -> void:
	board_view.cell_clicked.connect(_on_cell)
	board_view.piece_placed.connect(func(): sound.play("place"))
	board_view.piece_rotated.connect(func(): sound.play("rotate"))
	board_view.piece_captured.connect(func(): sound.play("capture"))
	board_view.cell_hovered.connect(func(c):
		hover = c
		_update_preview())
	hud.card_picked.connect(_on_card_picked)
	hud.draw_pressed.connect(func(): _after(tm.try_draw()))
	hud.rotate_toggled.connect(_on_rotate_toggled)
	hud.facing_pressed.connect(_on_facing_pressed)
	hud.new_game_pressed.connect(func(): tm.new_game())
	hud.menu_pressed.connect(_open_menu)
	start_menu.play_pressed.connect(_start_game)
	start_menu.settings_changed.connect(_apply_settings)
	handoff.ready_pressed.connect(tm.confirm_handoff)
	game_over.replay_pressed.connect(func(): tm.new_game())

	tm.board_changed.connect(_on_board_changed)
	tm.hands_changed.connect(func(_f): _refresh())
	tm.turn_started.connect(_on_turn_started)
	tm.action_rejected.connect(func(m):
		msg = m
		sound.play("reject", 0.0)
		_refresh())
	tm.handoff_requested.connect(_on_handoff_requested)
	tm.game_over.connect(_on_game_over)
	Settings.load_settings()
	Settings.apply_window()
	_apply_settings()
	_open_menu()

# ----------------------------------------------------------------- menu

func _open_menu() -> void:
	board_view.clear_preview()
	board_view.visible = false
	ui.visible = false
	handoff.visible = false
	game_over.visible = false
	start_menu.open()

func _start_game() -> void:
	start_menu.visible = false
	handoff.visible = false
	game_over.visible = false
	board_view.visible = true
	ui.visible = true
	tm.new_game()

func _apply_settings() -> void:
	post_fx.visible = Settings.effects
	sound.apply_settings()

func _pause_after_move() -> float:
	return Look.HANDOFF_DELAY if Settings.animations else 0.0

# ----------------------------------------------------------- tm signals

func _on_board_changed(result: LightEngine.Result, captured: Array) -> void:
	board_view.refresh(tm.board, result)
	preview_hint = ""
	notice = _capture_text(tm.last_captures) if captured.size() > 0 else ""
	if notice != "":
		msg = notice
	_refresh()

func _on_turn_started(_faction: int) -> void:
	selected = -1
	rotate_mode = false
	facing = 0
	msg = notice  # tell the next player what they just lost (or took)
	notice = ""
	_update_preview()

func _on_handoff_requested(next: int) -> void:
	await get_tree().create_timer(_pause_after_move()).timeout  # let place / capture animations play
	if tm.state == TurnManager.State.HANDOFF:  # skip if a new game started meanwhile
		handoff.open(Unit.FACTION_NAMES[next], notice)

func _on_game_over(winner: int, reason: String) -> void:
	await get_tree().create_timer(_pause_after_move()).timeout
	if tm.state != TurnManager.State.GAME_OVER:
		return
	sound.play("win", 0.0)
	game_over.open(winner, reason, "Turns: %d · Units lost: Light %d, Shadow %d · Tiles: Light %d, Shadow %d" % [
		tm.turn_number, tm.losses[Unit.Faction.LIGHT], tm.losses[Unit.Faction.SHADOW],
		_tiles(LightEngine.Tile.LIGHT), _tiles(LightEngine.Tile.SHADOW)])
	_refresh()

# ------------------------------------------------------------ hud input

func _on_card_picked(i: int) -> void:
	selected = -1 if selected == i else i
	rotate_mode = false
	msg = ""
	_update_preview()

func _on_rotate_toggled(on: bool) -> void:
	rotate_mode = on
	selected = -1
	msg = ""
	_update_preview()

func _on_facing_pressed() -> void:
	facing = (facing + 1) % 4
	_update_preview()

func _on_cell(cell: Vector2i) -> void:
	if tm.state != TurnManager.State.AWAITING_ACTION:
		return
	if rotate_mode:
		_after(tm.try_rotate(cell))
	elif selected >= 0:
		_after(tm.try_place(selected, cell, facing))

func _after(ok: bool) -> void:
	if ok:
		selected = -1
		rotate_mode = false
		msg = ""

# --------------------------------------------------------------- helpers

## Shows what the hovered placement / rotation would do, or clears the preview.
func _update_preview() -> void:
	var p := {}
	if tm.state == TurnManager.State.AWAITING_ACTION and hover.x >= 0:
		if rotate_mode:
			p = tm.preview_rotate(hover)
		elif selected >= 0:
			p = tm.preview_place(selected, hover, facing)
	if p.is_empty():
		board_view.clear_preview()
		preview_hint = ""
	else:
		board_view.show_preview(p, hover)
		if not p.legal:
			preview_hint = "Not allowed: the %s would be captured instantly on %s." % [Unit.NAMES[p.unit.kind], BoardState.cell_name(hover)]
		elif not p.captured.is_empty():
			preview_hint = "This move would capture: %s" % _capture_text(p.captured).trim_prefix("Captured: ")
		else:
			preview_hint = ""
	_refresh()

## e.g. "Captured: Shadow Blocker on E4, Shadow Veil on G4 (broken, doesn't count)."
func _capture_text(caps: Array) -> String:
	var parts: Array[String] = []
	for e in caps:
		var u: Unit = e[1]
		var note := "" if TurnManager.counts_as_loss(u) else " (broken, doesn't count)"
		parts.append("%s %s on %s%s" % [Unit.FACTION_NAMES[u.faction], Unit.NAMES[u.kind], BoardState.cell_name(e[0]), note])
	return "Captured: %s." % ", ".join(parts)

func _tiles(tile: int) -> int:
	return LightEngine.count_tiles(tm.result, tile)

func _refresh() -> void:
	if tm.board == null:
		return
	var acting := tm.state == TurnManager.State.AWAITING_ACTION
	var hand: Array = tm.hands[tm.active] if acting else []
	var kind := -1
	if selected >= 0 and selected < hand.size():
		kind = hand[selected]
	var L := Unit.Faction.LIGHT
	var S := Unit.Faction.SHADOW
	var hint := "Draw, pick a card to place, or rotate a unit."
	if rotate_mode:
		hint = "Click one of your units to rotate it."
	elif kind >= 0:
		hint = "Click an empty square to place."
	var facing_text: String = "Facing " + ARROWS[facing]
	if kind == Unit.Kind.MIRROR:
		facing_text = "Facing " + ("\\" if facing % 2 else "/")
	hud.update({
		"turn": "Turn %d/%d: %s" % [tm.turn_number, Rules.TURN_LIMIT, Unit.FACTION_NAMES[tm.active]],
		"stats": "Light: deck %d, lost %d/%d   Shadow: deck %d, lost %d/%d\nTiles  Light %d/%d · Shadow %d/%d   Centre  L %d/%d · S %d/%d%s" % [
			tm.decks[L].size(), tm.losses[L], Rules.CAPTURE_LIMIT, tm.decks[S].size(), tm.losses[S], Rules.CAPTURE_LIMIT,
			_tiles(LightEngine.Tile.LIGHT), Rules.TERRITORY_WIN, _tiles(LightEngine.Tile.SHADOW), Rules.TERRITORY_WIN,
			tm.zone_streak[L], Rules.ZONE_TURNS, tm.zone_streak[S], Rules.ZONE_TURNS,
			"\nDecks empty: %d turns left" % tm.final_turns_left if tm.final_turns_left >= 0 else ""],
		"message": preview_hint if preview_hint != "" else (msg if msg != "" else hint),
		"acting": acting,
		"rotate_mode": rotate_mode,
		"facing_text": facing_text,
		"facing_enabled": kind >= 0,
		"hand": hand,
		"selected": selected,
	})
