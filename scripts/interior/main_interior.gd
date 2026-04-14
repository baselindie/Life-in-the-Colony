extends Node2D

# -------------------------------------------------------------------
# NODOS (AHORA CORRECTOS: TileMapLayer)
# -------------------------------------------------------------------
@onready var queen = $Queen
@onready var camera = $Camera2D
@onready var construction_system = $ConstructionSystem
@onready var chamber_system = $ChamberSystem
@onready var chambers_container = $ChambersContainer
@onready var ground_tilemap: TileMapLayer = $GroundTileMap
@onready var structure_tilemap: TileMapLayer = $StructureTileMap

# -------------------------------------------------------------------
# UI
# -------------------------------------------------------------------
var resource_label = null
var population_label = null
var instruction_label = null
var tunnel_instructions = null
var build_button_ref: Button = null
var tooltip_label: Label = null

# -------------------------------------------------------------------
# RECURSOS Y POBLACIÓN
# -------------------------------------------------------------------
var colony_resources = {
	"food": 100.0,
	"fungus": 50.0,
	"protein": 10.0,
	"leaves": 0.0,
	"larvae_food": 30.0,
	"soil": 0.0
}

var colony_population = {
	"queen": 1,
	"worker_minima": 0,
	"worker_menor": 0,
	"worker_mediana": 0,
	"worker_mayor": 0,
	"larvae": 0,
	"pupae": 0,
	"eggs": 0
}

# -------------------------------------------------------------------
# PRODUCCIÓN DE OBRERAS
# -------------------------------------------------------------------
var production_queue = []
var max_queue_size = 4
var production_timer = 0.0
var production_interval = 2.0
var creation_panel = null
var developing_ants = []

# -------------------------------------------------------------------
# EXCAVACIÓN
# -------------------------------------------------------------------
var excavation_points = []          # Lista de tiles excavables (Vector2i)
var current_excavation_target: Vector2i
var pending_excavation_tile: Vector2i = Vector2i(-1, -1)
var is_excavating = false
var excavation_progress = 0.0
var excavation_speed = 1.0
var excavation_time_needed = 2.0

# -------------------------------------------------------------------
# GENERAL
# -------------------------------------------------------------------
var game_time: float = 0.0
var first_egg_laid: bool = false
var selected_ant: AntBase = null
var active_ants = []
var camera_target = null

# -------------------------------------------------------------------
# CONSTANTES DE TILES (¡AJUSTADAS SEGÚN TUS DATOS!)
# -------------------------------------------------------------------
const TILE_SOIL = 1               # El suelo en ground_tilemap tiene source_id = 1
const TILE_TUNNEL = 0             # Suponiendo que el túnel es el primer tile en structure_tilemap
const TILE_CHAMBER = 2            # Ajusta según tu tileset de estructura
const AUTO_GENERATE_SOIL = true   # Activar generación automática

# --- Lista de Patrones de Túnel Predefinidos ---
var tunnel_patterns = [
	# Patrón 0: Túnel pequeño de 1x1 (el original)
	{
		"cells": [[1]],
		"offset_x": 0,
		"offset_y": 0
	},
	# Patrón 1: Túnel en forma de cruz
	{
		"cells": [
			[0, 1, 0],
			[1, 1, 1],
			[0, 1, 0]
		],
		"offset_x": -1,
		"offset_y": -1
	},
	# Patrón 2: Túnel de 2x2
	{
		"cells": [
			[1, 1],
			[1, 1]
		],
		"offset_x": -1,
		"offset_y": -1
	},
	# Patrón 3: Túnel en forma de L
	{
		"cells": [
			[1, 0],
			[1, 1]
		],
		"offset_x": -1,
		"offset_y": -1
	},
	# Patrón 4: Túnel en línea recta horizontal
	{
		"cells": [
			[1, 1, 1]
		],
		"offset_x": -1,
		"offset_y": 0
	},
	# Patrón 5: Túnel en línea recta vertical
	{
		"cells": [
			[1],
			[1],
			[1]
		],
		"offset_x": 0,
		"offset_y": -1
	}
]
# -------------------------------------------------------------------
# CONSTRUCCIÓN
# -------------------------------------------------------------------
var construction_panel = null
var selected_tile_for_construction: Vector2i
var construction_mode = false

# -------------------------------------------------------------------
# READY
# -------------------------------------------------------------------
func _ready():
	print("=== 🏠 COLONIA ACROMYRMEX - CONSTRUYE TÚNELES ===")
	
	if queen:
		queen.is_player_controlled = true
	else:
		create_emergency_queen()
	
	setup_camera()
	setup_ui()
	
	if AUTO_GENERATE_SOIL:
		generate_initial_ground()
	
	create_initial_excavation_points()
	
	print("\n🎮 CONTROLES INTERIOR:")
	print("🖱️  CLICK en suelo excavable - La obrera va y excava")
	print("🔨 CLICK en túnel (modo construir) - Construir cámara")
	print("⛏️  ESPACIO - Excavar más rápido")
	print("🔍 WASD/Flechas - Mover cámara")
	print("📱 Rueda ratón - Zoom")
	print("📊 TAB - Debug")
	print("🎥 C - Seguir/Liberar cámara")
	print("🔍 R - Reset zoom")

