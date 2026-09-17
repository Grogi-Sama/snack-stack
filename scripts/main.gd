extends Control
## Görünüm + kontrolcü katmanı (HTML prototipteki DOM render fonksiyonları + event handler'ların
## karşılığı). Oyun verisi/kuralları GameState singleton'ında; burada yalnızca sahneyi o veriye
## göre kurup girdiyi GameState'e yönlendiriyoruz.

const ICON_DIR := "res://assets/icons/"

const COL_INK := Color("#1B1F3B")
const COL_INK_SOFT := Color("#585F82")
const COL_CARD := Color("#FFFFFF")
const COL_TRAY_BG := Color("#F5FAF7")
const COL_ACCENT := Color("#FF8A3D")
const COL_ACCENT_INK := Color("#7A3200")
const COL_ACCENT2 := Color("#2EC4B6")
const COL_DANGER := Color("#E8503A")
const COL_TILE_TOP := Color("#FFFDF6")
const COL_TILE_BASE := Color("#F1E7CC")
const COL_TILE_EDGE := Color("#CBB37E")
const COL_BOARD_BG := Color("#D9C393")
const COL_WICKER := Color("#A6784A")
const COL_WICKER_RIM := Color("#7A5228")
const COL_JOKER_TOP := Color("#FFA35E")
const COL_JOKER_BASE := Color("#F07A22")
const COL_JOKER_EDGE := Color("#B85A12")

var _icon_cache: Dictionary = {}

# Node referansları (render fonksiyonları bunları dolduruyor)
var sub_line: Label
var stat_level: Label
var stat_remaining: Label
var stat_matches: Label
var board_frame: Control
var board_bg: ColorRect
var board_inner: Control
var overlay: Control
var overlay_title: Label
var overlay_text: Label
var overlay_button: Button
var queue_count_label: Label
var queue_row: HBoxContainer
var tray_grid: GridContainer
var chef_icon: TextureRect
var pot_icon: TextureRect
var steam_nodes: Array = []
var jokers_grid: GridContainer
var joker_buttons: Dictionary = {} # type -> Button
var joker_count_labels: Dictionary = {} # type -> Label
var sound_button: Button
var fly_layer: Control

var armed_joker: String = ""
var overlay_action: Callable = Callable()
var board_scale: float = 1.0
var flight_generation: int = 0
var current_generation: int = 0

const JOKER_DEFS := [
	{"type": "shuffle", "icon": "ic_joker_shuffle", "label": "Karıştır", "hint": "Kalan taşları karıştır"},
	{"type": "restartLevel", "icon": "ic_joker_restart", "label": "Baştan Başla", "hint": "Bu seviyeyi baştan başlat"},
	{"type": "removeTile", "icon": "ic_joker_remove", "label": "Taşı Kaldır", "hint": "Açık bir taşı doğrudan kaldır"},
	{"type": "undo", "icon": "ic_joker_undo", "label": "Geri Al", "hint": "Son taşı geri al"},
]


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	randomize()
	_build_ui()
	_start_level(1)


func _icon(name: String) -> Texture2D:
	if not _icon_cache.has(name):
		var png_path := ICON_DIR + name + ".png"
		var path := png_path if FileAccess.file_exists(png_path) else ICON_DIR + name + ".svg"
		_icon_cache[name] = load(path)
	return _icon_cache[name]


# ---------------------------------------------------------------- UI kurulumu

func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color("#DFF0C8")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	add_child(margin)

	var center := CenterContainer.new()
	margin.add_child(center)

	var phone_wrap := PanelContainer.new()
	phone_wrap.custom_minimum_size = Vector2(388, 0)
	phone_wrap.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var phone_sb := StyleBoxFlat.new()
	phone_sb.bg_color = COL_CARD
	phone_sb.set_corner_radius_all(28)
	phone_sb.set_content_margin_all(16)
	phone_sb.shadow_size = 18
	phone_sb.shadow_color = Color(0.07, 0.09, 0.18, 0.22)
	phone_wrap.add_theme_stylebox_override("panel", phone_sb)
	center.add_child(phone_wrap)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	phone_wrap.add_child(vbox)

	_build_topbar(vbox)
	_build_stats(vbox)
	_build_board(vbox)
	_build_queue(vbox)
	_build_kitchen(vbox)
	_build_jokers(vbox)

	fly_layer = Control.new()
	fly_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fly_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fly_layer)

	_build_overlay()


