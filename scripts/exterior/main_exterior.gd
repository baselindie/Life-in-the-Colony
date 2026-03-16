extends Node2D

# Referencias
@onready var spot_generator = $SpotGenerator
@onready var camera = $Camera2D
var queen = null

# Sistema de spots
var spots: Array = []
var current_hovered_spot = null
var current_selected_spot = null

# Sistema de fundación
var founding_progress: float = 0.0
var founding_time_required: float = 6.0
var is_founding: bool = false
var is_founding_complete: bool = false

# UI
var ui_layer = null
var instruction_label = null
var info_icon = null
var info_popup = null
var progress_container = null
var progress_bar = null
var confirmation_popup = null

# Mundo abierto
var world_size = Vector2(2000, 2000)
var chunk_size = 500
var generated_chunks = {}
var chunks_generation_distance: float = 1000.0
var last_generation_position: Vector2 = Vector2.ZERO
var generation_cooldown: float = 0.0

# Cámara
var camera_target = null
var camera_follow_speed: float = 5.0

func _ready():
	print("=== 🌍 MUNDO INFINITO - BUSCANDO LUGAR ===")
	
	setup_ui()
	create_queen()
	setup_camera()
	generate_initial_spots()
	
	print("\n🎮 CONTROLES:")
	print("🖱️  CLICK - Mover reina")
	print("🖱️  CLICK sobre spot - Seleccionar")
	print("🎯 F sobre spot seleccionado - Preparar fundación (6s)")
	print("🔍 WASD/Flechas - Mover cámara")
	print("📱 Scroll - Zoom")
	print("🌍 MUNDO: INFINITO")

func generate_initial_spots():
	print("🌱 Generando spots iniciales...")
	for i in range(10):
		var angle = randf() * PI * 2
		var distance = randf_range(200, 500)
		var pos = Vector2(400, 300) + Vector2(cos(angle), sin(angle)) * distance
		create_spot_at_position(pos)
	print("✅ ", spots.size(), " spots generados")

func setup_camera():
	if not camera:
		camera = Camera2D.new()
		camera.name = "Camera2D"
		add_child(camera)
	
	camera.zoom = Vector2(1.0, 1.0)
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = camera_follow_speed
	camera.make_current()
	
	if queen:
		camera_target = queen
		camera.position = queen.position
	else:
		camera_target = null
		camera.position = Vector2(500, 500)
	
	camera.limit_left = -100000
	camera.limit_top = -100000
	camera.limit_right = 100000
	camera.limit_bottom = 100000
	
	print("🎥 Cámara configurada para seguir a: ", "reina" if camera_target else "nada")

func _process(delta):
	check_hover_over_spots()
	
	if info_icon and current_hovered_spot:
		info_icon.position = current_hovered_spot.position + Vector2(0, -40)
		info_icon.visible = true
		if info_popup and info_popup.visible:
			info_popup.position = info_icon.position + Vector2(25, -120)
	else:
		if info_icon:
			info_icon.visible = false
		if info_popup:
			info_popup.visible = false
	
	if is_founding and current_selected_spot and not is_founding_complete:
		founding_progress += (100.0 / founding_time_required) * delta
		founding_progress = min(founding_progress, 100.0)
		progress_bar.value = founding_progress
		if founding_progress >= 100.0 and not is_founding_complete:
			on_founding_complete()
	
	update_instructions()
	
	generation_cooldown -= delta
	if generation_cooldown <= 0.0:
		generation_cooldown = 1.0
		generate_chunks_around_position(camera.position, chunks_generation_distance)
	
	update_ui_position()
	
	# Seguimiento suave de cámara
	if camera_target and camera:
		var target_pos = camera_target.position
		var current_pos = camera.position
		var distance = current_pos.distance_to(target_pos)
		if distance > 2.0:
			var follow_speed = camera_follow_speed * min(distance / 100.0, 2.0)
			var t = 1.0 - pow(0.5, delta * follow_speed)
			camera.position = current_pos.lerp(target_pos, t)
			
	# Movimiento de cámara con WASD (solo en modo libre)
	if not camera_target and camera:
		var camera_speed = 300.0 * (1.0 / camera.zoom.x) * delta
		if Input.is_action_pressed("ui_right"):
			camera.position.x += camera_speed
		if Input.is_action_pressed("ui_left"):
			camera.position.x -= camera_speed
		if Input.is_action_pressed("ui_down"):
			camera.position.y += camera_speed
		if Input.is_action_pressed("ui_up"):
			camera.position.y -= camera_speed

