class_name Sound
extends Node
## Plays the game's sounds. Every button in the game clicks automatically.
## Swap the files in assets/audio/ to change a sound; the names here stay the same.

const SFX := {
	"place": preload("res://assets/audio/place.wav"),
	"rotate": preload("res://assets/audio/rotate.wav"),
	"capture": preload("res://assets/audio/capture.wav"),
	"click": preload("res://assets/audio/click.wav"),
	"reject": preload("res://assets/audio/reject.wav"),
	"win": preload("res://assets/audio/win.wav"),
}
const VOLUME_DB := {"place": -4.0, "rotate": -6.0, "capture": -2.0, "click": -10.0, "reject": -6.0, "win": -3.0}
const VOICES := 8

@onready var ambient: AudioStreamPlayer = $Ambient
var _voices: Array[AudioStreamPlayer] = []

func _ready() -> void:
	for i in VOICES:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_voices.append(p)
	var loop := ambient.stream as AudioStreamWAV
	if loop != null:
		loop.loop_mode = AudioStreamWAV.LOOP_FORWARD
		loop.loop_end = int(loop.get_length() * loop.mix_rate)
	get_tree().node_added.connect(_hook_button)
	_hook_tree(get_tree().root)
	apply_settings()

func _exit_tree() -> void:  # stop playback before shutdown so the audio streams are released
	ambient.stop()
	for p in _voices:
		p.stop()

func play(name: String, pitch_jitter := 0.04) -> void:
	if not Settings.sound or not SFX.has(name):
		return
	for p in _voices:
		if not p.playing:
			p.stream = SFX[name]
			p.volume_db = VOLUME_DB.get(name, 0.0)
			p.pitch_scale = 1.0 + randf_range(-pitch_jitter, pitch_jitter)
			p.play()
			return

func apply_settings() -> void:
	if Settings.music and not ambient.playing:
		ambient.play()
	elif not Settings.music:
		ambient.stop()

func _hook_tree(n: Node) -> void:
	_hook_button(n)
	for c in n.get_children():
		_hook_tree(c)

func _hook_button(n: Node) -> void:
	if n is BaseButton and not (n as BaseButton).pressed.is_connected(_on_button):
		(n as BaseButton).pressed.connect(_on_button)

func _on_button() -> void:
	play("click", 0.0)
