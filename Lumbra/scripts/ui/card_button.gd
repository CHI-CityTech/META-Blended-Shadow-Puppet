class_name CardButton
extends Button
## One card in the hand.

func setup(kind: int, is_selected: bool) -> void:
	text = "%s\n%s" % [Unit.NAMES[kind], Unit.HINTS[kind]]
	set_pressed_no_signal(is_selected)
