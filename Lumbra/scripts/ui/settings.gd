class_name Settings
extends RefCounted
## Player options from the start menu, saved to user://settings.cfg.

const PATH := "user://settings.cfg"

static var fullscreen := false
static var effects := true      # vignette + film grain (scenes/fx/post_fx.tscn)
static var animations := true   # piece animations + the pause before the handoff screen
static var sound := true        # sound effects
static var music := true        # ambient loop

static func load_settings() -> void:
	var cf := ConfigFile.new()
	if cf.load(PATH) != OK:
		return
	fullscreen = cf.get_value("display", "fullscreen", fullscreen)
	effects = cf.get_value("display", "effects", effects)
	animations = cf.get_value("display", "animations", animations)
	sound = cf.get_value("audio", "sound", sound)
	music = cf.get_value("audio", "music", music)

static func save_settings() -> void:
	var cf := ConfigFile.new()
	cf.set_value("display", "fullscreen", fullscreen)
	cf.set_value("display", "effects", effects)
	cf.set_value("display", "animations", animations)
	cf.set_value("audio", "sound", sound)
	cf.set_value("audio", "music", music)
	cf.save(PATH)

static func apply_window() -> void:
	if DisplayServer.get_name() == "headless":
		return
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_MAXIMIZED)