func _build_topbar(parent: Control) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	parent.add_child(row)

	var title_block := VBoxContainer.new()
	title_block.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(title_block)

	var title := Label.new()
	title.text = "Yığın be Yığın"
	title.add_theme_color_override("font_color", COL_INK)
	title.add_theme_font_size_override("font_size", 21)
	title_block.add_child(title)

	sub_line = Label.new()
	sub_line.text = "Taşları topla, 3'le eşleştir, aşçıya yetiştir"
	sub_line.add_theme_color_override("font_color", COL_INK_SOFT)
	sub_line.add_theme_font_size_override("font_size", 12)
	sub_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_block.add_child(sub_line)

	sound_button = Button.new()
	sound_button.custom_minimum_size = Vector2(36, 36)
	sound_button.icon = _icon("ic_sound_on")
	sound_button.expand_icon = true
	_style_flat_button(sound_button, COL_TRAY_BG, 12)
	sound_button.pressed.connect(_on_sound_pressed)
	row.add_child(sound_button)


func _build_stats(parent: Control) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	parent.add_child(row)
	stat_level = _make_stat_label("Seviye 1")
	stat_remaining = _make_stat_label("Kalan: 0")
	stat_matches = _make_stat_label("Eşleşme: 0")
	row.add_child(stat_level)
	row.add_child(stat_remaining)
	row.add_child(stat_matches)


func _make_stat_label(txt: String) -> Label:
	var l := Label.new()
	l.text = txt
	l.add_theme_color_override("font_color", COL_INK_SOFT)
	l.add_theme_font_size_override("font_size", 12)
	return l


func _build_board(parent: Control) -> void:
	board_frame = Control.new()
	board_frame.custom_minimum_size = Vector2(0, 280)
	board_frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	board_frame.resized.connect(_update_board_scale)
	parent.add_child(board_frame)

	board_bg = ColorRect.new()
	board_bg.color = COL_BOARD_BG
	board_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	board_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	board_frame.add_child(board_bg)

	board_inner = Control.new()
	board_inner.mouse_filter = Control.MOUSE_FILTER_PASS
	board_frame.add_child(board_inner)


func _build_queue(parent: Control) -> void:
	var label_row := HBoxContainer.new()
	parent.add_child(label_row)
	var lbl := Label.new()
	lbl.text = "Müşteriler"
	lbl.add_theme_color_override("font_color", COL_INK_SOFT)
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label_row.add_child(lbl)
	queue_count_label = Label.new()
	queue_count_label.text = "0"
	queue_count_label.add_theme_color_override("font_color", COL_INK)
	queue_count_label.add_theme_font_size_override("font_size", 12)
	label_row.add_child(queue_count_label)

	queue_row = HBoxContainer.new()
	queue_row.add_theme_constant_override("separation", 6)
	queue_row.custom_minimum_size = Vector2(0, 44)
	parent.add_child(queue_row)


func _build_kitchen(parent: Control) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)

	chef_icon = TextureRect.new()
	chef_icon.texture = _icon("ic_chef")
	chef_icon.custom_minimum_size = Vector2(54, 65)
	chef_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	chef_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(chef_icon)

	var counter := Control.new()
	counter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	counter.custom_minimum_size = Vector2(0, 76)
	row.add_child(counter)

	var counter_bg := ColorRect.new()
	counter_bg.color = COL_WICKER
	counter_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	counter_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	counter.add_child(counter_bg)

	pot_icon = TextureRect.new()
	pot_icon.texture = _icon("ic_pot")
	pot_icon.custom_minimum_size = Vector2(40, 34)
	pot_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pot_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pot_icon.position = Vector2(counter.custom_minimum_size.x - 54, -20)
	pot_icon.anchor_left = 1.0
	pot_icon.anchor_right = 1.0
	pot_icon.offset_left = -54
	pot_icon.offset_right = -14
	pot_icon.offset_top = -20
	pot_icon.offset_bottom = 14
	counter.add_child(pot_icon)

	var tray_margin := MarginContainer.new()
	tray_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		tray_margin.add_theme_constant_override("margin_" + side, 10)
	counter.add_child(tray_margin)

	tray_grid = GridContainer.new()
	tray_grid.columns = 7
	tray_grid.add_theme_constant_override("h_separation", 5)
	tray_grid.add_theme_constant_override("v_separation", 5)
	tray_margin.add_child(tray_grid)


