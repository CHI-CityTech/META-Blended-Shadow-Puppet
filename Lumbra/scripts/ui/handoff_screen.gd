class_name HandoffScreen
extends CanvasLayer
## "Pass the device" screen. Hides the hand between turns and says what the last move captured.

signal ready_pressed

@onready var title_label: Label = %TitleLabel
@onready var ready_button: Button = %ReadyButton
@onready var notice_label: Label = %NoticeLabel

func _ready() -> void:
	visible = false
	ready_button.pressed.connect(_on_ready)

func open(faction_name: String, notice := "") -> void:
	title_label.text = "%s’s turn" % faction_name
	notice_label.text = notice
	notice_label.visible = notice != ""
	visible = true

func _on_ready() -> void:
	visible = false
	ready_pressed.emit()