# -------------------------------------------------------------------
# FUNCIONES DE INICIO
# -------------------------------------------------------------------
func create_emergency_queen():
	var queen_scene = load("res://scenes/actors/queen_acromyrmex.tscn")
	if queen_scene:
		queen = queen_scene.instantiate()
		queen.position = Vector2(400, 300)
		queen.name = "Queen"
		queen.is_player_controlled = true
		add_child(queen)
	else:
		print("❌ ERROR: No se pudo cargar la escena de la reina")

func setup_camera():
	if not camera:
		camera = Camera2D.new()
		camera.name = "Camera2D"
		add_child(camera)
	
	camera.zoom = Vector2(1.5, 1.5)
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 5.0
	camera.make_current()
	
	if queen:
		camera.position = queen.position
		camera_target = queen

func setup_ui():
	var ui_layer = CanvasLayer.new()
	ui_layer.name = "UILayer"
	ui_layer.layer = 10
	add_child(ui_layer)
	
	instruction_label = Label.new()
	instruction_label.name = "InstructionLabel"
	instruction_label.text = "🏗️  CONSTRUYE TÚNELES\nSelecciona una obrera y haz click en suelo excavable"
	instruction_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	instruction_label.position = Vector2(400, 30)
	instruction_label.add_theme_font_size_override("font_size", 18)
	ui_layer.add_child(instruction_label)
	
	tunnel_instructions = Label.new()
	tunnel_instructions.name = "TunnelInstructions"
	tunnel_instructions.text = "🖱️ CLICK: Mover/Excavar | 🔍 WASD: Mover cámara"
	tunnel_instructions.position = Vector2(20, 600)
	tunnel_instructions.add_theme_font_size_override("font_size", 14)
	ui_layer.add_child(tunnel_instructions)
	
	var vbox = VBoxContainer.new()
	vbox.name = "UIContainer"
	vbox.position = Vector2(20, 80)
	vbox.add_theme_constant_override("separation", 5)
	ui_layer.add_child(vbox)
	
	resource_label = Label.new()
	resource_label.name = "ResourceLabel"
	resource_label.text = get_resources_text()
	resource_label.add_theme_font_size_override("font_size", 12)
	vbox.add_child(resource_label)
	
	population_label = Label.new()
	population_label.name = "PopulationLabel"
	population_label.text = get_population_text()
	population_label.add_theme_font_size_override("font_size", 12)
	vbox.add_child(population_label)
	
	var create_button = Button.new()
	create_button.text = "➕ Crear Obrera"
	create_button.position = Vector2(700, 80)
	create_button.pressed.connect(_show_creation_panel)
	ui_layer.add_child(create_button)
	
	var build_button = Button.new()
	build_button.text = "🔨 Construir"
	build_button.position = Vector2(820, 80)
	build_button.toggle_mode = true
	build_button.pressed.connect(_toggle_construction_mode)
	ui_layer.add_child(build_button)
	build_button_ref = build_button
	
	tooltip_label = Label.new()
	tooltip_label.name = "TooltipLabel"
	tooltip_label.text = ""
	tooltip_label.position = Vector2(0, 0)
	tooltip_label.add_theme_font_size_override("font_size", 12)
	tooltip_label.modulate = Color(1, 1, 1, 0.9)
	tooltip_label.add_theme_color_override("font_color", Color.BLACK)
	tooltip_label.visible = false
	ui_layer.add_child(tooltip_label)

# -------------------------------------------------------------------
# GENERACIÓN DE SUELO EN ANILLO (para que la reina tenga espacio)
# -------------------------------------------------------------------
func generate_initial_ground():
	if not queen or not ground_tilemap:
		return
	
	var queen_cell = ground_tilemap.local_to_map(queen.global_position)
	var inner_radius = 3   # Espacio vacío alrededor de la reina (ahora 7x7)
	var outer_radius = 8   # Suelo hasta 8 tiles de distancia (área 17x17)
	
	var generated = 0
	for x in range(queen_cell.x - outer_radius, queen_cell.x + outer_radius + 1):
		for y in range(queen_cell.y - outer_radius, queen_cell.y + outer_radius + 1):
			var cell = Vector2i(x, y)
			var distance = max(abs(x - queen_cell.x), abs(y - queen_cell.y))
			
			if distance <= outer_radius and distance > inner_radius:
				if ground_tilemap.get_cell_source_id(cell) == -1:
					var variant = randi() % 4
					ground_tilemap.set_cell(cell, TILE_SOIL, Vector2i(variant, 0))
					generated += 1
			elif distance <= inner_radius:
				if ground_tilemap.get_cell_source_id(cell) != -1:
					ground_tilemap.set_cell(cell, -1)
	
	print("✅ Suelo generado: ", generated, " tiles en anillo (interior vacío de ", inner_radius*2+1, "x", inner_radius*2+1, ")")

