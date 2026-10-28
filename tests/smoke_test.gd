extends Node

## 无头冒烟测试：godot --headless --path . res://tests/smoke_test.tscn
## 覆盖关卡布局、吃食物、道具、护盾、传送门、暂停与音效合成。

# 与 game.gd 中的 State 枚举顺序保持一致
const STATE_PLAYING := 2
const STATE_PAUSED := 3
const STATE_OVER := 4

var failures: Array[String] = []
var game
var flow_done := false


func _ready() -> void:
	await get_tree().process_frame
	_test_layouts()
	_test_synth()
	await _test_game_flow()
	_report()


func _check(condition: bool, message: String) -> void:
	if condition:
		print("  [PASS] ", message)
	else:
		failures.append(message)
		printerr("  [FAIL] ", message)


func _test_layouts() -> void:
	print("· 关卡布局")
	for size in [15, 20, 25]:
		for level in range(BoardLogic.level_count()):
			var layout := BoardLogic.build_layout(level, size, size)
			var walls: Dictionary = layout["walls"]
			var portals: Dictionary = layout["portals"]
			var body := BoardLogic.spawn_body(size, size)
			var spawn_blocked := false
			for cell in body:
				if walls.has(cell):
					spawn_blocked = true
			_check(not spawn_blocked, "关卡 %s/%d 出生点无墙" % [BoardLogic.LEVEL_NAMES[level], size])
			if level != BoardLogic.Level.OPEN and level != BoardLogic.Level.PORTALS:
				_check(walls.size() > 0, "关卡 %s/%d 生成了墙体" % [BoardLogic.LEVEL_NAMES[level], size])

			if level == BoardLogic.Level.PORTALS:
				_check(portals.size() == 4, "传送门关卡有 2 对入口")
				var symmetric := true
				for entry in portals:
					if portals[portals[entry]] != entry:
						symmetric = false
				_check(symmetric, "传送门成对互通")

	var cleared: Dictionary = BoardLogic.build_layout(BoardLogic.Level.CROSS, 20, 20)["walls"]
	BoardLogic.clear_spawn_row(cleared, 20, 20)
	var center := 10
	_check(not cleared.has(Vector2i(center, 10)), "出生行缓冲已清空")

	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var occupied := {Vector2i(0, 0): true}
	var cell := BoardLogic.random_cell(4, 4, occupied, rng)
	_check(cell != Vector2i(0, 0) and cell.x >= 0, "随机空格避开占用格")


func _test_synth() -> void:
	print("· 音频合成")
	var eat := Synth.eat()
	_check(eat != null and eat.data.size() > 0, "吃食物音效生成 PCM")
	var music := Synth.music()
	_check(music.loop_mode == AudioStreamWAV.LOOP_FORWARD, "BGM 为循环流")
	_check(music.get_length() > 6.0, "BGM 长度超过 6 秒")


