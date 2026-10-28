class_name HudView
extends Control

## HUD 与各种浮层：顶部计分、道具倒计时、倒计时、主菜单、暂停与结算。
## 全部用代码搭建，便于统一按配色表重绘。

signal start_pressed
signal restart_pressed
signal resume_pressed
signal menu_pressed
signal pause_pressed
signal mute_pressed
signal option_cycled(key: String)

const EFFECT_LABELS := {
	"speed_up": "加速",
	"slow_down": "减速",
	"shield": "护盾",
	"magnet": "磁铁",
	"double": "双倍",
}

var colors: Dictionary = Palette.get_theme("neon")

var _top_panel: PanelContainer
var _score_label: Label
var _best_label: Label
var _len_label: Label
var _effects_box: HBoxContainer
var _pause_button: Button
var _mute_button: Button
var _hint: Label
var _countdown_label: Label
var _flash: ColorRect

var _menu: Control
var _menu_panel: PanelContainer
var _title: Label
var _subtitle: Label
var _best_menu: Label
var _desc_label: Label
var _start_button: Button
var _menu_hint: Label
var _option_buttons := {}

var _over: Control
var _over_panel: PanelContainer
var _over_title: Label
var _over_score: Label
var _over_best: Label
var _over_badge: Label

var _pause_layer: Control
var _pause_panel: PanelContainer

var _all_buttons: Array[Button] = []
var _primary_buttons := {}
var _dim_labels: Array[Label] = []
var _effect_signature := ""
var _last_effects := {}


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_top_bar()
	_build_hint()
	_build_countdown()
	_build_menu()
	_build_game_over()
	_build_pause()
	_build_flash()
	apply_theme(colors)
	enter_menu()


# ---------------------------------------------------------------- 构建

func _build_top_bar() -> void:
	_top_panel = PanelContainer.new()
	_top_panel.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_top_panel.offset_left = 18
	_top_panel.offset_right = -18
	_top_panel.offset_top = 14
	_top_panel.offset_bottom = 96
	add_child(_top_panel)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	_top_panel.add_child(row)

	var score_col := VBoxContainer.new()
	score_col.add_theme_constant_override("separation", -4)
	score_col.custom_minimum_size = Vector2(190, 0)
	row.add_child(score_col)

	_score_label = _make_label("0", 34)
	score_col.add_child(_score_label)

	_best_label = _make_label("最高 0", 13)
	_dim_labels.append(_best_label)
	score_col.add_child(_best_label)

	_effects_box = HBoxContainer.new()
	_effects_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_effects_box.add_theme_constant_override("separation", 8)
	_effects_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_effects_box)

	var right := HBoxContainer.new()
	right.add_theme_constant_override("separation", 10)
	row.add_child(right)

	_len_label = _make_label("长度 3", 14)
	_dim_labels.append(_len_label)
	_len_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	right.add_child(_len_label)

	_mute_button = _make_button("音效 开", 13)
	_mute_button.custom_minimum_size = Vector2(84, 40)
	_mute_button.pressed.connect(func(): mute_pressed.emit())
	right.add_child(_mute_button)

	_pause_button = _make_button("暂停", 14)
	_pause_button.custom_minimum_size = Vector2(74, 40)
	_pause_button.pressed.connect(func(): pause_pressed.emit())
	right.add_child(_pause_button)


func _build_hint() -> void:
	_hint = _make_label("点击选项切换 · 回车开始", 12)
	_hint.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_hint.offset_top = -44
	_hint.offset_bottom = -14
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_dim_labels.append(_hint)
	add_child(_hint)


func _build_countdown() -> void:
	_countdown_label = _make_label("3", 104)
	_countdown_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_countdown_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_countdown_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_countdown_label.visible = false
	_countdown_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_countdown_label)


func _build_menu() -> void:
	var parts := _make_overlay()
	_menu = parts[0]
	_menu_panel = parts[1]
	var box: VBoxContainer = parts[2]
	_menu_panel.custom_minimum_size = Vector2(476, 0)

	_title = _make_label("贪吃蛇", 46)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_title)

	_subtitle = _make_label("GODOT 4.7.2 · GDSCRIPT · 3D", 12)
	_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_dim_labels.append(_subtitle)
	box.add_child(_subtitle)

	box.add_child(HSeparator.new())

	var entries := [
		["size", "棋盘大小"],
		["speed", "移动速度"],
		["level", "关卡"],
		["theme", "主题"],
	]
	for entry in entries:
		var key: String = entry[0]
		var button := _make_button("%s · —" % entry[1], 15)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.custom_minimum_size = Vector2(0, 44)
		button.pressed.connect(func(): option_cycled.emit(key))
		box.add_child(button)
		_option_buttons[key] = button

	_desc_label = _make_label("", 13)
	_desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_desc_label.custom_minimum_size = Vector2(0, 42)
	_dim_labels.append(_desc_label)
	box.add_child(_desc_label)

	_start_button = _make_button("开始游戏  ▶", 17, true)
	_start_button.custom_minimum_size = Vector2(0, 50)
	_start_button.pressed.connect(func(): start_pressed.emit())
	box.add_child(_start_button)

	_best_menu = _make_label("最高分 0", 14)
	_best_menu.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_dim_labels.append(_best_menu)
	box.add_child(_best_menu)

	_menu_hint = _make_label("方向键 / WASD 转向 · 右键拖动旋转视角 · 空格暂停", 12)
	_menu_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_dim_labels.append(_menu_hint)
	box.add_child(_menu_hint)