# -------------------------------------------------------------------
# PUNTOS DE EXCAVACIÓN INICIALES (en el borde interior)
# -------------------------------------------------------------------
func create_initial_excavation_points():
	excavation_points.clear()
	
	if not queen or not ground_tilemap:
		return
	
	var queen_cell = ground_tilemap.local_to_map(queen.global_position)
	var candidates = []
	
	# Buscar en un radio de 3 a 8 (donde ahora hay suelo)
	for dx in range(-8, 9):
		for dy in range(-8, 9):
			var distance = max(abs(dx), abs(dy))
			if distance < 3 or distance > 8:
				continue
			var tile_pos = queen_cell + Vector2i(dx, dy)
			if ground_tilemap.get_cell_source_id(tile_pos) != TILE_SOIL:
				continue
			
			# Comprobar si tiene un vecino vacío hacia el centro
			var dir_to_center = Vector2i(-sign(dx), -sign(dy))
			var neighbor = tile_pos + dir_to_center
			if ground_tilemap.get_cell_source_id(neighbor) == -1:
				candidates.append(tile_pos)
	
	candidates.shuffle()
	var count = 0
	for tile_pos in candidates:
		if count >= 16:  # Ahora podemos tener más puntos (hasta 16)
			break
		excavation_points.append(tile_pos)
		count += 1
		print("➕ Punto excavable: ", tile_pos)
	
	print("🔵 ", count, " puntos de excavación iniciales")

# -------------------------------------------------------------------
# DETECCIÓN DE PUNTO EXCAVABLE
# -------------------------------------------------------------------
func get_excavation_point_at(pos: Vector2) -> Variant:
	var tile_pos = ground_tilemap.local_to_map(pos)
	if tile_pos in excavation_points:
		if ground_tilemap.get_cell_source_id(tile_pos) == TILE_SOIL:
			return tile_pos
		else:
			excavation_points.erase(tile_pos)
	return null

# -------------------------------------------------------------------
# SOLICITUD DE EXCAVACIÓN
# -------------------------------------------------------------------
func request_excavation(tile_pos: Vector2i, excavator: AntBase):
	if pending_excavation_tile != Vector2i(-1, -1):
		pending_excavation_tile = Vector2i(-1, -1)
		print("⏹️  Excavación pendiente cancelada")
	pending_excavation_tile = tile_pos
	excavator.set_target(ground_tilemap.map_to_local(tile_pos))
	print("🚶 Obrera yendo a excavar a ", tile_pos)

# -------------------------------------------------------------------
# INICIO DE EXCAVACIÓN
# -------------------------------------------------------------------
func start_excavation(tile_pos: Vector2i):
	# Evitar empezar una excavación si ya hay una en curso
	if is_excavating:
		print("⚠️  Ya se está excavando, no se puede empezar otra")
		return
	
	# Verificar que el tile sigue siendo suelo y está en la lista
	if tile_pos not in excavation_points:
		print("⚠️  El tile ", tile_pos, " ya no es excavable")
		return
	
	if ground_tilemap.get_cell_source_id(tile_pos) != TILE_SOIL:
		print("⚠️  El tile ", tile_pos, " ya no es suelo")
		excavation_points.erase(tile_pos)
		return
	
	current_excavation_target = tile_pos
	is_excavating = true
	excavation_progress = 0.0
	excavation_speed = 1.0
	print("⛏️  Comienza excavación en ", tile_pos)

# -------------------------------------------------------------------
# COMPLETAR EXCAVACIÓN
# -------------------------------------------------------------------
func complete_tunnel_excavation():
	print("✅ ¡Túnel excavado!")
	var variant = randi() % 4
	var atlas_coords = Vector2i(variant, 0)

	# 1. Seleccionar un patrón aleatorio
	var selected_pattern = tunnel_patterns[0]
	var pattern_cells = selected_pattern["cells"]
	var offset_x = selected_pattern["offset_x"]
	var offset_y = selected_pattern["offset_y"]

	# 2. Recorrer el patrón y colocar los tiles
	for y in range(pattern_cells.size()):
		for x in range(pattern_cells[y].size()):
			if pattern_cells[y][x] == 1:
				var tile_x = current_excavation_target.x + x + offset_x
				var tile_y = current_excavation_target.y + y + offset_y
				var tile_pos = Vector2i(tile_x, tile_y)

				structure_tilemap.set_cell(tile_pos, TILE_TUNNEL, atlas_coords)
				if ground_tilemap.get_cell_source_id(tile_pos) != -1:
					ground_tilemap.set_cell(tile_pos, -1)

	# 3. Eliminar el punto excavable original de la lista
	excavation_points.erase(current_excavation_target)

	# 4. Generar nuevos puntos alrededor del área excavada
	create_new_excavation_points(current_excavation_target)

	# 5. ¡CRUCIAL! Resetear todas las variables de excavación
	is_excavating = false
	excavation_progress = 0.0
	current_excavation_target = Vector2i(-1, -1)

	# 6. Actualizar UI
	instruction_label.text = "✅ TÚNEL COMPLETADO\n¡Puedes excavar más!"
	print("✅ Excavación finalizada correctamente")