func generate_chunks_around_position(center_pos: Vector2, radius: float):
	var cam_chunk_x = int(center_pos.x / chunk_size)
	var cam_chunk_y = int(center_pos.y / chunk_size)
	var chunks_in_radius = int(radius / chunk_size) + 1
	for x in range(cam_chunk_x - chunks_in_radius, cam_chunk_x + chunks_in_radius + 1):
		for y in range(cam_chunk_y - chunks_in_radius, cam_chunk_y + chunks_in_radius + 1):
			var chunk_key = "%d_%d" % [x, y]
			if not generated_chunks.has(chunk_key):
				generate_chunk(x, y)
				generated_chunks[chunk_key] = true

func generate_chunk(chunk_x: int, chunk_y: int):
	var chunk_world_x = chunk_x * chunk_size
	var chunk_world_y = chunk_y * chunk_size
	var spots_in_chunk = randi_range(3, 5)
	for i in range(spots_in_chunk):
		var spot_x = chunk_world_x + randf_range(100, chunk_size - 100)
		var spot_y = chunk_world_y + randf_range(100, chunk_size - 100)
		var spot_pos = Vector2(spot_x, spot_y)
		create_spot_at_position(spot_pos)

func setup_ui():
	ui_layer = CanvasLayer.new()
	ui_layer.name = "UILayer"
	ui_layer.layer = 10
	add_child(ui_layer)
	
	instruction_label = Label.new()
	instruction_label.name = "InstructionLabel"
	instruction_label.text = "🏞️  EXPLORA EL MUNDO"
	instruction_label.position = Vector2(20, 20)
	instruction_label.add_theme_font_size_override("font_size", 18)
	ui_layer.add_child(instruction_label)
	
	progress_container = VBoxContainer.new()
	progress_container.name = "ProgressContainer"
	progress_container.position = Vector2(350, 100)
	progress_container.visible = false
	progress_container.add_theme_constant_override("separation", 5)
	ui_layer.add_child(progress_container)
	
	progress_bar = ProgressBar.new()
	progress_bar.name = "FoundingProgress"
	progress_bar.size = Vector2(200, 20)
	progress_bar.max_value = 100
	progress_bar.value = 0
	progress_container.add_child(progress_bar)
	
	create_info_icon()

func create_info_icon():
	info_icon = Sprite2D.new()
	info_icon.name = "InfoIcon"
	info_icon.texture = create_info_icon_texture()
	info_icon.scale = Vector2(0.5, 0.5)
	info_icon.visible = false
	info_icon.z_index = 5
	info_icon.modulate = Color(0.2, 0.5, 0.8, 0.9)
	add_child(info_icon)
	
	info_popup = Panel.new()
	info_popup.name = "InfoPopup"
	info_popup.size = Vector2(220, 140)
	info_popup.visible = false
	info_popup.z_index = 10
	info_popup.add_theme_stylebox_override("panel", create_transparent_panel_style())
	add_child(info_popup)
	
	var info_content = Label.new()
	info_content.name = "InfoContent"
	info_content.text = ""
	info_content.position = Vector2(15, 15)
	info_content.add_theme_font_size_override("font_size", 12)
	info_popup.add_child(info_content)

func create_info_icon_texture() -> Texture2D:
	var image = Image.create(32, 32, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	for x in range(32):
		for y in range(32):
			var dx = x - 16
			var dy = y - 16
			if dx*dx + dy*dy <= 144:
				image.set_pixel(x, y, Color(0.1, 0.6, 1.0, 0.9))
	for x in range(10, 22):
		for y in range(10, 22):
			if x >= 15 and x <= 17:
				image.set_pixel(x, y, Color(1, 1, 1, 1.0))
	return ImageTexture.create_from_image(image)

func create_transparent_panel_style() -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.2, 0.9)
	style.border_color = Color(0.3, 0.7, 1.0, 0.9)
	style.border_width_left = 3
	style.border_width_top = 3
	style.border_width_right = 3
	style.border_width_bottom = 3
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_right = 8
	style.corner_radius_bottom_left = 8
	style.shadow_color = Color(0, 0, 0, 0.5)
	style.shadow_size = 4
	return style

