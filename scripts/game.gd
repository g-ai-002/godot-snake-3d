extends Node3D

## 贪吃蛇 3D 主控制器：网格逻辑、状态机、镜头、光照环境与 3D 特效调度。

const COUNTDOWN_TIME := 3.0
const POWERUP_CHANCE := 0.28
const BODY_Y := 0.46
const POPUP_POOL_SIZE := 8
const BURST_POOL_SIZE := 6
const BURST_AMOUNT := 44

const EFFECT_DURATIONS := {
	"speed_up": 6.0,
	"slow_down": 5.0,
	"shield": 10.0,
	"magnet": 6.0,
	"double": 8.0,
}
const EFFECT_LABELS := {
	"speed_up": "加速",
	"slow_down": "减速",
	"shield": "护盾",
	"magnet": "磁铁",
	"double": "双倍",
}
const POWERUPS := ["speed_up", "slow_down", "shield", "magnet", "double"]
const POWERUP_COLORS := {
	"speed_up": Color("#ffd166"),
	"slow_down": Color("#6ec6ff"),
	"shield": Color("#c09bff"),
	"magnet": Color("#ff8fd1"),
	"double": Color("#ffe066"),
}

const SIZES := [15, 20, 25]
const SIZE_LABELS := ["小 15×15", "中 20×20", "大 25×25"]
const SPEEDS := [300, 200, 100]
const SPEED_LABELS := ["慢速", "中速", "快速"]

enum State { MENU, COUNTDOWN, PLAYING, PAUSED, OVER }

var state := State.MENU
var cols := 20
var rows := 20
var speed_ms := 200
var level_index := 0
var theme_id := "neon"
var colors: Dictionary

var cells: Array[Vector2i] = []
var previous_cells: Array[Vector2i] = []
var direction := Vector2i.RIGHT
var queued: Array[Vector2i] = []
var food_cell := Vector2i(-1, -1)
var food_kind := ""
var walls := {}
var portals := {}

var score := 0
var best := 0
var effects := {}
var shield_charge := false
var tick_accum := 0.0
var countdown := 0.0
var go_timer := 0.0
var hud_accum := 0.0
var dead := false

var rng := RandomNumberGenerator.new()

var _best_at_start := 0
var _touch_origin := Vector2.ZERO
var _orbiting := false
var _environment: Environment
var _sky_material: ProceduralSkyMaterial
var _key_light: DirectionalLight3D
var _fill_light: OmniLight3D

@onready var board_view: BoardView = $Board
@onready var snake_view: SnakeView = $Snake
@onready var food_view: FoodView = $Food
@onready var rig: CameraRig = $CameraRig
@onready var hud: HudView = $UI/HUD


func _ready() -> void:
	rng.randomize()
	_load_settings()
	_build_environment()
	_warm_effects()

	hud.start_pressed.connect(start_game)
	hud.restart_pressed.connect(start_game)
	hud.resume_pressed.connect(toggle_pause)
	hud.menu_pressed.connect(enter_menu)
	hud.pause_pressed.connect(toggle_pause)
	hud.mute_pressed.connect(_toggle_mute)
	hud.option_cycled.connect(_cycle_option)

	_apply_theme()
	_setup_board()
	_spawn_food()
	_update_menu_texts()
	hud.set_muted(SaveData.muted)
	hud.set_best(best)
	hud.update_stats(0, best, cells.size())
	hud.enter_menu()


func _load_settings() -> void:
	cols = SaveData.board_size
	if not SIZES.has(cols):
		cols = 20
	rows = cols
	speed_ms = SaveData.speed_ms
	if not SPEEDS.has(speed_ms):
		speed_ms = 200
	level_index = clampi(SaveData.level, 0, BoardLogic.level_count() - 1)
	theme_id = SaveData.theme_id
	if not Palette.DATA.has(theme_id):
		theme_id = "neon"
	best = SaveData.best