# -------------------------------------------------------------------
# CREAR NUEVOS PUNTOS ALREDEDOR DE UN TÚNEL
# -------------------------------------------------------------------
func create_new_excavation_points(center_tile: Vector2i):
	var directions = [
		Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1),
		Vector2i(1,1), Vector2i(-1,1), Vector2i(1,-1), Vector2i(-1,-1)
	]
	directions.shuffle()
	var count = 0
	for dir in directions:
		if count >= 3:
			break
		var new_tile = center_tile + dir
		if ground_tilemap.get_cell_source_id(new_tile) == TILE_SOIL and structure_tilemap.get_cell_source_id(new_tile) == -1:
			if new_tile not in excavation_points:
				excavation_points.append(new_tile)
				count += 1
				print("➕ Nuevo punto excavable adyacente: ", new_tile)

# -------------------------------------------------------------------
# EFECTO VISUAL DE EXCAVACIÓN
# -------------------------------------------------------------------
func create_mining_effect(pos: Vector2):
	for i in range(2):
		var dust = Sprite2D.new()
		dust.position = pos + Vector2(randf_range(-15, 15), randf_range(-15, 15))
		dust.texture = create_dust_texture()
		dust.modulate = Color(0.7, 0.6, 0.4, 0.8)
		add_child(dust)
		var tween = create_tween()
		tween.tween_property(dust, "position", dust.position + Vector2(randf_range(-20, 20), -randf_range(30, 50)), 0.8)
		tween.parallel().tween_property(dust, "modulate:a", 0.0, 0.8)
		tween.tween_callback(dust.queue_free)

func create_dust_texture() -> Texture2D:
	var image = Image.create(6, 6, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.8, 0.7, 0.5, 1.0))
	for x in range(6):
		for y in range(6):
			var dx = x - 3
			var dy = y - 3
			if dx*dx + dy*dy > 9:
				image.set_pixel(x, y, Color(0, 0, 0, 0))
	return ImageTexture.create_from_image(image)

# -------------------------------------------------------------------
# CONSTRUCCIÓN DE CÁMARAS
# -------------------------------------------------------------------
func is_tunnel_at(tile_pos: Vector2i) -> bool:
	return structure_tilemap.get_cell_source_id(tile_pos) == TILE_TUNNEL

func _toggle_construction_mode():
	construction_mode = not construction_mode
	if build_button_ref:
		build_button_ref.modulate = Color.YELLOW if construction_mode else Color.WHITE
	print("🔨 Modo construcción:", " ACTIVADO" if construction_mode else " DESACTIVADO")

func _show_construction_panel(tile_pos: Vector2i):
	if construction_panel and is_instance_valid(construction_panel):
		construction_panel.queue_free()
	
	selected_tile_for_construction = tile_pos
	
	var panel = Panel.new()
	panel.size = Vector2(500, 400)
	panel.position = (get_viewport_rect().size - panel.size) / 2
	panel.modulate = Color(1, 1, 1, 0.95)
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.2, 0.2, 0.3, 0.9)
	style.border_color = Color(0.3, 0.7, 1.0, 0.9)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_right = 8
	style.corner_radius_bottom_left = 8
	panel.add_theme_stylebox_override("panel", style)
	
	var ui_layer = get_node("UILayer")
	ui_layer.add_child(panel)
	
	var title = Label.new()
	title.text = "CONSTRUIR CÁMARA"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(0, 20)
	title.size = Vector2(panel.size.x, 30)
	title.add_theme_font_size_override("font_size", 20)
	panel.add_child(title)
	
	var vbox = VBoxContainer.new()
	vbox.position = Vector2(50, 70)
	vbox.size = Vector2(400, 250)
	vbox.add_theme_constant_override("separation", 12)
	panel.add_child(vbox)
	
	var available = construction_system.get_available_chambers(colony_resources)
	for chamber in available:
		var btn = Button.new()
		btn.text = "%s (costo: %s)" % [chamber["name"], chamber["cost"]]
		btn.size = Vector2(380, 45)
		btn.pressed.connect(_on_build_chamber.bind(chamber["type"]))
		vbox.add_child(btn)
	
	var close_btn = Button.new()
	close_btn.text = "Cerrar"
	close_btn.position = Vector2(200, 330)
	close_btn.size = Vector2(100, 40)
	close_btn.pressed.connect(_close_construction_panel)
	panel.add_child(close_btn)
	
	construction_panel = panel

func _close_construction_panel():
	if construction_panel:
		construction_panel.queue_free()
		construction_panel = null