func _build_jokers(parent: Control) -> void:
	jokers_grid = GridContainer.new()
	jokers_grid.columns = 4
	jokers_grid.add_theme_constant_override("h_separation", 8)
	jokers_grid.add_theme_constant_override("v_separation", 8)
	parent.add_child(jokers_grid)

	for def in JOKER_DEFS:
		var wrap := Control.new()
		wrap.custom_minimum_size = Vector2(80, 66)
		wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		jokers_grid.add_child(wrap)

		var btn := Button.new()
		btn.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		btn.toggle_mode = false
		_style_joker_button(btn)
		btn.pressed.connect(_on_joker_pressed.bind(def.type))
		wrap.add_child(btn)

		var content := VBoxContainer.new()
		content.mouse_filter = Control.MOUSE_FILTER_IGNORE
		content.alignment = BoxContainer.ALIGNMENT_CENTER
		content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		content.add_theme_constant_override("separation", 2)
		btn.add_child(content)

		var icon_rect := TextureRect.new()
		icon_rect.texture = _icon(def.icon)
		icon_rect.custom_minimum_size = Vector2(18, 18)
		icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon_rect.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		content.add_child(icon_rect)

		var lbl := Label.new()
		lbl.text = def.label
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.add_theme_font_size_override("font_size", 10)
		lbl.add_theme_color_override("font_color", Color.WHITE)
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		content.add_child(lbl)

		var count_lbl := Label.new()
		count_lbl.text = "1 hak"
		count_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		count_lbl.add_theme_font_size_override("font_size", 9)
		count_lbl.add_theme_color_override("font_color", Color(1, 1, 1, 0.85))
		count_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		count_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		content.add_child(count_lbl)

		var plus := Button.new()
		plus.text = "+"
		plus.custom_minimum_size = Vector2(19, 19)
		plus.anchor_left = 1.0; plus.anchor_right = 1.0
		plus.offset_left = -13; plus.offset_right = 6
		plus.offset_top = -6; plus.offset_bottom = 13
		var plus_sb := StyleBoxFlat.new()
		plus_sb.bg_color = COL_ACCENT2
		plus_sb.set_corner_radius_all(10)
		plus.add_theme_stylebox_override("normal", plus_sb)
		plus.add_theme_stylebox_override("hover", plus_sb)
		plus.add_theme_stylebox_override("pressed", plus_sb)
		plus.add_theme_font_size_override("font_size", 12)
		plus.add_theme_color_override("font_color", Color("#08281F"))
		plus.pressed.connect(_on_buy_joker_pressed.bind(def.type))
		wrap.add_child(plus)

		joker_buttons[def.type] = btn
		joker_count_labels[def.type] = count_lbl


func _build_overlay() -> void:
	overlay = Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.visible = false
	add_child(overlay)

	var dim := ColorRect.new()
	dim.color = Color(0.04, 0.05, 0.09, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)

	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(240, 0)
	var sb := StyleBoxFlat.new()
	sb.bg_color = COL_CARD
	sb.set_corner_radius_all(18)
	sb.set_content_margin_all(20)
	card.add_theme_stylebox_override("panel", sb)
	center.add_child(card)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	card.add_child(vb)

	overlay_title = Label.new()
	overlay_title.add_theme_font_size_override("font_size", 18)
	overlay_title.add_theme_color_override("font_color", COL_INK)
	overlay_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(overlay_title)

	overlay_text = Label.new()
	overlay_text.add_theme_font_size_override("font_size", 13)
	overlay_text.add_theme_color_override("font_color", COL_INK_SOFT)
	overlay_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	overlay_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	overlay_text.custom_minimum_size = Vector2(200, 0)
	vb.add_child(overlay_text)

	overlay_button = Button.new()
	overlay_button.text = "Tamam"
	overlay_button.custom_minimum_size = Vector2(0, 40)
	var btn_sb := StyleBoxFlat.new()
	btn_sb.bg_color = COL_ACCENT
	btn_sb.set_corner_radius_all(12)
	overlay_button.add_theme_stylebox_override("normal", btn_sb)
	overlay_button.add_theme_stylebox_override("hover", btn_sb)
	overlay_button.add_theme_stylebox_override("pressed", btn_sb)
	overlay_button.add_theme_color_override("font_color", COL_ACCENT_INK)
	overlay_button.pressed.connect(_on_overlay_button_pressed)
	vb.add_child(overlay_button)


