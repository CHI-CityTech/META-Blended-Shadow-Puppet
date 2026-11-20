class_name HUD
extends PanelContainer
## Side panel. Pure view: main.gd pushes a view-model dictionary into update().
## vm keys: turn, stats, message, acting, rotate_mode, facing_text, facing_enabled, hand (Array[int]), selected

signal draw_pressed
signal rotate_toggled(on: bool)
signal facing_pressed
signal new_game_pressed
signal menu_pressed
signal card_picked(index: int)

const CARD := preload("res://scenes/ui/card_button.tscn")

@onready var turn_label: Label = %TurnLabel
@onready var stats_label: Label = %StatsLabel
@onready var message_label: Label = %MessageLabel
@onready var draw_button: Button = %DrawButton
@onready var rotate_button: Button = %RotateButton
@onready var facing_button: Button = %FacingButton
@onready var new_game_button: Button = %NewGameButton
@onready var menu_button: Button = %MenuButton
@onready var hand_box: HFlowContainer = %Hand
@onready var rules_label: RichTextLabel = %RulesLabel

func _ready() -> void:
	rules_label.text = rules_text()
	draw_button.pressed.connect(func(): draw_pressed.emit())
	rotate_button.toggled.connect(func(on): rotate_toggled.emit(on))
	facing_button.pressed.connect(func(): facing_pressed.emit())
	new_game_button.pressed.connect(func(): new_game_pressed.emit())
	menu_button.pressed.connect(func(): menu_pressed.emit())

## Built from Rules so the numbers stay in sync with gameplay. Also shown by the start menu.
static func rules_text() -> String:
	var keys := ", ".join(Rules.KEY_TILES.map(func(c): return BoardState.cell_name(c)))
	return "\n".join([
		"[b]How to win[/b]",
		"• Capture: the other side loses %d units%s." % [Rules.CAPTURE_LIMIT, "" if Rules.BROKEN_VEILS_COUNT else " (broken Veils don't count)"],
		"• Centre: all four outlined tiles (%s) are your colour for %d of your turns." % [keys, Rules.ZONE_TURNS],
		"• Territory: %d of the %d inner tiles are your colour (the outer ring doesn't count)." % [Rules.TERRITORY_WIN, (BoardState.SIZE - 2) * (BoardState.SIZE - 2)],
		"• Out of cards: once both decks are empty, %d more turns are played (%d each); then more tiles wins." % [Rules.FINAL_TURNS, int(Rules.FINAL_TURNS / 2.0)],
		"• Turn limit: after turn %d, more tiles wins." % Rules.TURN_LIMIT,
		"",
		"[b]Your turn[/b]: one action. Draw a card (max %d in hand), place a card on an empty square, or rotate one of your units 90°." % Rules.MAX_HAND,
		"",
		"[b]Light[/b]  Emitter fires a beam · Mirror bends it · Prism splits it. Light units must stand on lit tiles or they are captured.",
		"",
		"[b]Shadow[/b]  Blocker stops beams and casts shadow behind it up to the first lit tile; beams hitting it from two different sides capture it. Veil darkens its 3x3 and beams die entering it (except corner emitter beams, which pass through); beams entering its darkness from two different directions break it.",
		"",
		"Corner emitters are neutral and permanent. You can't place a unit where it would be captured instantly.",
	])

func update(vm: Dictionary) -> void:
	turn_label.text = vm.turn
	stats_label.text = vm.stats
	message_label.text = vm.message
	draw_button.disabled = not vm.acting
	rotate_button.disabled = not vm.acting
	rotate_button.set_pressed_no_signal(vm.rotate_mode)
	facing_button.text = vm.facing_text
	facing_button.disabled = not vm.facing_enabled
	for c in hand_box.get_children():
		c.queue_free()
	for i in vm.hand.size():
		var card: CardButton = CARD.instantiate()
		hand_box.add_child(card)
		card.setup(vm.hand[i], i == vm.selected)
		card.pressed.connect(func(): card_picked.emit(i))