func _build_environment() -> void:
	_environment = Environment.new()
	_environment.background_mode = Environment.BG_SKY
	_sky_material = ProceduralSkyMaterial.new()
	var sky := Sky.new()
	sky.sky_material = _sky_material
	_environment.sky = sky
	_environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	_environment.ambient_light_sky_contribution = 0.85
	_environment.ambient_light_energy = 0.9
	_environment.tonemap_mode = Environment.TONE_MAPPER_ACES
	_environment.tonemap_exposure = 1.05
	_environment.glow_enabled = true
	_environment.glow_intensity = 0.85
	_environment.glow_bloom = 0.12
	_environment.glow_hdr_threshold = 0.9
	_environment.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	_environment.ssao_enabled = true
	_environment.ssao_radius = 1.6
	_environment.ssao_intensity = 1.8
	_environment.fog_enabled = true
	_environment.fog_density = 0.008
	_environment.fog_sky_affect = 0.25
	_environment.adjustment_enabled = true
	_environment.adjustment_saturation = 1.06
	_environment.adjustment_contrast = 1.03

	var world := WorldEnvironment.new()
	world.environment = _environment
	add_child(world)

	_key_light = DirectionalLight3D.new()
	_key_light.rotation_degrees = Vector3(-52.0, -38.0, 0.0)
	_key_light.light_energy = 1.25
	_key_light.light_color = Color("#fff1dd")
	_key_light.shadow_enabled = true
	_key_light.directional_shadow_max_distance = 90.0
	_key_light.directional_shadow_blend_splits = true
	add_child(_key_light)

	_fill_light = OmniLight3D.new()
	_fill_light.position = Vector3(0.0, 11.0, 0.0)
	_fill_light.omni_range = 70.0
	_fill_light.light_energy = 0.75
	add_child(_fill_light)


func _process(delta: float) -> void:
	match state:
		State.MENU:
			rig.target_yaw += delta * 0.12
		State.COUNTDOWN:
			_process_countdown(delta)
		State.PLAYING:
			_tick_effects(delta)
			tick_accum += delta
			var interval := _interval()
			var guard := 0
			while tick_accum >= interval and guard < 4:
				tick_accum -= interval
				_tick()
				guard += 1
				if state != State.PLAYING:
					break
			if state == State.PLAYING:
				var progress := clampf(tick_accum / maxf(interval, 0.001), 0.0, 1.0)
				snake_view.update_snake(
					previous_cells, cells, progress, direction, dead, shield_charge
				)
		_:
			pass

	if go_timer > 0.0:
		go_timer -= delta
		if go_timer <= 0.0:
			hud.hide_countdown()

	_update_hud(delta)


# ---------------------------------------------------------------- 流程

func start_game() -> void:
	Engine.time_scale = 1.0
	dead = false
	score = 0
	_best_at_start = best
	effects.clear()
	shield_charge = false
	tick_accum = 0.0
	go_timer = 0.0
	rig.add_shake(0.0)

	_setup_board()
	_spawn_food()

	state = State.COUNTDOWN
	countdown = COUNTDOWN_TIME
	hud.enter_game()
	hud.update_stats(score, best, cells.size())
	hud.set_effects(effects)
	hud.set_best(best)
	hud.show_countdown(str(int(COUNTDOWN_TIME)))
	Sfx.play("count")
	Sfx.start_music()
	snake_view.update_snake(cells, cells, 1.0, direction, false, false)


func enter_menu() -> void:
	Engine.time_scale = 1.0
	state = State.MENU
	dead = false
	effects.clear()
	shield_charge = false
	SaveData.save_data()
	_setup_board()
	_spawn_food()
	_update_menu_texts()
	hud.set_best(best)
	hud.enter_menu()


func toggle_pause() -> void:
	if state == State.PLAYING:
		state = State.PAUSED
		hud.show_pause()
	elif state == State.PAUSED:
		state = State.PLAYING
		hud.hide_pause()


func _process_countdown(delta: float) -> void:
	var before := int(ceil(countdown))
	countdown -= delta
	if countdown <= 0.0:
		state = State.PLAYING
		tick_accum = 0.0
		hud.show_countdown("GO!")
		go_timer = 0.55
		Sfx.play("go")
		return
	var now := int(ceil(countdown))
	if now != before and now >= 1:
		hud.show_countdown(str(now))
		Sfx.play("count")


func _setup_board() -> void:
	var layout := BoardLogic.build_layout(level_index, cols, rows)
	walls = layout["walls"]
	portals = layout["portals"]
	BoardLogic.clear_spawn_row(walls, cols, rows)

	cells = BoardLogic.spawn_body(cols, rows)
	previous_cells = cells.duplicate()
	direction = Vector2i.RIGHT
	queued.clear()
	food_kind = ""
	dead = false

	board_view.configure(cols, rows, walls, portals, colors)
	snake_view.configure(cols, rows, colors)
	snake_view.update_snake(cells, cells, 1.0, direction, false, false)
	food_view.configure(food_kind, colors)
	rig.configure(cols, rows)


