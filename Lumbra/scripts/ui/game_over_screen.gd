class_name GameOverScreen
extends CanvasLayer
## Winner screen with Replay / View final board.

signal replay_pressed
signal view_board_pressed

const TINT := {Unit.Faction.NEUTRAL: Color(0.14, 0.14, 0.17, 0.95), Unit.Faction.LIGHT: Color(0.43, 0.31, 0.0, 0.94), Unit.Faction.SHADOW: Color(0.12, 0.07, 0.26, 0.95)}
const GLYPH := {Unit.Faction.NEUTRAL: "◐", Unit.Faction.LIGHT: "☼", Unit.Faction.SHADOW: "◉"}

@onready var dim: ColorRect = %Dim
@onready var glyph_label: Label = %GlyphLabel
@onready var title_label: Label = %TitleLabel
@onready var reason_label: Label = %ReasonLabel
@onready var stats_label: Label = %StatsLabel
@onready var replay_button: Button = %ReplayButton
@onready var view_button: Button = %ViewBoardButton

func _ready() -> void:
	visible = false
	replay_button.pressed.connect(func():
		visible = false
		replay_pressed.emit())
	view_button.pressed.connect(func():
		visible = false
		view_board_pressed.emit())

func open(winner: int, reason: String, stats: String) -> void:
	dim.color = TINT[winner]
	glyph_label.text = GLYPH[winner]
	title_label.text = "Draw" if winner == Unit.Faction.NEUTRAL else "%s wins" % Unit.FACTION_NAMES[winner]
	reason_label.text = reason
	stats_label.text = stats
	visible = true
