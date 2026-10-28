class_name BoardLogic
extends RefCounted

## 棋盘逻辑：关卡布局、出生点清理与坐标换算，纯数据，不依赖渲染。

enum Level { OPEN, BORDER, PILLARS, CROSS, MAZE, PORTALS }

const LEVEL_NAMES := ["空旷", "边墙", "立柱阵", "十字回廊", "回字迷宫", "传送门"]
const LEVEL_DESCRIPTIONS := [
	"没有障碍物，专注吃分",
	"内圈围墙，四边各留缺口",
	"均匀分布的 2×2 立柱",
	"中央十字墙，中心留出空场",
	"双层回字围墙，考验路线规划",
	"两对传送门，瞬间穿越棋盘",
]


static func level_count() -> int:
	return LEVEL_NAMES.size()


static func build_layout(level: int, cols: int, rows: int) -> Dictionary:
	var center := int(cols * 0.5)
	var mid := int(rows * 0.5)
	match level:
		Level.BORDER:
			return {"walls": _border_walls(cols, rows, center, mid), "portals": {}}
		Level.PILLARS:
			return {"walls": _pillar_walls(cols, rows), "portals": {}}
		Level.CROSS:
			return {"walls": _cross_walls(cols, rows, center, mid), "portals": {}}
		Level.MAZE:
			return {"walls": _maze_walls(cols, rows, center, mid), "portals": {}}
		Level.PORTALS:
			return _portal_layout(cols, rows, center, mid)
		_:
			return {"walls": {}, "portals": {}}


## 出生行两侧各留出缓冲，避免倒计时结束后立刻撞墙。
static func clear_spawn_row(walls: Dictionary, cols: int, rows: int) -> void:
	var center := int(cols * 0.5)
	var mid := int(rows * 0.5)
	for x in range(center - 3, center + 5):
		walls.erase(Vector2i(x, mid))


static func spawn_body(cols: int, rows: int) -> Array[Vector2i]:
	var center := int(cols * 0.5)
	var mid := int(rows * 0.5)
	var body: Array[Vector2i] = [
		Vector2i(center - 2, mid),
		Vector2i(center - 1, mid),
		Vector2i(center, mid),
	]
	return body


static func random_cell(
	cols: int,
	rows: int,
	occupied: Dictionary,
	rng: RandomNumberGenerator
) -> Vector2i:
	var available: Array[Vector2i] = []
	for y in rows:
		for x in cols:
			var cell := Vector2i(x, y)
			if not occupied.has(cell):
				available.append(cell)
	if available.is_empty():
		return Vector2i(-1, -1)
	return available[rng.randi_range(0, available.size() - 1)]


static func cell_to_world(cell: Vector2i, cols: int, rows: int, cell_size: float) -> Vector2:
	return Vector2(
		(cell.x + 0.5) - cols * 0.5,
		(cell.y + 0.5) - rows * 0.5
	) * cell_size


static func _border_walls(cols: int, rows: int, center: int, mid: int) -> Dictionary:
	const INSET := 2
	var gaps := {}
	for d in range(-1, 2):
		gaps[Vector2i(center + d, INSET)] = true
		gaps[Vector2i(center + d, rows - INSET - 1)] = true
		gaps[Vector2i(INSET, mid + d)] = true
		gaps[Vector2i(cols - INSET - 1, mid + d)] = true
	return _ring_walls(INSET, INSET, cols - INSET - 1, rows - INSET - 1, gaps)


static func _pillar_walls(cols: int, rows: int) -> Dictionary:
	var walls := {}
	var x := 3
	while x + 1 <= cols - 3:
		var y := 3
		while y + 1 <= rows - 3:
			for offset in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]:
				walls[Vector2i(x, y) + offset] = true
			y += 5
		x += 5
	return walls


static func _cross_walls(cols: int, rows: int, center: int, mid: int) -> Dictionary:
	var walls := {}
	for y in range(2, rows - 2):
		if y >= mid - 2 and y <= mid + 2:
			continue
		walls[Vector2i(center, y)] = true
	for x in range(2, cols - 2):
		if x >= center - 2 and x <= center + 2:
			continue
		walls[Vector2i(x, mid)] = true
	return walls


static func _maze_walls(cols: int, rows: int, center: int, mid: int) -> Dictionary:
	var gaps := {}
	for d in range(-1, 2):
		gaps[Vector2i(center + d, 2)] = true
		gaps[Vector2i(center + d, rows - 3)] = true
		gaps[Vector2i(2, mid + d)] = true
		gaps[Vector2i(cols - 3, mid + d)] = true

	var walls := _ring_walls(2, 2, cols - 3, rows - 3, gaps)
	var inner_left := 5
	var inner_top := 5
	var inner_right := cols - 6
	var inner_bottom := rows - 6
	if inner_right - inner_left >= 2 and inner_bottom - inner_top >= 2:
		var inner_gaps := {
			Vector2i(center, inner_top): true,
			Vector2i(center, inner_bottom): true,
			Vector2i(inner_left, mid): true,
			Vector2i(inner_right, mid): true,
		}
		walls.merge(_ring_walls(inner_left, inner_top, inner_right, inner_bottom, inner_gaps))
	return walls


static func _portal_layout(cols: int, rows: int, center: int, mid: int) -> Dictionary:
	var left := Vector2i(2, mid)
	var right := Vector2i(cols - 3, mid)
	var top := Vector2i(center, 2)
	var bottom := Vector2i(center, rows - 3)
	return {
		"walls": {},
		"portals": {
			left: right,
			right: left,
			top: bottom,
			bottom: top,
		},
	}


static func _ring_walls(
	left: int,
	top: int,
	right: int,
	bottom: int,
	gaps: Dictionary
) -> Dictionary:
	var walls := {}
	for x in range(left, right + 1):
		for y in [top, bottom]:
			var cell := Vector2i(x, y)
			if not gaps.has(cell):
				walls[cell] = true
	for y in range(top, bottom + 1):
		for x in [left, right]:
			var cell := Vector2i(x, y)
			if not gaps.has(cell):
				walls[cell] = true
	return walls