func _spawn_food() -> void:
	var occupied := {}
	for cell in cells:
		occupied[cell] = true
	for wall in walls:
		occupied[wall] = true
	for portal in portals:
		occupied[portal] = true

	food_cell = BoardLogic.random_cell(cols, rows, occupied, rng)
	if food_cell.x < 0:
		food_cell = Vector2i.ZERO
	food_kind = ""
	if rng.randf() < POWERUP_CHANCE:
		food_kind = POWERUPS[rng.randi_range(0, POWERUPS.size() - 1)]

	food_view.configure(food_kind, colors)
	food_view.position = cell_world(food_cell) + Vector3(0.0, 0.55, 0.0)


# ---------------------------------------------------------------- 网格推进

func _interval() -> float:
	var base := float(speed_ms) / 1000.0
	if effects.has("speed_up"):
		return maxf(0.06, base * 0.65)
	if effects.has("slow_down"):
		return minf(0.6, base * 1.5)
	return base


func _tick() -> void:
	previous_cells = cells.duplicate()

	if not queued.is_empty():
		var next_direction: Vector2i = queued.pop_front()
		if next_direction != -direction:
			direction = next_direction

	var new_head: Vector2i = cells[0] + direction
	if portals.has(new_head):
		new_head = portals[new_head]
		_burst(cell_world(cells[0]) + Vector3(0.0, 0.3, 0.0), colors["special"], 14, 4.0)

	if _blocked(new_head):
		if shield_charge:
			shield_charge = false
			effects.erase("shield")
			hud.set_effects(effects)
			rig.add_shake(0.35)
			Sfx.play("shield")
			return
		_die()
		return

	var ate := new_head == food_cell
	if not ate and effects.has("magnet") and _manhattan(new_head, food_cell) <= 1:
		ate = true

	cells.insert(0, new_head)
	if not ate:
		cells.pop_back()

	if not ate:
		return

	var gain := 20 if effects.has("double") else 10
	score += gain
	if score > best:
		best = score
		SaveData.best = best

	var world := cell_world(new_head) + Vector3(0.0, 0.3, 0.0)
	_spawn_popup("+%d" % gain, world)
	_burst(world, _food_color(), 24, 5.0)

	if food_kind == "":
		Sfx.play("eat")
	else:
		Sfx.play("powerup")
		_activate(food_kind)
		_spawn_popup(EFFECT_LABELS[food_kind], world + Vector3(0.0, 0.55, 0.0))

	_spawn_food()


func _blocked(head: Vector2i) -> bool:
	if head.x < 0 or head.y < 0 or head.x >= cols or head.y >= rows:
		return true
	if walls.has(head):
		return true
	for i in range(0, cells.size() - 1):
		if cells[i] == head:
			return true
	return false


func _manhattan(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)


func _die() -> void:
	state = State.OVER
	dead = true
	SaveData.best = best
	SaveData.save_data()
	Sfx.play("death")
	hud.flash(Color(colors["danger"], 0.55))
	rig.add_shake(1.1)
	_burst(cell_world(cells[0]) + Vector3(0.0, 0.4, 0.0), colors["danger"], 40, 6.5)
	snake_view.update_snake(previous_cells, cells, 1.0, direction, true, false)

	Engine.time_scale = 0.45
	await get_tree().create_timer(0.5, true, false, true).timeout
	Engine.time_scale = 1.0
	if not is_inside_tree():
		return
	hud.show_game_over(score, best, score > _best_at_start and score > 0)


func _activate(kind: String) -> void:
	if kind == "speed_up":
		effects.erase("slow_down")
	elif kind == "slow_down":
		effects.erase("speed_up")
	effects[kind] = EFFECT_DURATIONS[kind]
	if kind == "shield":
		shield_charge = true
	hud.set_effects(effects)


func _tick_effects(delta: float) -> void:
	if effects.is_empty():
		return
	var expired: Array[String] = []
	for kind in effects:
		effects[kind] = float(effects[kind]) - delta
		if effects[kind] <= 0.0:
			expired.append(kind)
	for kind in expired:
		effects.erase(kind)
		if kind == "shield":
			shield_charge = false


# ---------------------------------------------------------------- 输入

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and _orbiting:
		rig.orbit(event.relative)
		return
	if event is InputEventKey and event.pressed and not event.echo:
		_handle_key(event.keycode)
	elif event is InputEventMouseButton:
		_handle_mouse(event)
	elif event is InputEventScreenTouch:
		if event.pressed:
			_touch_origin = event.position
		else:
			_swipe(_touch_origin, event.position)
	elif event is InputEventScreenDrag and not event.pressed:
		pass