func _build_game_over() -> void:
	var parts := _make_overlay()
	_over = parts[0]
	_over_panel = parts[1]
	var box: VBoxContainer = parts[2]
	_over_panel.custom_minimum_size = Vector2(420, 0)

	_over_title = _make_label("游戏结束", 34)
	_over_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_over_title)

	_over_badge = _make_label("★ 新纪录 ★", 14)
	_over_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_over_badge.visible = false
	box.add_child(_over_badge)

	_over_score = _make_label("0", 56)
	_over_score.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_over_score)

	_over_best = _make_label("最高分 0", 14)
	_over_best.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_dim_labels.append(_over_best)
	box.add_child(_over_best)

	box.add_child(HSeparator.new())

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	box.add_child(row)

	var again := _make_button("再来一局", 15, true)
	again.custom_minimum_size = Vector2(0, 46)
	again.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	again.pressed.connect(func(): restart_pressed.emit())
	row.add_child(again)

	var home := _make_button("返回主页", 15)
	home.custom_minimum_size = Vector2(0, 46)
	home.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	home.pressed.connect(func(): menu_pressed.emit())
	row.add_child(home)


func _build_pause() -> void:
	var parts := _make_overlay()
	_pause_layer = parts[0]
	_pause_panel = parts[1]
	var box: VBoxContainer = parts[2]
	_pause_panel.custom_minimum_size = Vector2(340, 0)

	var title := _make_label("已暂停", 32)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	var resume := _make_button("继续游戏", 15, true)
	resume.custom_minimum_size = Vector2(0, 46)
	resume.pressed.connect(func(): resume_pressed.emit())
	box.add_child(resume)

	var restart := _make_button("重新开始", 15)
	restart.custom_minimum_size = Vector2(0, 44)
	restart.pressed.connect(func(): restart_pressed.emit())
	box.add_child(restart)

	var home := _make_button("返回主页", 15)
	home.custom_minimum_size = Vector2(0, 44)
	home.pressed.connect(func(): menu_pressed.emit())
	box.add_child(home)


func _build_flash() -> void:
	_flash = ColorRect.new()
	_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_flash.color = Color(1, 1, 1, 0)
	_flash.modulate.a = 0.0
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_flash)


func _make_overlay() -> Array:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)

	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.0, 0.0, 0.0, 0.32)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)

	var panel := PanelContainer.new()
	center.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_bottom", 24)
	panel.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 11)
	margin.add_child(box)

	return [root, panel, box]


# ---------------------------------------------------------------- 样式

func apply_theme(new_colors: Dictionary) -> void:
	colors = new_colors
	_style_panel(_top_panel, 0.88, 16)
	_style_panel(_menu_panel, 0.96, 20)
	_style_panel(_over_panel, 0.96, 20)
	_style_panel(_pause_panel, 0.96, 20)

	_title.add_theme_color_override("font_color", colors["accent"])
	_score_label.add_theme_color_override("font_color", colors["text"])
	_over_score.add_theme_color_override("font_color", colors["accent"])
	_over_title.add_theme_color_override("font_color", colors["danger"])
	_over_badge.add_theme_color_override("font_color", colors["warning"])
	_countdown_label.add_theme_color_override("font_color", colors["accent"])
	_countdown_label.add_theme_color_override("font_outline_color", Color(colors["bg_bottom"], 0.9))
	_countdown_label.add_theme_constant_override("outline_size", 10)

	for label in _dim_labels:
		label.add_theme_color_override("font_color", colors["text_dim"])

	for button in _all_buttons:
		_style_button(button)

	_effect_signature = ""
	if not _last_effects.is_empty():
		set_effects(_last_effects)


func _style_panel(panel: PanelContainer, alpha: float, radius: int) -> void:
	if panel == null:
		return
	var style := StyleBoxFlat.new()
	style.bg_color = Color(colors["panel"].r, colors["panel"].g, colors["panel"].b, alpha)
	style.set_corner_radius_all(radius)
	style.set_border_width_all(1)
	style.border_color = Color(colors["panel_border"], 0.9)
	style.shadow_color = Color(0, 0, 0, 0.45)
	style.shadow_size = 16 if radius > 16 else 6
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	panel.add_theme_stylebox_override("panel", style)


func _style_button(button: Button) -> void:
	var primary := _primary_buttons.has(button)
	var base: Color = colors["accent"] if primary else colors["panel_border"].darkened(0.55)
	var font_color: Color = colors["bg_bottom"] if primary else colors["text"]
	button.add_theme_stylebox_override("normal", _button_box(base, 1.0, Color(colors["panel_border"], 0.95)))
	button.add_theme_stylebox_override("hover", _button_box(base.lightened(0.12), 1.0, colors["accent"]))
	button.add_theme_stylebox_override("pressed", _button_box(base.darkened(0.16), 1.0, colors["accent"]))
	button.add_theme_stylebox_override("focus", _button_box(Color(0, 0, 0, 0), 0.0, Color(colors["accent"], 0.9)))
	button.add_theme_color_override("font_color", font_color)
	button.add_theme_color_override("font_hover_color", font_color)
	button.add_theme_color_override("font_pressed_color", font_color)
	button.add_theme_color_override("font_focus_color", font_color)