func create_queen():
	if has_node("Queen"):
		print("⚠️  Ya hay una reina en la escena, usando la existente")
		queen = $Queen
	else:
		var queen_scene = load("res://scenes/actors/queen_acromyrmex.tscn")
		if queen_scene:
			queen = queen_scene.instantiate()
			queen.position = Vector2(400, 300)
			queen.name = "Queen"
			queen.is_player_controlled = true
			add_child(queen)
			print("👑 Reina creada")
		else:
			print("❌ Error: No se pudo cargar la reina")

func check_hover_over_spots():
	var mouse_pos = get_global_mouse_position()
	var closest_spot = null
	var closest_distance = INF
	for spot in spots:
		if not is_instance_valid(spot):
			continue
		var distance = mouse_pos.distance_to(spot.position)
		if distance < 60:
			if distance < closest_distance:
				closest_distance = distance
				closest_spot = spot
	if closest_spot != current_hovered_spot:
		current_hovered_spot = closest_spot
		if closest_spot:
			show_spot_info(closest_spot)
		else:
			if info_popup:
				info_popup.visible = false

func _input(event):
	# Teclas globales (C y R) - SIEMPRE disponibles
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_C:
			if camera_target:
				set_camera_target(null)
				print("🎥 Cámara LIBERADA (WASD para mover)")
			else:
				if queen:
					set_camera_target(queen)
					print("🎥 Cámara SIGUIENDO a la reina")
				else:
					print("⚠️  No hay reina para seguir")
			get_viewport().set_input_as_handled()
			return
		
		if event.keycode == KEY_R and camera:
			camera.zoom = Vector2(1.0, 1.0)
			print("🔍 Zoom reseteado")
			get_viewport().set_input_as_handled()
			return
	
	# Zoom con rueda - SIEMPRE disponible
	if event is InputEventMouseButton and camera:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
		# Rueda arriba: alejar (zoom out)
			camera.zoom *= 1.1
			camera.zoom = camera.zoom.min(Vector2(3.0, 3.0))  # límite de alejamiento
			get_viewport().set_input_as_handled()
			return
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		# Rueda abajo: acercar (zoom in)
			camera.zoom *= 0.9
			camera.zoom = camera.zoom.max(Vector2(0.3, 0.3))  # límite de acercamiento
			get_viewport().set_input_as_handled()
			return
	
	# Click izquierdo - SOLO si NO hay popup visible
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		# Si el popup está visible, NO procesamos clics en el mundo
		if confirmation_popup and confirmation_popup.visible:
			return  # Dejamos que el popup maneje el evento (no hacemos return con handled)
		
		var mouse_pos = get_global_mouse_position()
		var clicked_spot = get_spot_at_position(mouse_pos)
		if clicked_spot:
			select_spot(clicked_spot)
			print("🎯 Spot seleccionado: %s" % clicked_spot.spot_name)
			show_spot_info(clicked_spot)
			get_viewport().set_input_as_handled()
			return
		elif queen:
			queen.move_to(mouse_pos)
			print("👑 Reina moviéndose a: %s" % mouse_pos)
			if not camera_target:
				set_camera_target(queen)
			get_viewport().set_input_as_handled()
			return
	
	# Tecla F - SIEMPRE disponible (pero respeta el popup)
	if event is InputEventKey and event.keycode == KEY_F:
		# Si el popup está visible, ignoramos la F (para no cancelar mientras se decide)
		if confirmation_popup and confirmation_popup.visible:
			return
		
		if event.pressed and current_selected_spot and not is_founding:
			start_founding()
			get_viewport().set_input_as_handled()
			return
		elif not event.pressed and is_founding and not is_founding_complete:
			cancel_founding("Soltaste F")
			get_viewport().set_input_as_handled()
			return

func get_spot_at_position(mouse_pos: Vector2)	:
	if spots.size() == 0:
		return null
	for spot in spots:
		if not is_instance_valid(spot):
			continue
		var detection_radius = 40.0
		if "detection_radius" in spot:
			detection_radius = spot.detection_radius
		elif "spot_radius" in spot:
			detection_radius = spot.spot_radius
		if mouse_pos.distance_to(spot.position) < detection_radius:
			return spot
	return null