func _handle_mouse(event: InputEventMouseButton) -> void:
	match event.button_index:
		MOUSE_BUTTON_RIGHT:
			_orbiting = event.pressed
		MOUSE_BUTTON_WHEEL_UP:
			if event.pressed:
				rig.zoom(-1)
		MOUSE_BUTTON_WHEEL_DOWN:
			if event.pressed:
				rig.zoom(1)
		MOUSE_BUTTON_LEFT:
			if event.pressed:
				_touch_origin = event.position
			else:
				_swipe(_touch_origin, event.position)


func _handle_key(keycode: int) -> void:
	match keycode:
		KEY_UP, KEY_W:
			_queue(Vector2i.UP)
		KEY_DOWN, KEY_S:
			_queue(Vector2i.DOWN)
		KEY_LEFT, KEY_A:
			_queue(Vector2i.LEFT)
		KEY_RIGHT, KEY_D:
			_queue(Vector2i.RIGHT)
		KEY_Q:
			rig.target_yaw += 0.2
		KEY_E:
			rig.target_yaw -= 0.2
		KEY_SPACE:
			if state == State.PLAYING or state == State.PAUSED:
				toggle_pause()
		KEY_ESCAPE:
			if state == State.PLAYING or state == State.PAUSED:
				toggle_pause()
			elif state == State.OVER:
				enter_menu()
		KEY_ENTER, KEY_KP_ENTER:
			if state == State.MENU or state == State.OVER:
				start_game()
		KEY_R:
			if state != State.MENU:
				start_game()
		KEY_M:
			_toggle_mute()


func _queue(new_direction: Vector2i) -> void:
	if state != State.COUNTDOWN and state != State.PLAYING:
		return
	var last := direction
	if not queued.is_empty():
		last = queued[queued.size() - 1]
	if new_direction == last or new_direction == -last:
		return
	if queued.size() >= 2:
		queued.pop_back()
	queued.append(new_direction)


func _swipe(from: Vector2, to: Vector2) -> void:
	var delta := to - from
	if delta.length() < 32.0:
		return
	if absf(delta.x) > absf(delta.y):
		_queue(Vector2i.RIGHT if delta.x > 0.0 else Vector2i.LEFT)
	else:
		_queue(Vector2i.DOWN if delta.y > 0.0 else Vector2i.UP)


# ---------------------------------------------------------------- 设置

func _cycle_option(key: String) -> void:
	match key:
		"size":
			var size_index := SIZES.find(cols)
			size_index = (size_index + 1) % SIZES.size()
			cols = SIZES[size_index]
			rows = cols
			SaveData.board_size = cols
		"speed":
			var speed_index := SPEEDS.find(speed_ms)
			speed_index = (speed_index + 1) % SPEEDS.size()
			speed_ms = SPEEDS[speed_index]
			SaveData.speed_ms = speed_ms
		"level":
			level_index = (level_index + 1) % BoardLogic.level_count()
			SaveData.level = level_index
		"theme":
			theme_id = Palette.next_id(theme_id)
			SaveData.theme_id = theme_id
			_apply_theme()
	SaveData.save_data()
	_setup_board()
	_spawn_food()
	_update_menu_texts()
	hud.set_best(best)


func _update_menu_texts() -> void:
	var size_index := SIZES.find(cols)
	var speed_index := SPEEDS.find(speed_ms)
	hud.set_option("size", "棋盘大小 · %s" % SIZE_LABELS[maxi(size_index, 0)])
	hud.set_option("speed", "移动速度 · %s" % SPEED_LABELS[maxi(speed_index, 0)])
	hud.set_option("level", "关卡 · %s" % BoardLogic.LEVEL_NAMES[level_index])
	hud.set_option("theme", "主题 · %s" % Palette.display_name(theme_id))
	hud.set_level_description(
		"%s —— %s" % [
			BoardLogic.LEVEL_NAMES[level_index],
			BoardLogic.LEVEL_DESCRIPTIONS[level_index],
		]
	)


func _toggle_mute() -> void:
	SaveData.muted = not SaveData.muted
	SaveData.save_data()
	Sfx.set_muted(SaveData.muted)
	hud.set_muted(SaveData.muted)