func _style_flat_button(btn: Button, color: Color, radius: int) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(radius)
	btn.add_theme_stylebox_override("normal", sb)
	btn.add_theme_stylebox_override("hover", sb)
	btn.add_theme_stylebox_override("pressed", sb)
	btn.add_theme_stylebox_override("focus", sb)


func _style_joker_button(btn: Button, dim: bool = false) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = COL_JOKER_BASE if not dim else COL_JOKER_BASE.darkened(0.35)
	sb.set_corner_radius_all(14)
	btn.add_theme_stylebox_override("normal", sb)
	var hover_sb: StyleBoxFlat = sb.duplicate()
	hover_sb.bg_color = sb.bg_color.lightened(0.08)
	btn.add_theme_stylebox_override("hover", hover_sb)
	btn.add_theme_stylebox_override("pressed", sb)
	btn.add_theme_stylebox_override("disabled", sb)
	btn.add_theme_stylebox_override("focus", sb)


func _style_tile_button(btn: Button, covered: bool) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = COL_TILE_TOP.lerp(COL_TILE_BASE, 0.5)
	if covered:
		sb.bg_color = sb.bg_color.darkened(0.22)
	sb.set_corner_radius_all(10)
	sb.border_width_bottom = 3
	sb.border_color = COL_TILE_EDGE
	btn.add_theme_stylebox_override("normal", sb)
	btn.add_theme_stylebox_override("disabled", sb)
	var hover_sb: StyleBoxFlat = sb.duplicate()
	hover_sb.bg_color = sb.bg_color.lightened(0.06)
	btn.add_theme_stylebox_override("hover", hover_sb)
	btn.add_theme_stylebox_override("pressed", hover_sb)
	btn.add_theme_stylebox_override("focus", sb)


# ------------------------------------------------------------------ Seviye

func _start_level(lvl: int, jokers_override = null) -> void:
	current_generation += 1
	GameState.new_level(lvl, jokers_override)
	armed_joker = ""
	board_frame.custom_minimum_size.y = GameState.board_h
	_render_all()
	call_deferred("_update_board_scale")


func _render_all() -> void:
	_render_board()
	_render_tray()
	_render_queue()
	_render_jokers()
	_update_stats()


func _update_stats() -> void:
	stat_level.text = "Seviye %d" % GameState.level
	stat_remaining.text = "Kalan: %d" % GameState.tiles.size()
	stat_matches.text = "Eşleşme: %d" % GameState.matches


func _update_board_scale() -> void:
	if GameState.board_w <= 0:
		return
	var avail: float = board_frame.size.x
	if avail <= 0:
		return
	board_scale = avail / GameState.board_w
	board_inner.scale = Vector2(board_scale, board_scale)
	board_frame.custom_minimum_size.y = GameState.board_h * board_scale


# ------------------------------------------------------------------- Tahta

func _render_board() -> void:
	for c in board_inner.get_children():
		c.queue_free()

	var sorted: Array = GameState.tiles.duplicate()
	sorted.sort_custom(func(a, b): return a.layer < b.layer)

	for tile in sorted:
		var clickable: bool = GameState.covering_count(tile) == 0
		var btn := Button.new()
		btn.position = Vector2(tile.x, tile.y)
		btn.size = Vector2(GameState.CELL, GameState.CELL)
		btn.icon = _icon("ic_" + tile.icon)
		btn.expand_icon = true
		btn.disabled = not clickable
		btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if clickable else Control.CURSOR_ARROW
		_style_tile_button(btn, not clickable)
		if clickable:
			btn.pressed.connect(_on_tile_pressed.bind(tile.id))
		board_inner.add_child(btn)