func select_spot(spot):
	if current_selected_spot and current_selected_spot != spot:
		if "is_selected" in current_selected_spot:
			current_selected_spot.is_selected = false
	current_selected_spot = spot
	if "is_selected" in spot:
		spot.is_selected = true
	show_spot_info(spot)
	update_instructions()
	print("✅ Spot seleccionado: ", spot.name)

func show_spot_info(spot):
	if not info_popup:
		return
	var quality_levels = ["COMÚN", "BUENO", "EXCELENTE", "ÉPICO", "LEGENDARIO", "MÍTICO"]
	var quality_colors = [
		Color(0.7, 0.7, 0.7),
		Color(0.2, 0.8, 0.2),
		Color(0.2, 0.5, 1.0),
		Color(0.7, 0.2, 1.0),
		Color(1.0, 0.5, 0.0),
		Color(1.0, 0.8, 0.0)
	]
	var quality = 0
	if "spot_quality" in spot:
		quality = spot.spot_quality
	else:
		quality = randi() % 6
	quality = clamp(quality, 0, quality_levels.size() - 1)
	var quality_text = quality_levels[quality]
	var quality_color = quality_colors[quality]
	
	var bonuses = {
		"resource_multiplier": 1.0 + (quality * 0.15),
		"defense_bonus": quality * 0.1,
		"fertility_bonus": quality * 0.08
	}
	if spot.has_method("get_bonuses"):
		bonuses = spot.get_bonuses()
	
	var spot_name = "Lugar Desconocido"
	if "spot_name" in spot:
		spot_name = spot.spot_name
	
	var info_text = "📍 %s\n" % spot_name
	info_text += "⭐ %s\n\n" % quality_text
	info_text += "📊 Recursos: +%.0f%%\n" % ((bonuses["resource_multiplier"] - 1.0) * 100)
	info_text += "🛡️ Defensa: +%.0f%%\n" % (bonuses["defense_bonus"] * 100)
	info_text += "🌱 Fertilidad: +%.0f%%\n\n" % (bonuses["fertility_bonus"] * 100)
	info_text += "🎯 MANTÉN F para fundar"
	
	info_popup.get_node("InfoContent").text = info_text
	info_popup.get_node("InfoContent").autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info_popup.get_node("InfoContent").size = Vector2(190, 110)
	
	var style = create_transparent_panel_style()
	style.border_color = quality_color
	info_popup.add_theme_stylebox_override("panel", style)
	
	info_popup.visible = true
	info_popup.position = spot.position + Vector2(50, -140)

func update_instructions():
	if not instruction_label:
		return
	if current_selected_spot:
		var quality_levels = ["COMÚN", "BUENO", "EXCELENTE", "ÉPICO", "LEGENDARIO", "MÍTICO"]
		var quality = 0
		if "spot_quality" in current_selected_spot:
			quality = current_selected_spot.spot_quality
		quality = clamp(quality, 0, quality_levels.size() - 1)
		var quality_text = quality_levels[quality]
		var spot_name = "Spot"
		if "spot_name" in current_selected_spot:
			spot_name = current_selected_spot.spot_name
		if is_founding:
			instruction_label.text = "🏗️  FUNDANDO: %.0f%%\n📍 %s (%s)" % [founding_progress, spot_name, quality_text]
		else:
			instruction_label.text = "🎯 SPOT SELECCIONADO\n📍 %s (%s)\n🎯 MANTÉN F para fundar (6s)" % [spot_name, quality_text]
	else:
		instruction_label.text = "🏞️  EXPLORA EL MUNDO\n🖱️  CLICK: Mover reina\n🔍 PASA EL MOUSE sobre spots: Ver info"

func start_founding():
	if not current_selected_spot:
		print("⚠️  No hay spot seleccionado para fundar")
		return
	if is_founding:
		print("⚠️  Ya hay una fundación en progreso")
		return
	print("🏗️  Comenzando fundación en: ", current_selected_spot.name)
	is_founding = true
	is_founding_complete = false
	founding_progress = 0.0
	if progress_container:
		progress_container.visible = true
	if progress_bar:
		progress_bar.value = 0
	update_instructions()

