extends Node

## 音效播放器：合成音频缓存 + 播放器池 + 循环 BGM。

const VOICES := 8

var muted := false

var _players: Array[AudioStreamPlayer] = []
var _cache := {}
var _next := 0
var _music: AudioStreamPlayer
var _music_wanted := false


func _ready() -> void:
	for i in VOICES:
		var player := AudioStreamPlayer.new()
		player.volume_db = -7.0
		add_child(player)
		_players.append(player)
	_music = AudioStreamPlayer.new()
	_music.volume_db = -24.0
	add_child(_music)


func play(sound: String) -> void:
	if muted:
		return
	if not _cache.has(sound):
		_cache[sound] = _create(sound)
	var stream: AudioStream = _cache[sound]
	if stream == null:
		return
	var player := _players[_next]
	_next = (_next + 1) % _players.size()
	player.stream = stream
	player.play()


func _create(sound: String) -> AudioStream:
	match sound:
		"eat":
			return Synth.eat()
		"powerup":
			return Synth.powerup()
		"death":
			return Synth.death()
		"shield":
			return Synth.shield_break()
		"count":
			return Synth.countdown()
		"go":
			return Synth.go()
	return null


func start_music() -> void:
	_music_wanted = true
	if muted or _music.playing:
		return
	if _music.stream == null:
		_music.stream = Synth.music()
	_music.play()


func set_muted(value: bool) -> void:
	muted = value
	if muted:
		_music.stop()
	elif _music_wanted:
		start_music()