func _on_build_chamber(chamber_type: int):
	_close_construction_panel()
	
	if not construction_system.can_build_chamber(chamber_type, colony_resources):
		print("❌ No hay suficientes recursos")
		return
	
	var world_pos = structure_tilemap.map_to_local(selected_tile_for_construction)
	if not construction_system.start_construction(chamber_type, world_pos, colony_resources):
		return
	
	var atlas_coords = construction_system.chamber_data[chamber_type]["atlas_coords"]
	structure_tilemap.set_cell(selected_tile_for_construction, TILE_CHAMBER, atlas_coords)
	
	print("🎉 Cámara construida en %s" % selected_tile_for_construction)
	update_ui()

# -------------------------------------------------------------------
# CREACIÓN DE OBRERAS (PANEL)
# -------------------------------------------------------------------
func _show_creation_panel():
	if creation_panel and is_instance_valid(creation_panel):
		creation_panel.queue_free()
		creation_panel = null
		return
	
	var panel = Panel.new()
	panel.size = Vector2(500, 380)
	panel.position = (get_viewport_rect().size - panel.size) / 2
	panel.modulate = Color(1, 1, 1, 0.95)
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.2, 0.2, 0.3, 0.9)
	style.border_color = Color(1, 0.8, 0, 0.9)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_right = 8
	style.corner_radius_bottom_left = 8
	panel.add_theme_stylebox_override("panel", style)
	
	var ui_layer = get_node("UILayer")
	ui_layer.add_child(panel)
	
	var title = Label.new()
	title.text = "SELECCIONA CASTA"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(0, 20)
	title.size = Vector2(panel.size.x, 30)
	title.add_theme_font_size_override("font_size", 20)
	panel.add_child(title)
	
	var vbox = VBoxContainer.new()
	vbox.position = Vector2(50, 70)
	vbox.size = Vector2(400, 250)
	vbox.add_theme_constant_override("separation", 12)
	panel.add_child(vbox)
	
	var castas = [
		{ "caste": AntBase.AntCaste.WORKER_MINIMA, "text": "🌱 Mínima (jardinera)", "cost": 10 },
		{ "caste": AntBase.AntCaste.WORKER_MENOR, "text": "🍃 Menor (cortadora)", "cost": 15 },
		{ "caste": AntBase.AntCaste.WORKER_MEDIANA, "text": "🌿 Mediana (transportadora)", "cost": 20 },
		{ "caste": AntBase.AntCaste.WORKER_MAYOR, "text": "⚔️ Mayor (soldado)", "cost": 25 }
	]
	
	for c in castas:
		var btn = Button.new()
		btn.text = "%s (costo: %d comida)" % [c.text, c.cost]
		btn.size = Vector2(380, 45)
		btn.pressed.connect(_on_create_worker_from_panel.bind(c.caste, c.cost))
		vbox.add_child(btn)
	
	var close_btn = Button.new()
	close_btn.text = "Cerrar"
	close_btn.position = Vector2(200, 330)
	close_btn.size = Vector2(100, 40)
	close_btn.pressed.connect(_close_creation_panel)
	panel.add_child(close_btn)
	
	creation_panel = panel
	_update_panel_queue_info()

func _close_creation_panel():
	if creation_panel:
		creation_panel.queue_free()
		creation_panel = null

func _on_create_worker_from_panel(caste: AntBase.AntCaste, cost: int):
	if production_queue.size() >= max_queue_size:
		print("⚠️  Cola de producción llena (máx %d). Espera." % max_queue_size)
		return
	if colony_resources["food"] < cost:
		print("❌ No hay suficiente comida (necesitas %d)" % cost)
		return
	production_queue.append({ "caste": caste, "cost": cost })
	print("📦 Pedido añadido a la cola. Total: %d" % production_queue.size())
	if creation_panel and is_instance_valid(creation_panel):
		_update_panel_queue_info()

func _create_egg(caste: AntBase.AntCaste, cost: float):
	if colony_resources["food"] < cost:
		print("❌ No hay suficiente comida (necesitas %.0f)" % cost)
		return
	colony_resources["food"] -= cost
	var egg = Sprite2D.new()
	egg.texture = create_egg_texture()
	egg.scale = Vector2(0.3, 0.3)
	egg.position = queen.position + Vector2(randf_range(-30, 30), randf_range(-30, 30))
	add_child(egg)
	developing_ants.append({
		"caste": caste,
		"stage": "EGG",
		"timer": 5.0,
		"node": egg,
		"position": egg.position
	})
	colony_population["eggs"] += 1
	print("🥚 Huevo de %s puesto." % get_caste_display_name(caste))
	update_ui()
	if colony_population["eggs"] == 1 and not first_egg_laid:
		first_egg_laid = true
		queen.is_player_controlled = false
		print("👑 La reina ha puesto su primer huevo.")
		instruction_label.text = "🥚 PRIMER HUEVO - Ahora las obreras trabajan"