func _on_tile_pressed(id: String) -> void:
	if GameState.status != "playing":
		return
	if armed_joker == "removeTile":
		var idx: int = GameState.find_tile_index(id)
		if idx == -1:
			return
		if GameState.covering_count(GameState.tiles[idx]) > 0:
			return
		GameState.tiles.remove_at(idx)
		GameState.jokers.removeTile -= 1
		armed_joker = ""
		Audio.play_tone(420, 0.1, "sawtooth", 0.05)
		_render_board()
		_render_jokers()
		_update_stats()
		_check_end()
		return
	_collect(id)


func _collect(id: String) -> void:
	if GameState.status != "playing":
		return
	var idx: int = GameState.find_tile_index(id)
	if idx == -1:
		return
	var tile: Dictionary = GameState.tiles[idx]
	if GameState.covering_count(tile) > 0:
		return

	var reserved: int = GameState.tray.size() + GameState.flights_in_progress
	if reserved >= GameState.TRAY_MAX:
		return

	var source_btn: Button = null
	for c in board_inner.get_children():
		if c is Button and c.position == Vector2(tile.x, tile.y):
			source_btn = c
			break
	var source_rect: Rect2 = source_btn.get_global_rect() if source_btn else Rect2()

	var target_index: int = reserved
	var gen: int = current_generation

	GameState.tiles.remove_at(idx)
	_render_board()
	_update_stats()

	var slot: Control = tray_grid.get_child(target_index) if target_index < tray_grid.get_child_count() else null
	var target_rect: Rect2 = slot.get_global_rect() if slot else Rect2()

	GameState.flights_in_progress += 1

	if source_btn and slot:
		_fly_tile(tile.icon, source_rect, target_rect, func():
			_land_tile(tile, target_index, gen)
		)
	else:
		_land_tile(tile, target_index, gen)


func _fly_tile(icon: String, source_rect: Rect2, target_rect: Rect2, on_done: Callable) -> void:
	var clone := TextureRect.new()
	clone.texture = _icon("ic_" + icon)
	clone.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	clone.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	clone.size = source_rect.size
	clone.position = source_rect.position
	clone.pivot_offset = source_rect.size / 2.0
	fly_layer.add_child(clone)

	var target_scale: float = maxf(0.45, (target_rect.size.x / source_rect.size.x) * 0.9)
	var tw := create_tween()
	tw.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.set_parallel(true)
	tw.tween_property(clone, "position", target_rect.position + target_rect.size / 2.0 - source_rect.size * target_scale / 2.0, 0.4)
	tw.tween_property(clone, "scale", Vector2(target_scale, target_scale), 0.4)
	tw.chain().tween_callback(func():
		clone.queue_free()
		on_done.call()
	)


func _land_tile(tile: Dictionary, target_index: int, gen: int) -> void:
	if gen != current_generation:
		return
	GameState.flights_in_progress -= 1
	GameState.tray.append({"id": tile.id, "icon": tile.icon, "x": tile.x, "y": tile.y, "layer": tile.layer})
	_render_tray()
	Audio.play_tone(520, 0.08, "triangle", 0.045)
	_bump_slot(target_index)
	_check_match()


