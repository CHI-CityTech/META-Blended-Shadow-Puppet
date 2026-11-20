class_name StartMenu
extends CanvasLayer
## Title screen: Play, Rules, Options, Quit. Rules and Options are pages inside this scene.

signal play_pressed
signal settings_changed

@onready var title_label: Label = %TitleLabel
@onready var title_glow: TextureRect = %TitleGlow
@onready var main_page: Control = %MainPage
@onready var rules_page: Control = %RulesPage
@onready var options_page: Control = %OptionsPage
@onready var play_button: Button = %PlayButton
@onready var rules_button: Button = %RulesButton
@onready var options_button: Button = %OptionsButton
@onready var quit_button: Button = %QuitButton
@onready var rules_text: RichTextLabel = %RulesText
@onready var fullscreen_check: CheckButton = %FullscreenCheck
@onready var effects_check: CheckButton = %EffectsCheck
@onready var animations_check: CheckButton = %AnimationsCheck
@onready var sound_check: CheckButton = %SoundCheck
@onready var music_check: CheckButton = %MusicCheck

func _ready() -> void:
	rules_text.text = HUD.rules_text()
	play_button.pressed.connect(func(): play_pressed.emit())
	rules_button.pressed.connect(func(): _show(rules_page))
	options_button.pressed.connect(func(): _show(options_page))
	quit_button.visible = not OS.has_feature("web")  # browsers can't close the tab
	quit_button.pressed.connect(func(): get_tree().quit())
	for back in [%RulesBack, %OptionsBack]:
		(back as Button).pressed.connect(func(): _show(main_page))
	fullscreen_check.toggled.connect(func(on): _apply_option("fullscreen", on))
	effects_check.toggled.connect(func(on): _apply_option("effects", on))
	animations_check.toggled.connect(func(on): _apply_option("animations", on))
	sound_check.toggled.connect(func(on): _apply_option("sound", on))
	music_check.toggled.connect(func(on): _apply_option("music", on))
	# slow breathing glow behind the title
	var t := create_tween().set_loops()
	t.tween_property(title_glow, "modulate:a", 1.0, 1.8).set_trans(Tween.TRANS_SINE)
	t.tween_property(title_glow, "modulate:a", 0.55, 1.8).set_trans(Tween.TRANS_SINE)

func open() -> void:
	fullscreen_check.set_pressed_no_signal(Settings.fullscreen)
	effects_check.set_pressed_no_signal(Settings.effects)
	animations_check.set_pressed_no_signal(Settings.animations)
	sound_check.set_pressed_no_signal(Settings.sound)
	music_check.set_pressed_no_signal(Settings.music)
	_show(main_page)
	visible = true
	play_button.grab_focus()

func _unhandled_input(e: InputEvent) -> void:
	if visible and e.is_action_pressed("ui_cancel") and not main_page.visible:
		_show(main_page)
		get_viewport().set_input_as_handled()

func _show(page: Control) -> void:
	for p in [main_page, rules_page, options_page]:
		p.visible = p == page

func _apply_option(key: String, on: bool) -> void:
	match key:
		"fullscreen":
			Settings.fullscreen = on
			Settings.apply_window()
		"effects":
			Settings.effects = on
		"animations":
			Settings.animations = on
		"sound":
			Settings.sound = on
		"music":
			Settings.music = on
	Settings.save_settings()
	settings_changed.emit()