func cancel_founding(reason: String):
	if is_founding:
		is_founding = false
		founding_progress = 0.0
		if progress_container:
			progress_container.visible = false
		print("❌ Fundación cancelada: %s" % reason)

func on_founding_complete():
	if is_founding_complete:  # 🛡️ Evita ejecutarse más de una vez
		return
	
	is_founding = false
	is_founding_complete = true
	progress_container.visible = false
	
	print("✅ ¡Spot preparado para fundación!")
	show_confirmation_popup()

func show_confirmation_popup():
	if not current_selected_spot:
		print("❌ ERROR: No hay spot seleccionado")
		return
	
	# Calidad del spot
	var quality_levels = ["COMÚN", "BUENO", "EXCELENTE", "ÉPICO", "LEGENDARIO", "MÍTICO"]
	var quality = 0
	if "spot_quality" in current_selected_spot:
		quality = current_selected_spot.spot_quality
	
	quality = clamp(quality, 0, quality_levels.size() - 1)
	var quality_text = quality_levels[quality]
	
	# Bonificaciones
	var bonuses = {
		"resource_multiplier": 1.0 + (quality * 0.15),
		"defense_bonus": quality * 0.1,
		"fertility_bonus": quality * 0.08
	}
	
	if current_selected_spot.has_method("get_bonuses"):
		bonuses = current_selected_spot.get_bonuses()
	
	# Nombre del spot
	var spot_name = "Este lugar"
	if "spot_name" in current_selected_spot:
		spot_name = current_selected_spot.spot_name
	
	# Si ya existe un popup, eliminarlo
	if confirmation_popup and is_instance_valid(confirmation_popup):
		confirmation_popup.queue_free()
	
	# Crear popup
	confirmation_popup = Panel.new()
	confirmation_popup.name = "ConfirmationPopup"
	confirmation_popup.size = Vector2(400, 250)  # Un poco más grande
	# Centrar en la pantalla
	confirmation_popup.position = (get_viewport_rect().size - confirmation_popup.size) / 2
	confirmation_popup.z_index = 1000
	confirmation_popup.mouse_filter = Control.MOUSE_FILTER_STOP  # ✅ Captura clics
	
	# Estilo visible (fondo azul sólido para asegurar visibilidad)
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.2, 0.4, 0.95)  # Azul oscuro semitransparente
	style.border_color = Color(1, 0.8, 0, 1)      # Borde dorado
	style.border_width_left = 4
	style.border_width_top = 4
	style.border_width_right = 4
	style.border_width_bottom = 4
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_right = 12
	style.corner_radius_bottom_left = 12
	confirmation_popup.add_theme_stylebox_override("panel", style)
	
	ui_layer.add_child(confirmation_popup)
	
	# Contenedor vertical
	var vbox = VBoxContainer.new()
	vbox.anchor_left = 0.0
	vbox.anchor_top = 0.0
	vbox.anchor_right = 1.0
	vbox.anchor_bottom = 1.0
	vbox.add_theme_constant_override("separation", 15)
	confirmation_popup.add_child(vbox)
	
	# Título
	var title = Label.new()
	title.text = "¿FUNDAR COLONIA AQUÍ?"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(1, 1, 0))
	vbox.add_child(title)
	
	# Mensaje
	var message = Label.new()
	message.text = "📍 %s\n⭐ %s\n\n📊 Recursos: +%.0f%%\n🛡️ Defensa: +%.0f%%\n🌱 Fertilidad: +%.0f%%" % [
		spot_name,
		quality_text,
		(bonuses["resource_multiplier"] - 1.0) * 100,
		bonuses["defense_bonus"] * 100,
		bonuses["fertility_bonus"] * 100
	]
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(message)
	
	# Botones
	var button_hbox = HBoxContainer.new()
	button_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	button_hbox.add_theme_constant_override("separation", 30)
	vbox.add_child(button_hbox)
	
	var yes_btn = Button.new()
	yes_btn.text = "✅ SÍ, FUNDAR"
	yes_btn.custom_minimum_size = Vector2(150, 50)
	yes_btn.pressed.connect(_on_yes_pressed)
	button_hbox.add_child(yes_btn)
	
	var no_btn = Button.new()
	no_btn.text = "❌ NO, BUSCAR MEJOR"
	no_btn.custom_minimum_size = Vector2(150, 50)
	no_btn.pressed.connect(_on_no_pressed)
	button_hbox.add_child(no_btn)
	
	print("🟢 Popup de confirmación mostrado")