func _update_panel_queue_info():
	if not creation_panel or not is_instance_valid(creation_panel):
		return
	var queue_label = creation_panel.get_node_or_null("QueueLabel")
	if not queue_label:
		queue_label = Label.new()
		queue_label.name = "QueueLabel"
		queue_label.position = Vector2(50, 320)
		queue_label.size = Vector2(400, 30)
		queue_label.add_theme_font_size_override("font_size", 14)
		creation_panel.add_child(queue_label)
	var texto = "📦 Pedidos en cola: %d/%d" % [production_queue.size(), max_queue_size]
	if production_queue.size() > 0:
		texto += "\n⏳ Siguiente en %.1f s" % max(0, production_interval - production_timer)
	queue_label.text = texto

# -------------------------------------------------------------------
# SELECCIÓN DE OBRERAS
# -------------------------------------------------------------------
func _on_worker_clicked(_viewport: Node, event: InputEvent, _shape_idx: int, worker: AntBase):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if selected_ant and is_instance_valid(selected_ant):
			selected_ant.is_selected = false
			selected_ant.modulate = Color.WHITE
		selected_ant = worker
		worker.is_selected = true
		worker.modulate = Color.YELLOW
		print("🖱️  Obrera seleccionada: %s" % worker.get_display_name())

# -------------------------------------------------------------------
# _process Y _input
# -------------------------------------------------------------------
func _process(delta):
	game_time += delta
	update_tooltip()
	
	# Comprobar si la obrera llegó al punto de excavación
	if selected_ant and pending_excavation_tile != Vector2i(-1, -1) and not is_excavating:
		var target_world = ground_tilemap.map_to_local(pending_excavation_tile)
		if selected_ant.position.distance_to(target_world) < 40:
			start_excavation(pending_excavation_tile)
			pending_excavation_tile = Vector2i(-1, -1)
	
	# Manejo de la excavación en curso
	if is_excavating:
		excavation_progress += delta * excavation_speed
		var world_pos = ground_tilemap.map_to_local(current_excavation_target)
		if int(game_time * 5) % 2 == 0:
			create_mining_effect(world_pos)
		
		# Condición de finalización
		if excavation_progress >= excavation_time_needed:
			complete_tunnel_excavation()
		else:
			# Actualizar texto de progreso
			var percent = int((excavation_progress / excavation_time_needed) * 100)
			instruction_label.text = "⛏️  EXCAVANDO... %d%%" % percent
	else:
		# Si no se está excavando, mostrar instrucciones normales
		instruction_label.text = "🏗️  CONSTRUYE TÚNELES\nClick en suelo excavable"
	
	# Control de cámara (esto debe ir fuera del if is_excavating)
	if camera_target:
		camera.position = camera_target.position
	if not camera_target:
		var move_speed = 400.0 * delta * (1.0 / camera.zoom.x)
		var move = Vector2(Input.get_axis("ui_left", "ui_right"), Input.get_axis("ui_up", "ui_down"))
		if move.length() > 0:
			camera.position += move.normalized() * move_speed
	
	# Desarrollo de huevos, larvas y pupas
	for ant in developing_ants:
		ant.timer -= delta
		if ant.timer <= 0:
			match ant.stage:
				"EGG":
					ant.stage = "LARVA"
					ant.timer = 10.0
					if ant.node is Sprite2D:
						ant.node.texture = create_larvae_texture(ant.caste)
						ant.node.scale = Vector2(0.4, 0.4)
					colony_population["eggs"] -= 1
					colony_population["larvae"] += 1
					print("🐛 Huevo eclosionó a larva")
				"LARVA":
					ant.stage = "PUPA"
					ant.timer = 15.0
					if ant.node is Sprite2D:
						ant.node.texture = create_pupa_texture(ant.caste)
						ant.node.scale = Vector2(0.5, 0.5)
					colony_population["larvae"] -= 1
					colony_population["pupae"] += 1
					print("🪰 Larva se convierte en pupa")
				"PUPA":
					_create_adult_worker(ant.caste, ant.node.position)
					ant.node.queue_free()
					developing_ants.erase(ant)
					colony_population["pupae"] -= 1
					print("🦋 Pupa emerge como obrera")
			update_ui()
	
	# Producción en cola
	if production_queue.size() > 0:
		production_timer += delta
		if production_timer >= production_interval:
			production_timer = 0.0
			var pedido = production_queue.pop_front()
			_create_egg(pedido.caste, pedido.cost)
			update_ui()
			if creation_panel and is_instance_valid(creation_panel):
				_update_panel_queue_info()
	
	# Actualizar sistema de construcción
	construction_system.update_construction(delta)

