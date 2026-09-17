extends Node
## Oyun verisi ve saf mantık (HTML prototipteki `state` objesi + yardımcı fonksiyonlar).
## Görsel/animasyon/ses işleri Main.gd içinde; burada yalnızca veri ve kurallar var.

const CELL := 58.0
const GRID_MARGIN_X := 15.0
const GRID_MARGIN_Y := 24.0
const CAP_OFFSET := 14.0 # her ek katman bir öncekinden bu kadar kayar
const TRAY_MAX := 7
const QUEUE_VISIBLE := 5

const ICONS := ["tentacle", "eyesoup", "glowshroom", "alienleg", "wormnoodle",
	"crystalshrimp", "ooze", "spikefruit", "alienegg"]

const ICON_COLORS := {
	"tentacle": Color("#1F8A6E"), "eyesoup": Color("#B8391E"), "glowshroom": Color("#1E9C8C"),
	"alienleg": Color("#5C2E8C"), "wormnoodle": Color("#8FB83A"), "crystalshrimp": Color("#4C8CD8"),
	"ooze": Color("#5C9C1E"), "spikefruit": Color("#8C1E6C"), "alienegg": Color("#6C9C4A"),
}

const CUSTOMER_TYPES := ["cust_octo", "cust_pirate", "cust_cyclops", "cust_tri_eye",
	"cust_horned", "cust_tentabeard"]

# cols, rows, layers, tiers (katman başı taş sayısı), icons (ikon çeşidi), copies (kopya/ikon)
const LEVEL_TABLE := [
	{"cols": 3, "rows": 3, "layers": 1, "tiers": [9], "icons": 3, "copies": 3},
	{"cols": 4, "rows": 3, "layers": 2, "tiers": [12, 3], "icons": 5, "copies": 3},
	{"cols": 4, "rows": 4, "layers": 3, "tiers": [16, 6, 2], "icons": 8, "copies": 3},
	{"cols": 5, "rows": 4, "layers": 4, "tiers": [20, 4, 2, 1], "icons": 9, "copies": 3},
	{"cols": 6, "rows": 5, "layers": 5, "tiers": [30, 14, 6, 3, 1], "icons": 9, "copies": 6},
]

var level: int = 1
var tiles: Array = [] # Array of Dictionary {id, icon, layer, x, y}
var tray: Array = [] # Array of Dictionary {id, icon, x, y, layer} (orijinal konum saklanır -> geri al)
var status: String = "playing" # playing | won | lost
var matches: int = 0
var jokers: Dictionary = {}
var queue: Array = [] # Array of customer type strings
var queue_served: int = 0
var flights_in_progress: int = 0
var board_w: float = 320.0
var board_h: float = 280.0

var _uid_counter: int = 1


func get_level_config(lvl: int) -> Dictionary:
	var idx: int = clampi(lvl, 1, LEVEL_TABLE.size()) - 1
	return LEVEL_TABLE[idx]


func _shuffle(arr: Array) -> Array:
	var i: int = arr.size() - 1
	while i > 0:
		var j: int = randi() % (i + 1)
		var t = arr[i]
		arr[i] = arr[j]
		arr[j] = t
		i -= 1
	return arr


func _build_level_tiles(config: Dictionary) -> Dictionary:
	var bag: Array = []
	for i in range(config.icons):
		for k in range(config.copies):
			bag.append(ICONS[i])
	_shuffle(bag)

	var cols: int = config.cols
	var rows: int = config.rows
	var bw: float = cols * CELL + GRID_MARGIN_X * 2
	var bh: float = rows * CELL + GRID_MARGIN_Y * 2
	var ox: float = GRID_MARGIN_X
	var oy: float = GRID_MARGIN_Y
	var min_x: float = ox
	var max_x: float = ox + cols * CELL - CELL
	var min_y: float = oy
	var max_y: float = oy + rows * CELL - CELL
	var idx: int = 0
	var built_tiles: Array = []

	var base: Array = []
	for r in range(rows):
		for c in range(cols):
			base.append({"col": c, "row": r})
	var prev_positions: Array = []
	for cell in base:
		var pos := Vector2(ox + cell.col * CELL, oy + cell.row * CELL)
		built_tiles.append({"id": "t%d" % _next_uid(), "icon": bag[idx], "layer": 0, "x": pos.x, "y": pos.y})
		idx += 1
		prev_positions.append(pos)

	if config.layers >= 2:
		var inter: Array = []
		for r2 in range(rows - 1):
			for c2 in range(cols - 1):
				inter.append({"col": c2, "row": r2})
		_shuffle(inter)
		var t1: Array = []
		for cell in inter.slice(0, config.tiers[1]):
			t1.append(Vector2(ox + (cell.col + 0.5) * CELL, oy + (cell.row + 0.5) * CELL))
		for pos in t1:
			built_tiles.append({"id": "t%d" % _next_uid(), "icon": bag[idx], "layer": 1, "x": pos.x, "y": pos.y})
			idx += 1
		prev_positions = t1

	# Katman 2 ve sonrası: bir öncekinden sabit bir miktar (CAP_OFFSET) kayarak oturur.
	# Böylece hiçbir katman bir öncekini %100 örtmez; her zaman kısmi bir "ucundan görünme" kalır.
	for k in range(2, config.layers):
		_shuffle(prev_positions)
		var tk: Array = []
		for pos in prev_positions.slice(0, config.tiers[k]):
			var nx: float = clampf(pos.x + CAP_OFFSET, min_x, max_x)
			var ny: float = clampf(pos.y + CAP_OFFSET, min_y, max_y)
			tk.append(Vector2(nx, ny))
		for pos in tk:
			built_tiles.append({"id": "t%d" % _next_uid(), "icon": bag[idx], "layer": k, "x": pos.x, "y": pos.y})
			idx += 1
		prev_positions = tk

	return {"tiles": built_tiles, "board_w": bw, "board_h": bh}


func _next_uid() -> int:
	_uid_counter += 1
	return _uid_counter - 1


func new_level(lvl: int, jokers_override = null) -> void:
	var config: Dictionary = get_level_config(lvl)
	var built: Dictionary = _build_level_tiles(config)
	level = lvl
	tiles = built.tiles
	board_w = built.board_w
	board_h = built.board_h
	tray = []
	status = "playing"
	matches = 0
	jokers = jokers_override if jokers_override != null else {"shuffle": 1, "restartLevel": 1, "removeTile": 1, "undo": 1}
	queue_served = 0
	flights_in_progress = 0

	var queue_total: int = int(built.tiles.size() / 3.0)
	queue = []
	for i in range(queue_total):
		queue.append(CUSTOMER_TYPES[randi() % CUSTOMER_TYPES.size()])


## Gerçek dikdörtgen çakışmasına bakar: bir taş, kendisinden yüksek katmanda olan ve
## bounding box'ı gerçekten çakışan taş sayısı kadar "örtülü" sayılır. 0 ise tıklanabilir.
func covering_count(tile: Dictionary) -> int:
	var n: int = 0
	for o in tiles:
		if o == tile or o.layer <= tile.layer:
			continue
		if abs(o.x - tile.x) < CELL - 1 and abs(o.y - tile.y) < CELL - 1:
			n += 1
	return n


func find_tile_index(id: String) -> int:
	for i in range(tiles.size()):
		if tiles[i].id == id:
			return i
	return -1


func queue_remaining() -> int:
	return queue.size() - queue_served