func _apply_theme() -> void:
	colors = Palette.get_theme(theme_id)

	_sky_material.sky_top_color = colors["bg_top"].lightened(0.03)
	_sky_material.sky_horizon_color = colors["bg_top"].lightened(0.3)
	_sky_material.ground_bottom_color = colors["bg_bottom"]
	_sky_material.ground_horizon_color = colors["bg_bottom"].lightened(0.15)
	_sky_material.sky_energy_multiplier = 0.55
	_sky_material.ground_energy_multiplier = 0.3
	_environment.fog_light_color = colors["bg_top"].lightened(0.12)
	_environment.fog_light_energy = 0.7
	_fill_light.light_color = colors["glow"]
	_fill_light.light_energy = 0.75

	hud.apply_theme(colors)
	if is_node_ready():
		board_view.configure(cols, rows, walls, portals, colors)
		snake_view.configure(cols, rows, colors)
		food_view.configure(food_kind, colors)


# ---------------------------------------------------------------- HUD 与特效

func _update_hud(delta: float) -> void:
	hud_accum += delta
	if hud_accum < 0.1:
		return
	hud_accum = 0.0
	hud.update_stats(score, best, cells.size())
	hud.set_effects(effects)


## 开局一次性建好飘字与爆散粒子池，运行时只改参数复用，避免吃食物时卡帧。
func _warm_effects() -> void:
	for i in POPUP_POOL_SIZE:
		var label := Label3D.new()
		label.font = UiFont.get_font()
		label.font_size = 64
		label.pixel_size = 0.006
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.no_depth_test = true
		label.outline_size = 12
		label.visible = false
		add_child(label)
		_popup_pool.append(label)

	for i in BURST_POOL_SIZE:
		var particles := GPUParticles3D.new()
		particles.amount = BURST_AMOUNT
		particles.lifetime = 0.75
		particles.one_shot = true
		particles.explosiveness = 1.0
		particles.emitting = false

		var process := ParticleProcessMaterial.new()
		process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
		process.emission_sphere_radius = 0.22
		process.direction = Vector3(0.0, 1.0, 0.0)
		process.spread = 180.0
		process.initial_velocity_min = 1.75
		process.initial_velocity_max = 5.0
		process.gravity = Vector3(0.0, -2.5, 0.0)
		process.scale_min = 0.6
		process.scale_max = 1.5
		particles.process_material = process

		var mesh := SphereMesh.new()
		mesh.radius = 0.05
		mesh.height = 0.1
		var material := StandardMaterial3D.new()
		material.emission_enabled = true
		material.emission_energy_multiplier = 3.5
		mesh.material = material
		particles.draw_pass_1 = mesh

		add_child(particles)
		_burst_pool.append(particles)


func _spawn_popup(text: String, world: Vector3) -> void:
	var label := _popup_pool[_popup_index]
	_popup_index = (_popup_index + 1) % _popup_pool.size()

	var running: Variant = label.get_meta("fx_tween", null)
	if running is Tween and running.is_valid():
		running.kill()

	label.text = text
	label.outline_modulate = Color(colors["bg_bottom"], 0.95)
	label.modulate = colors["accent"]
	label.position = world + Vector3(0.0, 1.0, 0.0)
	label.visible = true

	var tween := label.create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y + 1.0, 0.8) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, 0.7).set_delay(0.3)
	tween.chain().tween_callback(_hide_popup.bind(label))
	label.set_meta("fx_tween", tween)


func _hide_popup(label: Label3D) -> void:
	label.visible = false


func _burst(world: Vector3, color: Color, amount: int, speed: float) -> void:
	var particles := _burst_pool[_burst_index]
	_burst_index = (_burst_index + 1) % _burst_pool.size()

	particles.position = world
	particles.amount = maxi(amount, 1)
	particles.emitting = true
	particles.restart()

	var process := particles.process_material as ParticleProcessMaterial
	process.initial_velocity_min = speed * 0.35
	process.initial_velocity_max = speed

	var mesh := particles.draw_pass_1 as SphereMesh
	var material := mesh.material as StandardMaterial3D
	material.albedo_color = color
	material.emission = color


func _food_color() -> Color:
	if food_kind == "":
		return colors["food"]
	return POWERUP_COLORS.get(food_kind, colors["accent"])


func cell_world(cell: Vector2i) -> Vector3:
	return Vector3(
		cell.x + 0.5 - cols * 0.5,
		BODY_Y,
		cell.y + 0.5 - rows * 0.5
	)