func _input(event):
	# Clic izquierdo
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		# Ignorar si el ratón está sobre un elemento de la UI
		if get_viewport().gui_get_hovered_control() != null:
			return
		
		var mouse_pos = get_global_mouse_position()
		var clicked_tile = get_excavation_point_at(mouse_pos)
		
		# Caso 1: Clic en punto excavable
		if clicked_tile != null and not is_excavating:
			if selected_ant and selected_ant.is_alive():
				request_excavation(clicked_tile, selected_ant)
			else:
				print("❌ Selecciona una obrera para excavar")
			get_viewport().set_input_as_handled()
			return
		
		# Caso 2: Clic en túnel con modo construcción activado
		var tile_pos = structure_tilemap.local_to_map(mouse_pos)
		if construction_mode and structure_tilemap.get_cell_source_id(tile_pos) == TILE_TUNNEL:
			_show_construction_panel(tile_pos)
			get_viewport().set_input_as_handled()
			return
		
		# Caso 3: Clic en suelo normal (no excavable) o en cualquier otro sitio
		# Aquí movemos la entidad seleccionada, PERO si hay una excavación pendiente o en curso, NO la movemos
		if selected_ant and selected_ant.is_alive():
			# Si hay una excavación pendiente o en curso, no permitir mover la obrera
			if pending_excavation_tile != Vector2i(-1, -1) or is_excavating:
				print("⚠️  La obrera tiene una excavación pendiente o en curso, no se puede mover")
				get_viewport().set_input_as_handled()
				return
			selected_ant.set_target(mouse_pos)
			print("🐜 Obrera moviéndose a: ", mouse_pos)
		elif queen and queen.is_player_controlled and not first_egg_laid:
			queen.set_target(mouse_pos)
			print("👑 Reina moviéndose a: ", mouse_pos)
		
		get_viewport().set_input_as_handled()
		return
	
	# Zoom con rueda del ratón
	if event is InputEventMouseButton and camera:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			camera.zoom *= 1.1
			camera.zoom = camera.zoom.min(Vector2(3.0, 3.0))
			get_viewport().set_input_as_handled()
			return
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			camera.zoom *= 0.9
			camera.zoom = camera.zoom.max(Vector2(0.3, 0.3))
			get_viewport().set_input_as_handled()
			return
	
	# Teclas
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_SPACE:
				if is_excavating:
					excavation_speed = 2.0
			KEY_TAB:
				debug_colony_status()
			KEY_B:
				if not is_excavating:
					open_construction_menu()
			KEY_C:
				if camera_target:
					camera_target = null
				else:
					camera_target = selected_ant if selected_ant else queen
			KEY_R:
				camera.zoom = Vector2(1.5, 1.5)
		get_viewport().set_input_as_handled()

func update_tooltip():
	var mouse_pos = get_global_mouse_position()
	var tile_pos = get_excavation_point_at(mouse_pos)
	if tile_pos != null:
		tooltip_label.text = "⛏️ Ir a excavar (%.1fs)" % excavation_time_needed
		tooltip_label.visible = true
		var mouse_viewport = get_viewport().get_mouse_position()
		tooltip_label.position = mouse_viewport + Vector2(20, -30)
	else:
		tooltip_label.visible = false

# -------------------------------------------------------------------
# UI ACTUALIZACIÓN
# -------------------------------------------------------------------
func update_ui():
	if resource_label and is_instance_valid(resource_label):
		resource_label.text = get_resources_text()
	if population_label and is_instance_valid(population_label):
		population_label.text = get_population_text()

func get_resources_text() -> String:
	return """📊 RECURSOS:
🍯 Comida: %.1f
🍄 Hongos: %.1f
🥩 Proteína: %.1f
🍃 Hojas: %.1f
🪨 Tierra: %.1f""" % [
	colony_resources["food"],
	colony_resources["fungus"],
	colony_resources["protein"],
	colony_resources["leaves"],
	colony_resources.get("soil", 0.0)
]

func get_population_text() -> String:
	return """👥 POBLACIÓN:
👑 Reina: %d
🌿 Jardineras: %d
🍃 Cortadoras: %d
💪 Transportadoras: %d
⚔️ Soldados: %d""" % [
	colony_population["queen"],
	colony_population["worker_minima"],
	colony_population["worker_menor"],
	colony_population["worker_mediana"],
	colony_population["worker_mayor"]
]

func debug_colony_status():
	print("\n=== 🐜 DEBUG ===")
	print("Tiempo: %.1f s" % game_time)
	print("Puntos excavación: %d" % excavation_points.size())
	print("Excavando: %s" % is_excavating)
	print("Recursos: ", colony_resources)
	print("Población: ", colony_population)
	print("================")

func update_population_count(caste: AntBase.AntCaste, delta: int):
	match caste:
		AntBase.AntCaste.QUEEN:
			colony_population["queen"] += delta
		AntBase.AntCaste.WORKER_MINIMA:
			colony_population["worker_minima"] += delta
		AntBase.AntCaste.WORKER_MENOR:
			colony_population["worker_menor"] += delta
		AntBase.AntCaste.WORKER_MEDIANA:
			colony_population["worker_mediana"] += delta
		AntBase.AntCaste.WORKER_MAYOR:
			colony_population["worker_mayor"] += delta

