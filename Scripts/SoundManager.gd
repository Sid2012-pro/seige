extends Node

var sounds := {
	"purchase": preload("res://Assets/ka_ching.mp3"),
	"place_tower": preload("res://Assets/tower_place.mp3"),
	"upgrade": preload("res://Assets/upload.mp3"),
	"enemy_die": preload("res://Assets/enemy_die.mp3")
}
var bgm_player: AudioStreamPlayer
func _ready() -> void:
	bgm_player = AudioStreamPlayer.new()
	bgm_player.stream = preload("res://Assets/Unholy Knight.mp3")
	bgm_player.volume_db = linear_to_db(0.30)
	bgm_player.autoplay = true
	bgm_player.bus = "Music"
	add_child(bgm_player)

func play(sound_name: String) -> void:
	if sounds.has(sound_name):
		var player = AudioStreamPlayer.new()
		player.stream = sounds[sound_name]
		player.bus = "SFX"
		add_child(player)
		player.play()
		player.finished.connect(player.queue_free)