func _bump_slot(index: int) -> void:
	if index >= tray_grid.get_child_count():
		return
	var slot: Control = tray_grid.get_child(index)
	slot.pivot_offset = slot.size / 2.0
	slot.scale = Vector2(0.65, 0.65)
	var tw := create_tween()
	tw.tween_property(slot, "scale", Vector2(1, 1), 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


# -------------------------------------------------------------------- Sepet

func _render_tray() -> void:
	for c in tray_grid.get_children():
		c.queue_free()
	var danger: bool = GameState.tray.size() >= GameState.TRAY_MAX - 1
	for i in range(GameState.TRAY_MAX):
		var slot := Control.new()
		slot.custom_minimum_size = Vector2(38, 38)
		var sb := StyleBoxFlat.new()
		sb.bg_color = COL_TILE_TOP.lerp(COL_TILE_BASE, 0.5)
		sb.set_corner_radius_all(9)
		sb.border_width_bottom = 2
		sb.border_color = COL_DANGER if danger else COL_TILE_EDGE
		var bg := Panel.new()
		bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		bg.add_theme_stylebox_override("panel", sb)
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(bg)
		if i < GameState.tray.size():
			var icon_rect := TextureRect.new()
			icon_rect.texture = _icon("ic_" + GameState.tray[i].icon)
			icon_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			icon_rect.offset_left = 5; icon_rect.offset_top = 5; icon_rect.offset_right = -5; icon_rect.offset_bottom = -5
			icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
			slot.add_child(icon_rect)
		tray_grid.add_child(slot)


func _check_match() -> void:
	var counts: Dictionary = {}
	for t in GameState.tray:
		counts[t.icon] = counts.get(t.icon, 0) + 1
	var match_icon: String = ""
	for k in counts.keys():
		if counts[k] >= 3:
			match_icon = k
			break

	if match_icon == "":
		_check_end()
		return

	var slot_indices: Array = []
	for i in range(GameState.tray.size()):
		if GameState.tray[i].icon == match_icon and slot_indices.size() < 3:
			slot_indices.append(i)
	for i in slot_indices:
		if i < tray_grid.get_child_count():
			var slot: Control = tray_grid.get_child(i)
			slot.pivot_offset = slot.size / 2.0
			var tw := create_tween()
			tw.tween_property(slot, "scale", Vector2(1.3, 1.3), 0.13)
			tw.tween_property(slot, "modulate:a", 0.0, 0.2)
	Audio.play_chime()

	get_tree().create_timer(0.38).timeout.connect(func():
		var removed: int = 0
		var new_tray: Array = []
		for t in GameState.tray:
			if t.icon == match_icon and removed < 3:
				removed += 1
			else:
				new_tray.append(t)
		GameState.tray = new_tray
		GameState.matches += 1
		_render_tray()
		_update_stats()
		_play_cook_feedback()
		_advance_queue()
		_check_end()
	)


func _play_cook_feedback() -> void:
	var tw := create_tween()
	pot_icon.pivot_offset = pot_icon.size / 2.0
	tw.tween_property(pot_icon, "scale", Vector2(1.18, 1.18), 0.2)
	tw.tween_property(pot_icon, "scale", Vector2(1, 1), 0.2)
	var ctw := create_tween()
	chef_icon.pivot_offset = Vector2(chef_icon.size.x / 2.0, chef_icon.size.y)
	ctw.tween_property(chef_icon, "rotation", deg_to_rad(-6), 0.12)
	ctw.tween_property(chef_icon, "rotation", deg_to_rad(5), 0.12)
	ctw.tween_property(chef_icon, "rotation", 0.0, 0.12)


func _check_end() -> void:
	if GameState.tiles.is_empty() and GameState.status == "playing":
		GameState.status = "won"
		Audio.play_win_sound()
		_show_overlay("Seviye %d tamam!" % GameState.level, "Tebrikler, tüm müşteriler doydu.", "Sonraki Seviye", func():
			_start_level(GameState.level + 1)
		)
		return
	if GameState.tray.size() >= GameState.TRAY_MAX and GameState.status == "playing":
		GameState.status = "lost"
		Audio.play_lose_sound()
		_show_overlay("Tezgah doldu", "Aşçının tezgahı 7 malzemeyle doldu ama pes etme.", "Bu Seviyeyi Tekrar Dene", func():
			_start_level(GameState.level)
		)


# -------------------------------------------------------------------- Sıra

func _render_queue() -> void:
	for c in queue_row.get_children():
		c.queue_free()
	var remaining: int = GameState.queue_remaining()
	var visible: int = mini(GameState.QUEUE_VISIBLE, remaining)
	for i in range(visible):
		var ctype: String = GameState.queue[GameState.queue_served + i]
		var size: float = 44.0 if i == 0 else 36.0
		var chip := Control.new()
		chip.custom_minimum_size = Vector2(size, size)
		chip.name = "chip"
		var panel := Panel.new()
		panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		var sb := StyleBoxFlat.new()
		sb.bg_color = COL_TRAY_BG
		sb.set_corner_radius_all(int(size / 2))
		if i == 0:
			sb.border_width_top = 2; sb.border_width_bottom = 2; sb.border_width_left = 2; sb.border_width_right = 2
			sb.border_color = COL_ACCENT
		panel.add_theme_stylebox_override("panel", sb)
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		chip.add_child(panel)
		var icon_rect := TextureRect.new()
		icon_rect.texture = _icon("ic_" + ctype)
		icon_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		icon_rect.offset_left = 3; icon_rect.offset_top = 3; icon_rect.offset_right = -3; icon_rect.offset_bottom = -3
		icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		chip.add_child(icon_rect)
		queue_row.add_child(chip)
	if remaining > visible:
		var more := Label.new()
		more.text = "+%d" % (remaining - visible)
		more.add_theme_color_override("font_color", COL_INK_SOFT)
		more.add_theme_font_size_override("font_size", 11)
		queue_row.add_child(more)
	queue_count_label.text = str(remaining)


func _advance_queue() -> void:
	var front: Control = null
	for c in queue_row.get_children():
		if c.name == "chip":
			front = c
			break
	if front:
		var tw := create_tween()
		tw.tween_property(front, "modulate:a", 0.0, 0.22)
		tw.parallel().tween_property(front, "position:x", front.position.x - 14, 0.22)
	get_tree().create_timer(0.24).timeout.connect(func():
		GameState.queue_served += 1
		_render_queue()
	)


# ------------------------------------------------------------------ Joker

func _render_jokers() -> void:
	for def in JOKER_DEFS:
		var type: String = def.type
		var left: int = GameState.jokers[type]
		var btn: Button = joker_buttons[type]
		joker_count_labels[type].text = "%d hak" % left if left > 0 else "bitti"
		btn.disabled = left <= 0
		_style_joker_button(btn, left <= 0)
		if armed_joker == type:
			var sb: StyleBoxFlat = btn.get_theme_stylebox("normal").duplicate()
			sb.border_width_top = 3; sb.border_width_bottom = 3; sb.border_width_left = 3; sb.border_width_right = 3
			sb.border_color = COL_ACCENT2
			btn.add_theme_stylebox_override("normal", sb)
	sub_line.text = "Kaldırmak istediğin açık taşa dokun" if armed_joker == "removeTile" else "Taşları topla, 3'le eşleştir, aşçıya yetiştir"


func _on_joker_pressed(type: String) -> void:
	if GameState.status != "playing" or GameState.jokers[type] <= 0:
		return
	if type == "removeTile":
		armed_joker = "" if armed_joker == "removeTile" else "removeTile"
		_render_jokers()
		return
	if type == "undo":
		if GameState.tray.is_empty():
			return
		GameState.jokers.undo -= 1
		var last: Dictionary = GameState.tray.pop_back()
		GameState.tiles.append({"id": last.id, "icon": last.icon, "layer": last.layer, "x": last.x, "y": last.y})
		_render_board()
		_render_tray()
		_render_jokers()
		_update_stats()
		return

	GameState.jokers[type] -= 1
	if type == "shuffle":
		var icons: Array = []
		for t in GameState.tiles:
			icons.append(t.icon)
		icons.shuffle()
		for i in range(GameState.tiles.size()):
			GameState.tiles[i].icon = icons[i]
		_render_board()
		Audio.play_tone(700, 0.08, "triangle", 0.05)
	elif type == "restartLevel":
		var kept: Dictionary = GameState.jokers.duplicate()
		_start_level(GameState.level, kept)
		return
	_render_jokers()


func _on_buy_joker_pressed(type: String) -> void:
	var names := {"shuffle": "Karıştır", "restartLevel": "Baştan Başla", "removeTile": "Taşı Kaldır", "undo": "Geri Al"}
	_show_overlay(
		"%s jokerini yenile" % names[type],
		"Gerçek uygulamada burada mağazanın (App Store / Google Play) satın alma ekranı açılır. Bu prototipte jokerini hemen yeniliyoruz.",
		"Tamam, Yenile",
		func():
			GameState.jokers[type] = 1
			_render_jokers()
	)


# ------------------------------------------------------------------ Overlay

func _show_overlay(title: String, text: String, btn_label: String, action: Callable) -> void:
	overlay_title.text = title
	overlay_text.text = text
	overlay_button.text = btn_label
	overlay_action = action
	overlay.visible = true


func _on_overlay_button_pressed() -> void:
	overlay.visible = false
	var a: Callable = overlay_action
	overlay_action = Callable()
	if a.is_valid():
		a.call()


func _on_sound_pressed() -> void:
	Audio.sound_on = not Audio.sound_on
	sound_button.icon = _icon("ic_sound_on" if Audio.sound_on else "ic_sound_off")
	if Audio.sound_on:
		Audio.play_tone(700, 0.06, "triangle", 0.04)