func _test_game_flow() -> void:
	print("· 游戏流程")
	var saved_best := SaveData.best
	var saved_size := SaveData.board_size
	var saved_speed := SaveData.speed_ms
	var saved_level := SaveData.level
	var saved_theme := SaveData.theme_id
	var saved_muted := SaveData.muted
	var scene: PackedScene = load("res://scenes/main.tscn")
	game = scene.instantiate()
	add_child(game)
	await get_tree().process_frame

	# 固定棋盘尺寸，避免测试依赖本机保存的设置
	game.cols = 20
	game.rows = 20
	game.start_game()
	game.set_process(false)
	game.state = STATE_PLAYING
	game.countdown = 0.0
	game.cells = _cells([Vector2i(10, 10), Vector2i(9, 10), Vector2i(8, 10)])
	game.previous_cells = game.cells.duplicate()
	game.direction = Vector2i.RIGHT
	game.queued.clear()
	game.food_cell = Vector2i(11, 10)
	game.food_kind = ""
	game.score = 0
	game.effects.clear()
	game._tick()
	_check(game.cells.size() == 4, "吃到食物后长度 +1")
	_check(game.score == 10, "普通食物得 10 分")
	_check(game.cells[0] == Vector2i(11, 10), "蛇头前进一格")

	game.food_cell = Vector2i(12, 10)
	game.food_kind = "speed_up"
	game._tick()
	_check(game.effects.has("speed_up"), "拾取加速道具")
	_check(is_equal_approx(game.effects.get("speed_up", 0.0), 6.0), "加速持续 6 秒")
	_check(game._interval() < 0.2, "加速后步进变快")

	game.effects.clear()
	game.effects["magnet"] = 6.0
	game.cells = _cells([Vector2i(10, 12), Vector2i(9, 12), Vector2i(8, 12)])
	game.previous_cells = game.cells.duplicate()
	game.direction = Vector2i.RIGHT
	game.queued.clear()
	game.food_cell = Vector2i(11, 11)
	game.food_kind = ""
	var length_before: int = game.cells.size()
	game._tick()
	_check(game.cells.size() == length_before + 1, "磁铁吸附相邻食物")

	game.effects.clear()
	game.shield_charge = true
	game.cells = _cells([Vector2i(19, 5), Vector2i(18, 5), Vector2i(17, 5)])
	game.previous_cells = game.cells.duplicate()
	game.direction = Vector2i.RIGHT
	game.queued.clear()
	game._tick()
	_check(game.state == STATE_PLAYING, "护盾抵挡撞墙")
	_check(not game.shield_charge, "护盾消耗一次")

	game.level_index = BoardLogic.Level.PORTALS
	game._setup_board()
	game.state = STATE_PLAYING
	var mid: int = game.rows / 2
	game.cells = _cells([Vector2i(3, mid), Vector2i(4, mid), Vector2i(5, mid)])
	game.previous_cells = game.cells.duplicate()
	game.direction = Vector2i.LEFT
	game.queued.clear()
	game.food_cell = Vector2i(1, 1)
	game._tick()
	_check(game.cells[0] == Vector2i(game.cols - 3, mid), "进入传送门后出现在另一端")

	game.level_index = BoardLogic.Level.OPEN
	game._setup_board()
	game.state = STATE_PLAYING
	game.cells = _cells([Vector2i(19, 5), Vector2i(18, 5), Vector2i(17, 5)])
	game.previous_cells = game.cells.duplicate()
	game.direction = Vector2i.RIGHT
	game.queued.clear()
	game._tick()
	_check(game.state == STATE_OVER, "撞墙后游戏结束")
	Engine.time_scale = 1.0

	game.state = STATE_PLAYING
	game.toggle_pause()
	_check(game.state == STATE_PAUSED, "暂停生效")
	game.toggle_pause()
	_check(game.state == STATE_PLAYING, "继续生效")

	game.effects["shield"] = 0.1
	game.shield_charge = true
	game._tick_effects(1.0)
	_check(game.effects.is_empty() and not game.shield_charge, "道具到期后清除")

	var before_cols: int = game.cols
	game.state = 0
	game._cycle_option("size")
	_check(game.cols != before_cols, "切换棋盘尺寸重建布局")
	game._cycle_option("level")
	_check(game.walls.size() > 0 or game.level_index == BoardLogic.Level.OPEN, "切换关卡生效")
	var before_theme: String = game.theme_id
	game._cycle_option("theme")
	_check(game.theme_id != before_theme, "切换主题生效")

	game.start_game()
	_check(game.score == 0 and game.cells.size() == 3, "重开后分数与长度重置")
	Engine.time_scale = 1.0
	SaveData.best = saved_best
	SaveData.board_size = saved_size
	SaveData.speed_ms = saved_speed
	SaveData.level = saved_level
	SaveData.theme_id = saved_theme
	SaveData.muted = saved_muted
	SaveData.save_data()
	flow_done = true


func _cells(values: Array) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for value in values:
		result.append(value)
	return result


func _report() -> void:
	if not flow_done:
		failures.append("游戏流程未执行完")
	print("")
	if failures.is_empty():
		print("全部通过")
		get_tree().quit(0)
	else:
		printerr("失败 %d 项：" % failures.size())
		for failure in failures:
			printerr(" - ", failure)
		get_tree().quit(1)