func _on_yes_pressed():
	print("✅ Confirmado: Fundando colonia...")
	if confirmation_popup:
		confirmation_popup.queue_free()
		confirmation_popup = null
	start_excavation_sequence()

func _on_no_pressed():
	print("❌ Rechazado: Buscando otro lugar...")
	if confirmation_popup:
		confirmation_popup.queue_free()
		confirmation_popup = null
	var quality = 0
	if "spot_quality" in current_selected_spot:
		quality = current_selected_spot.spot_quality
	var spot_name = "Este lugar"
	if "spot_name" in current_selected_spot:
		spot_name = current_selected_spot.spot_name
	if quality <= 1:
		instruction_label.text = "💭 '%s' es decente\n🗺️ Pero hay mejores lugares\n🔍 ¡Sigue explorando!" % spot_name
	elif quality == 2:
		instruction_label.text = "🤔 '%s' es excelente\n💡 ¡Piénsalo bien!\n🌍 Podría ser tu mejor opción" % spot_name
	else:
		var epic_names = ["ÉPICO", "LEGENDARIO", "MÍTICO"]
		var epic_name = epic_names[quality - 3] if quality - 3 < epic_names.size() else "INCREÍBLE"
		instruction_label.text = "⚠️  ¡'%s' es %s!\n🎯 Es un lugar increíble\n💎 Asegúrate antes de rechazar" % [spot_name, epic_name]
	current_selected_spot = null
	is_founding = false
	is_founding_complete = false
	founding_progress = 0.0
	await get_tree().create_timer(4.0).timeout
	if info_popup:
		info_popup.visible = false
	instruction_label.text = "🏞️  EXPLORA EL MUNDO\n🖱️  CLICK: Mover reina\n🔍 PASA EL MOUSE sobre spots: Ver info"

func start_excavation_sequence():
	print("🚀 Iniciando excavación...")
	
	if not current_selected_spot:
		print("❌ ERROR: current_selected_spot es null")
		return
	
	# Calidad y nombre
	var quality = 1
	if "spot_quality" in current_selected_spot:
		quality = current_selected_spot.spot_quality
	
	var spot_name = "Colonia Sin Nombre"
	if "spot_name" in current_selected_spot:
		spot_name = current_selected_spot.spot_name
	
	# Bonificaciones
	var bonuses = {
		"resource_multiplier": 1.0 + (quality * 0.15),
		"defense_bonus": quality * 0.1,
		"fertility_bonus": quality * 0.08
	}
	
	if current_selected_spot.has_method("get_bonuses"):
		bonuses = current_selected_spot.get_bonuses()
	
	# Guardar datos en GLOBAL (autoload)
	GLOBAL.selected_settlement_spot = {
		"position": current_selected_spot.position,
		"name": spot_name,
		"quality": quality,
		"bonuses": bonuses
	}
	
	print("📦 Datos guardados en GLOBAL: ", GLOBAL.selected_settlement_spot)
	switch_to_interior_scene()

func switch_to_interior_scene():
	print("🚪 Cambiando a mundo interior...")
	var interior_path = "res://scenes/interior/main_interior.tscn"
	if not ResourceLoader.exists(interior_path):
		print("❌ ERROR: No se encuentra la escena en: ", interior_path)
		var posibles = [
			"res://scenes/interior/main_interior.tscn",
			"res://interior/main_interior.tscn",
			"res://main_interior.tscn"
		]
		var found = false
		for path in posibles:
			if ResourceLoader.exists(path):
				interior_path = path
				print("✅ Encontrada en: ", path)
				found = true
				break
		if not found:
			print("❌ No se encontró ninguna escena interior")
			show_error_message("No se encuentra la escena interior")
			return
	
	var transition = ColorRect.new()
	transition.color = Color(0, 0, 0, 0)
	transition.size = get_viewport_rect().size
	transition.mouse_filter = Control.MOUSE_FILTER_IGNORE
	transition.z_index = 1000
	ui_layer.add_child(transition)
	
	var tween = create_tween()
	tween.tween_property(transition, "color", Color(0, 0, 0, 1), 1.0)
	await tween.finished
	
	var interior_scene = load(interior_path)
	if interior_scene:
		get_tree().change_scene_to_packed(interior_scene)
	else:
		print("❌ Error al cargar la escena")
		show_error_message("Error al cargar la escena interior")

