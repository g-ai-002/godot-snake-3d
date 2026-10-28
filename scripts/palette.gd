class_name Palette
extends RefCounted

## 三套配色。所有渲染层只读这里，切换主题时整体换色。

const ORDER := ["neon", "candy", "classic"]

const DATA := {
	"neon": {
		"name": "霓虹",
		"bg_top": Color("#070d1a"),
		"bg_bottom": Color("#03060d"),
		"board": Color("#081120"),
		"board_alt": Color("#0a1628"),
		"grid": Color("#16324a"),
		"frame": Color("#2ef2b3"),
		"wall": Color("#163247"),
		"wall_edge": Color("#3f8fb0"),
		"head": Color("#d6fff0"),
		"body": Color("#2fe08a"),
		"tail": Color("#0f6b52"),
		"glow": Color("#2ef2b3"),
		"food": Color("#ff5c7a"),
		"accent": Color("#39f5c8"),
		"accent_alt": Color("#ff3ea5"),
		"panel": Color("#0b1526"),
		"panel_border": Color("#1f4a5e"),
		"text": Color("#eafff8"),
		"text_dim": Color("#7ea7b8"),
		"danger": Color("#ff4d6d"),
		"warning": Color("#ffd166"),
		"special": Color("#b388ff"),
	},
	"candy": {
		"name": "糖果",
		"bg_top": Color("#1a1024"),
		"bg_bottom": Color("#0b0710"),
		"board": Color("#221330"),
		"board_alt": Color("#28163a"),
		"grid": Color("#3a2350"),
		"frame": Color("#ff8fd1"),
		"wall": Color("#3d2453"),
		"wall_edge": Color("#ff9ae0"),
		"head": Color("#fff0f8"),
		"body": Color("#ff7ac0"),
		"tail": Color("#8a2f66"),
		"glow": Color("#ff8fd1"),
		"food": Color("#7cf0d0"),
		"accent": Color("#ff8fd1"),
		"accent_alt": Color("#7cf0d0"),
		"panel": Color("#1c1029"),
		"panel_border": Color("#57316f"),
		"text": Color("#fff2fb"),
		"text_dim": Color("#c39cc0"),
		"danger": Color("#ff6b8a"),
		"warning": Color("#ffd166"),
		"special": Color("#8fd0ff"),
	},
	"classic": {
		"name": "经典",
		"bg_top": Color("#0b1a12"),
		"bg_bottom": Color("#050d09"),
		"board": Color("#0f2418"),
		"board_alt": Color("#132a1c"),
		"grid": Color("#23402e"),
		"frame": Color("#a8e063"),
		"wall": Color("#24402c"),
		"wall_edge": Color("#6bbf59"),
		"head": Color("#f2ffe6"),
		"body": Color("#7bd94f"),
		"tail": Color("#2f6b2b"),
		"glow": Color("#a8e063"),
		"food": Color("#ff7a45"),
		"accent": Color("#a8e063"),
		"accent_alt": Color("#ffb347"),
		"panel": Color("#10251a"),
		"panel_border": Color("#37543f"),
		"text": Color("#f0ffe6"),
		"text_dim": Color("#9fbf9a"),
		"danger": Color("#ff6b5a"),
		"warning": Color("#ffd166"),
		"special": Color("#7fd0ff"),
	},
}


static func get_theme(id: String) -> Dictionary:
	if DATA.has(id):
		return DATA[id]
	return DATA["neon"]


static func next_id(id: String) -> String:
	var index := ORDER.find(id)
	if index < 0:
		return ORDER[0]
	return ORDER[(index + 1) % ORDER.size()]


static func display_name(id: String) -> String:
	return get_theme(id)["name"]