func _button_box(bg: Color, alpha: float, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(bg.r, bg.g, bg.b, alpha)
	style.set_corner_radius_all(10)
	style.set_border_width_all(1)
	style.border_color = border
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style


# ---------------------------------------------------------------- 状态更新

func enter_menu() -> void:
	_menu.visible = true
	_over.visible = false
	_pause_layer.visible = false
	_top_panel.visible = false
	_hint.visible = true
	_countdown_label.visible = false
	_hint.text = "点击选项切换 · 回车开始"


func enter_game() -> void:
	_menu.visible = false
	_over.visible = false
	_pause_layer.visible = false
	_top_panel.visible = true
	_pause_button.visible = true
	_pause_button.text = "暂停"
	_hint.visible = true
	_hint.text = "方向键 / WASD 转向 · 右键拖动转视角 · 滚轮缩放 · 空格暂停"


func show_pause() -> void:
	_pause_layer.visible = true
	_pause_button.text = "继续"


func hide_pause() -> void:
	_pause_layer.visible = false
	_pause_button.text = "暂停"


func show_game_over(score: int, best: int, record: bool) -> void:
	_over.visible = true
	_over_score.text = str(score)
	_over_best.text = "最高分 %d" % best
	_over_badge.visible = record
	_pause_button.visible = false
	_hint.text = "回车再来一局 · Esc 返回主页"


func update_stats(score: int, best: int, length: int) -> void:
	_score_label.text = str(score)
	_best_label.text = "最高 %d" % best
	_len_label.text = "长度 %d" % length


func set_best(best: int) -> void:
	_best_label.text = "最高 %d" % best
	_best_menu.text = "最高分 %d" % best


func set_option(key: String, text: String) -> void:
	var button: Button = _option_buttons.get(key)
	if button != null:
		button.text = text


func set_level_description(text: String) -> void:
	_desc_label.text = text


func set_muted(muted: bool) -> void:
	_mute_button.text = "音效 关" if muted else "音效 开"


func show_countdown(text: String) -> void:
	_countdown_label.text = text
	_countdown_label.visible = true
	_countdown_label.modulate = Color(1, 1, 1, 1)
	_countdown_label.pivot_offset = get_viewport_rect().size * 0.5
	_countdown_label.scale = Vector2(1.3, 1.3)
	var tween := create_tween()
	tween.tween_property(_countdown_label, "scale", Vector2.ONE, 0.26) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func hide_countdown() -> void:
	_countdown_label.visible = false


func flash(color: Color) -> void:
	_flash.color = color
	_flash.modulate.a = 0.8
	var tween := create_tween()
	tween.tween_property(_flash, "modulate:a", 0.0, 0.5)


func set_effects(effects: Dictionary) -> void:
	_last_effects = effects.duplicate()
	var signature := ""
	for key in effects:
		signature += "%s:%d;" % [key, int(ceil(float(effects[key])))]
	if signature == _effect_signature:
		return
	_effect_signature = signature

	for child in _effects_box.get_children():
		child.queue_free()

	for key in effects:
		var color := _effect_color(key)
		var chip := PanelContainer.new()
		var style := StyleBoxFlat.new()
		style.bg_color = Color(color.r, color.g, color.b, 0.14)
		style.border_color = Color(color.r, color.g, color.b, 0.65)
		style.set_border_width_all(1)
		style.set_corner_radius_all(8)
		style.content_margin_left = 10
		style.content_margin_right = 10
		style.content_margin_top = 3
		style.content_margin_bottom = 3
		chip.add_theme_stylebox_override("panel", style)
		var label := _make_label("%s %.1fs" % [EFFECT_LABELS.get(key, key), float(effects[key])], 12)
		label.add_theme_color_override("font_color", color)
		chip.add_child(label)
		_effects_box.add_child(chip)


func _effect_color(key: String) -> Color:
	match key:
		"speed_up":
			return colors["warning"]
		"slow_down":
			return Color("#6ec6ff")
		"shield":
			return colors["special"]
		"magnet":
			return colors["accent_alt"]
		"double":
			return colors["accent"]
	return colors["text"]


# ---------------------------------------------------------------- 小工具

func _make_label(text: String, size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", UiFont.get_font())
	label.add_theme_font_size_override("font_size", size)
	return label


func _make_button(text: String, size: int, primary := false) -> Button:
	var button := Button.new()
	button.text = text
	button.add_theme_font_override("font", UiFont.get_font())
	button.add_theme_font_size_override("font_size", size)
	button.focus_mode = Control.FOCUS_ALL
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_all_buttons.append(button)
	if primary:
		_primary_buttons[button] = true
	return button
