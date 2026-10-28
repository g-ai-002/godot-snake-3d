extends Node

## 存档：最高分与设置，写入 user://settings.cfg。

const PATH := "user://settings.cfg"

var best := 0
var board_size := 20
var speed_ms := 200
var level := 0
var theme_id := "neon"
var muted := false


func _ready() -> void:
	load_data()


func load_data() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return
	best = int(cfg.get_value("game", "best", best))
	board_size = int(cfg.get_value("game", "board_size", board_size))
	speed_ms = int(cfg.get_value("game", "speed_ms", speed_ms))
	level = int(cfg.get_value("game", "level", level))
	theme_id = String(cfg.get_value("game", "theme", theme_id))
	muted = bool(cfg.get_value("game", "muted", muted))


func save_data() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("game", "best", best)
	cfg.set_value("game", "board_size", board_size)
	cfg.set_value("game", "speed_ms", speed_ms)
	cfg.set_value("game", "level", level)
	cfg.set_value("game", "theme", theme_id)
	cfg.set_value("game", "muted", muted)
	cfg.save(PATH)