# -------------------------------------------------------------------
# FUNCIONES AUXILIARES (sprites y nombres)
# -------------------------------------------------------------------
func get_random_worker_name(caste: AntBase.AntCaste) -> String:
	var names = ["Alfa", "Beta", "Gamma", "Delta", "Épsilon", "Zeta"]
	var prefix = ""
	match caste:
		AntBase.AntCaste.WORKER_MINIMA: prefix = "Mínima "
		AntBase.AntCaste.WORKER_MENOR: prefix = "Menor "
		AntBase.AntCaste.WORKER_MEDIANA: prefix = "Mediana "
		AntBase.AntCaste.WORKER_MAYOR: prefix = "Mayor "
	return prefix + names[randi() % names.size()]

func get_caste_display_name(caste: AntBase.AntCaste) -> String:
	match caste:
		AntBase.AntCaste.WORKER_MINIMA: return "Mínima"
		AntBase.AntCaste.WORKER_MENOR: return "Menor"
		AntBase.AntCaste.WORKER_MEDIANA: return "Mediana"
		AntBase.AntCaste.WORKER_MAYOR: return "Mayor"
		_: return "Obrera"

func create_egg_texture() -> Texture2D:
	var image = Image.create(16, 16, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	for x in range(16):
		for y in range(16):
			var dx = x - 8
			var dy = y - 8
			if dx*dx + dy*dy <= 40:
				image.set_pixel(x, y, Color(1, 1, 0.8, 1))
	return ImageTexture.create_from_image(image)

func create_larvae_texture(_caste: AntBase.AntCaste) -> Texture2D:
	var image = Image.create(16, 16, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	for x in range(16):
		for y in range(16):
			var dx = (x - 8) / 6.0
			var dy = (y - 8) / 4.0
			if dx*dx + dy*dy <= 1:
				image.set_pixel(x, y, Color(0.9, 0.8, 0.6, 1))
	return ImageTexture.create_from_image(image)

func create_pupa_texture(_caste: AntBase.AntCaste) -> Texture2D:
	var image = Image.create(16, 16, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	for x in range(16):
		for y in range(16):
			var dx = x - 8
			var dy = y - 8
			if dx*dx + dy*dy <= 36:
				image.set_pixel(x, y, Color(0.6, 0.5, 0.4, 1))
	return ImageTexture.create_from_image(image)

func _create_adult_worker(caste: AntBase.AntCaste, spawn_position: Vector2):
	var worker_scene = load("res://scenes/actors/workers/worker_base.tscn")
	if not worker_scene:
		print("❌ Error: No se encontró worker_base.tscn")
		return
	var worker = worker_scene.instantiate()
	worker.ant_caste = caste
	worker.ant_name = get_random_worker_name(caste)
	worker.is_player_controlled = false
	worker.position = spawn_position
	add_child(worker)
	
	var click_area = Area2D.new()
	var collision = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = 20
	collision.shape = shape
	click_area.add_child(collision)
	click_area.input_event.connect(_on_worker_clicked.bind(worker))
	worker.add_child(click_area)
	
	update_population_count(caste, 1)
	active_ants.append(worker)
	
	if first_egg_laid and active_ants.size() == 1:
		selected_ant = worker
		camera_target = worker
		worker.modulate = Color.YELLOW
		worker.is_selected = true
		print("🎮 Primera obrera seleccionada automáticamente.")
	
	update_ui()

func _on_worker_died(worker: AntBase):
	print("💀 Obrera %s ha muerto" % worker.get_display_name())
	active_ants.erase(worker)
	if selected_ant == worker:
		selected_ant = null
		camera_target = queen if queen.is_player_controlled else null
	update_ui()

func _on_worker_damaged(worker: AntBase, damage: float):
	print("💥 %s recibió %.1f de daño" % [worker.get_display_name(), damage])

# -------------------------------------------------------------------
# SISTEMAS DE CONSTRUCCIÓN (señales)
# -------------------------------------------------------------------
func open_construction_menu():
	print("🔨 Abriendo menú de construcción...")
	var available = construction_system.get_available_chambers(colony_resources)
	if available.size() == 0:
		print("❌ No hay recursos para construir cámaras")
		return
	print("\n=== 🏗️  MENÚ DE CONSTRUCCIÓN ===")
	for i in range(available.size()):
		var chamber = available[i]
		print("%d. %s" % [i+1, chamber["name"]])
		print("   Coste: %s" % chamber["cost"])
		print("   Tiempo: %.1f s" % chamber["build_time"])
		print("   %s" % chamber["description"])
		print("---")
	print("\nPresiona 1-%d para construir, E			SC para cancelar" % available.size())

func _on_construction_started(chamber_type, chamber_pos: Vector2):
	print("🏗️  Construcción iniciada: %s en %s" % [chamber_type, chamber_pos])

func _on_construction_completed(chamber_data):
	print("🎉 ¡Cámara completada: %s!" % chamber_data["name"])

func _on_construction_progress(_progress_percent):
	pass

func setup_chamber_system():
	pass

func setup_construction_system():
	if construction_system:
		construction_system.construction_started.connect(_on_construction_started)
		construction_system.construction_completed.connect(_on_construction_completed)
		construction_system.construction_progress_updated.connect(_on_construction_progress)