func show_error_message(text: String):
	var error_label = Label.new()
	error_label.text = "❌ " + text
	error_label.add_theme_font_size_override("font_size", 24)
	error_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	error_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	error_label.size = get_viewport_rect().size
	error_label.modulate = Color(1, 0.3, 0.3, 1)
	ui_layer.add_child(error_label)
	await get_tree().create_timer(3.0).timeout
	error_label.queue_free()

func create_spot_at_position(pos: Vector2):
	if spot_generator and spot_generator.has_method("create_spot"):
		var spot = spot_generator.create_spot(pos)
		if spot:
			spots.append(spot)
			print("📍 Spot generado por generator en: ", pos)
	else:
		var spot = Area2D.new()
		spot.position = pos
		spot.name = "SettlementSpot_%d_%d" % [int(pos.x), int(pos.y)]
		
		var collider = CollisionShape2D.new()
		var shape = CircleShape2D.new()
		shape.radius = 30.0
		collider.shape = shape
		spot.add_child(collider)
		
		var sprite = Sprite2D.new()
		sprite.texture = create_spot_texture()
		sprite.scale = Vector2(0.5, 0.5)
		spot.add_child(sprite)
		
		var script_path = "res://scripts/exterior/world/settlement_spot_clean.gd"
		if ResourceLoader.exists(script_path):
			spot.set_script(load(script_path))
			print("✅ Script cargado: ", script_path)
		else:
			print("⚠️  Script no encontrado, usando propiedades básicas")
		
		spot.spot_name = generate_spot_name()
		spot.spot_quality = randi() % 5 + 1
		
		if "spot_radius" in spot:
			spot.spot_radius = 40.0
		else:
			print("⚠️  Nota: spot_radius no disponible en el script")
		
		spot.add_to_group("settlement_spots")
		add_child(spot)
		spots.append(spot)
		print("📍 Spot manual creado: ", spot.spot_name, " calidad: ", spot.spot_quality, " en: ", pos)

func create_spot_texture() -> Texture2D:
	var image = Image.create(32, 32, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	for x in range(32):
		for y in range(32):
			var dx = (x - 16) / 16.0
			var dy = (y - 16) / 16.0
			if dx*dx + dy*dy <= 1.0:
				var quality = randf()
				if quality < 0.2:
					image.set_pixel(x, y, Color(0.6, 0.6, 0.6, 0.8))
				elif quality < 0.4:
					image.set_pixel(x, y, Color(0.2, 0.8, 0.2, 0.8))
				elif quality < 0.6:
					image.set_pixel(x, y, Color(0.2, 0.5, 1.0, 0.8))
				elif quality < 0.75:
					image.set_pixel(x, y, Color(0.7, 0.2, 1.0, 0.8))
				elif quality < 0.9:
					image.set_pixel(x, y, Color(1.0, 0.5, 0.0, 0.8))
				else:
					image.set_pixel(x, y, Color(1.0, 0.8, 0.0, 0.8))
	return ImageTexture.create_from_image(image)

func generate_spot_name() -> String:
	var prefixes = ["Valle", "Colina", "Bosque", "Pradera", "Claro", "Cañón", "Llanura"]
	var suffixes = ["Verde", "Dorado", "Azul", "Antiguo", "Silencioso", "Fértil", "Sereno"]
	return "%s %s" % [prefixes[randi() % prefixes.size()], suffixes[randi() % suffixes.size()]]

func set_camera_target(target):
	camera_target = target
	if camera_target:
		print("🎥 Cámara SIGUIENDO a: %s" % camera_target.name)
		if camera_target == queen and camera:
			camera.position = queen.position
		update_camera_instructions()
	else:
		print("🎥 Cámara en MODO LIBRE (WASD para mover)")
		update_camera_instructions()

func update_camera_instructions():
	var camera_mode_text = "🎥 Cámara: %s" % ["LIBRE (WASD)" if not camera_target else "SIGUIENDO reina"]
	print(camera_mode_text)

func update_ui_position():
	pass
