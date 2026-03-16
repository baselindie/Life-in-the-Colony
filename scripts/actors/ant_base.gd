extends CharacterBody2D
class_name AntBase

# ========== ENUMS ==========
enum AntState {
	IDLE,        # Esperando
	MOVING,      # Moviéndose a destino
	WORKING,     # Trabajando (recolectando, etc.)
	RETURNING,   # Regresando a colonia
	ATTACKING,   # Atacando
	DEFENDING,   # Defendiendo
	FEEDING      # Alimentando larvas/hongos
}

# CASTAS REALES DE ACROMYRMEX (¡BIOLÓGICAMENTE CORRECTO!)
enum AntCaste {
	QUEEN,           # Reina (fundadora)
	WORKER_MINIMA,   # Mínimas (Jardineras/Enfermeras, 3-5mm)
	WORKER_MENOR,    # Menores (Cortadoras pequeñas, 5-7mm)
	WORKER_MEDIANA,  # Medianas (Transportadoras, 7-10mm)
	WORKER_MAYOR,    # Mayores (Soldados/Dinergates, 10-15mm)
	LARVA,           # Larva (en desarrollo)
	PUPA             # Pupa (metamorfosis)
}

# ========== VARIABLES EXPORTADAS ==========
@export var ant_caste: AntCaste = AntCaste.WORKER_MENOR  # Casta de la hormiga
@export var move_speed: float = 100.0                    # Velocidad base
@export var max_health: float = 100.0                    # Salud base
@export var carry_capacity: float = 10.0                 # Capacidad base
@export var attack_damage: float = 10.0                  # Daño base
@export var defense: float = 5.0                         # Defensa base
@export var ant_size: float = 1.0                        # Escala visual (1.0 = normal)
@export var ant_name: String = ""                        # Nombre opcional

# ========== VARIABLES INTERNAS ==========
var current_health: float                    # Salud actual
var state: AntState = AntState.IDLE          # Estado actual
var target_position: Vector2 = Vector2.ZERO  # Posición objetivo
var is_carrying: bool = false                # ¿Está cargando algo?
var carried_amount: float = 0.0              # Cuánto está cargando
var carried_resource: String = ""            # Tipo de recurso cargado
var caste_stats: Dictionary = {}             # Stats según casta
var special_abilities: Array[String] = []    # Habilidades especiales
var development_stage: String = "ADULT"      # ADULT, LARVA, PUPA
var current_task: String = "NONE"            # Tarea actual
var is_player_controlled: bool = false       # ¿Controlada por jugador?
var colony_id: String = ""                   # ID de colonia a la que pertenece
var is_selected: bool = false  # Si la hormiga está seleccionada por el jugador
# Señales para comunicación
signal ant_died(ant_node)
signal ant_damaged(ant_node, damage_taken)
signal ant_task_completed(ant_node, task_type)
signal ant_resource_delivered(ant_node, resource_type, amount)

# ========== READY ==========
func _ready() -> void:
	# Inicializar según casta
	initialize_caste_stats()
	current_health = max_health
	
	# Ajustar escala visual según tamaño
	scale = Vector2(ant_size, ant_size)
	
	# Ajustar collision shape si existe
	adjust_collision_for_size()
	
	# Imprimir info (solo en debug)
	print_ant_info()

# ... (el resto del script continúa igual) ...

# ========== INICIALIZACIÓN DE CASTAS ==========
func initialize_caste_stats() -> void:
	# Resetear stats
	caste_stats.clear()
	special_abilities.clear()
	
	match ant_caste:
		AntCaste.QUEEN:
			caste_stats = {
				"display_name": "REINA ACROMYRMEX",
				"size_mm": 15.0,
				"base_speed": 80.0,
				"base_health": 500.0,
				"base_attack": 5.0,
				"base_defense": 20.0,
				"base_carry": 50.0,
				"description": "Fundadora de la colonia, pone huevos",
				"color": Color(0.8, 0.6, 0.9),  # Púrpura real
				"can_lay_eggs": false,
				"egg_production_rate": 0.1,  # Huevos por segundo
				"food_consumption": 0.5      # Comida por segundo
			}
			special_abilities = ["Poner huevos", "Fundar colonias", "Feromonas reales", "Liderazgo"]
			ant_size = 1.5
			move_speed = caste_stats["base_speed"]
			max_health = caste_stats["base_health"]
			carry_capacity = caste_stats["base_carry"]
			attack_damage = caste_stats["base_attack"]
			defense = caste_stats["base_defense"]
			development_stage = "ADULT"
		
		AntCaste.WORKER_MINIMA:
			caste_stats = {
				"display_name": "OBRERA MÍNIMA (Jardineras)",
				"size_mm": 4.0,
				"base_speed": 120.0,
				"base_health": 30.0,
				"base_attack": 5.0,
				"base_defense": 3.0,
				"base_carry": 10.0,
				"description": "Cuida larvas y mantiene jardín de hongos",
				"color": Color(0.6, 0.8, 0.4),  # Verde claro
				"nursing_efficiency": 1.5,      # Eficiencia cuidando
				"fungus_growth_bonus": 0.2,     # Bonus crecimiento hongos
				"food_consumption": 0.1
			}
			special_abilities = ["Cuidar crías", "Mantener hongos", "Limpieza", "Alimentar larvas"]
			ant_size = 0.8
			move_speed = caste_stats["base_speed"]
			max_health = caste_stats["base_health"]
			carry_capacity = caste_stats["base_carry"]

			defense = caste_stats["base_defense"]
			development_stage = "ADULT"
		
		AntCaste.WORKER_MENOR:
			caste_stats = {
				"display_name": "OBRERA MENOR (Cortadoras)",
				"size_mm": 6.0,
				"base_speed": 100.0,
				"base_health": 50.0,
				"base_attack": 15.0,
				"base_defense": 8.0,
				"base_carry": 25.0,
				"description": "Recolecta y corta material vegetal fino",
				"color": Color(0.7, 0.5, 0.3),  # Marrón claro
				"foraging_efficiency": 1.2,     # Eficiencia recolectando
				"cutting_speed": 1.0,          # Velocidad corte
				"food_consumption": 0.15
			}
			special_abilities = ["Cortar hojas", "Recolectar", "Transporte ligero", "Navegación"]
			ant_size = 1.0
			move_speed = caste_stats["base_speed"]
			max_health = caste_stats["base_health"]
			carry_capacity = caste_stats["base_carry"]
			attack_damage = caste_stats["base_attack"]
			defense = caste_stats["base_defense"]
			development_stage = "ADULT"
		
		AntCaste.WORKER_MEDIANA:
			caste_stats = {
				"display_name": "OBRERA MEDIANA (Transportadoras)",
				"size_mm": 8.5,
				"base_speed": 70.0,
				"base_health": 80.0,
				"base_attack": 25.0,
				"base_defense": 15.0,
				"base_carry": 50.0,
				"description": "Transporta cargas pesadas y corta trozos grandes",
				"color": Color(0.5, 0.4, 0.2),  # Marrón oscuro
				"strength_multiplier": 2.0,     # Multiplicador fuerza
				"heavy_carry_bonus": 0.3,       # Bonus carga pesada
				"food_consumption": 0.2
			}
			special_abilities = ["Transporte pesado", "Corte grande", "Fuerza", "Resistencia"]
			ant_size = 1.3
			move_speed = caste_stats["base_speed"]
			max_health = caste_stats["base_health"]
			carry_capacity = caste_stats["base_carry"]
			attack_damage = caste_stats["base_attack"]
			defense = caste_stats["base_defense"]
			development_stage = "ADULT"
		
		AntCaste.WORKER_MAYOR:
			caste_stats = {
				"display_name": "OBRERA MAYOR (Soldados)",
				"size_mm": 12.0,
				"base_speed": 60.0,
				"base_health": 150.0,
				"base_attack": 45.0,
				"base_defense": 25.0,
				"base_carry": 30.0,
				"description": "Defiende la colonia y protege el forrajeo",
				"color": Color(0.8, 0.2, 0.2),  # Rojo oscuro
				"attack_range": 40.0,           # Rango de ataque
				"defense_aura": 10.0,           # Bonus defensa para aliados cercanos
				"intimidation": 1.5,            # Factor intimidación
				"food_consumption": 0.3
			}
			special_abilities = ["Defensa", "Ataque", "Protección", "Intimidación", "Patrullaje"]
			ant_size = 1.6
			move_speed = caste_stats["base_speed"]
			max_health = caste_stats["base_health"]
			carry_capacity = caste_stats["base_carry"]
			attack_damage = caste_stats["base_attack"]
			defense = caste_stats["base_defense"]
			development_stage = "ADULT"
		
		AntCaste.LARVA:
			caste_stats = {
				"display_name": "LARVA",
				"size_mm": 2.0,
				"base_speed": 0.0,
				"base_health": 10.0,
				"base_attack": 0.0,
				"base_defense": 1.0,
				"base_carry": 0.0,
				"description": "Etapa de crecimiento, necesita cuidado",
				"color": Color(0.9, 0.9, 0.7),  # Amarillo pálido
				"growth_rate": 0.01,            # Crecimiento por segundo
				"food_requirement": 0.05,       # Comida necesaria por segundo
				"care_requirement": 1.0         # Nivel de cuidado necesario
			}
			special_abilities = ["Crecer", "Comer", "Metamorfosear"]
			ant_size = 0.5
			move_speed = caste_stats["base_speed"]
			max_health = caste_stats["base_health"]
			carry_capacity = caste_stats["base_carry"]
			attack_damage = caste_stats["base_attack"]
			defense = caste_stats["base_defense"]
			development_stage = "LARVA"
		
		AntCaste.PUPA:
			caste_stats = {
				"display_name": "PUPA",
				"size_mm": 5.0,
				"base_speed": 0.0,
				"base_health": 20.0,
				"base_attack": 0.0,
				"base_defense": 2.0,
				"base_carry": 0.0,
				"description": "Metamorfosis, se transforma en adulto",
				"color": Color(0.7, 0.7, 0.5),  # Beige
				"metamorphosis_time": 60.0,     # Segundos para metamorfosis
				"protection_required": 1.0,     # Nivel protección necesario
				"final_caste": AntCaste.WORKER_MENOR  # Casta por defecto
			}
			special_abilities = ["Metamorfosis", "Desarrollo", "Transformación"]
			ant_size = 0.7
			move_speed = caste_stats["base_speed"]
			max_health = caste_stats["base_health"]
			carry_capacity = caste_stats["base_carry"]
			attack_damage = caste_stats["base_attack"]
			defense = caste_stats["base_defense"]
			development_stage = "PUPA"
	
	# Aplicar color si hay Sprite2D
	apply_caste_color()

# ========== AJUSTAR COLISIÓN ==========
func adjust_collision_for_size() -> void:
	if has_node("CollisionShape2D"):
		var collision = $CollisionShape2D
		var shape = collision.shape
		
		if shape is CircleShape2D:
			# Ajustar radio según tamaño
			shape.radius = 10.0 * ant_size
		elif shape is RectangleShape2D:
			# Ajustar extensión
			shape.extents = Vector2(8.0 * ant_size, 8.0 * ant_size)

# ========== APLICAR COLOR DE CASTA ==========
func apply_caste_color() -> void:
	if has_node("Sprite2D") and caste_stats.has("color"):
		$Sprite2D.modulate = caste_stats["color"]

# ========== IMPRIMIR INFORMACIÓN ==========
func print_ant_info() -> void:
	var caste_name = caste_stats.get("display_name", "DESCONOCIDA")
	var description = caste_stats.get("description", "")
	
	print("🐜 HORMIGA CREADA: %s" % caste_name)
	if ant_name != "":
		print("   📛 Nombre: %s" % ant_name)
	print("   📏 Tamaño: %.1f mm (Escala: %.1fx)" % [caste_stats.get("size_mm", 0), ant_size])
	print("   ❤️  Salud: %.1f/%.1f" % [current_health, max_health])
	print("   🏃 Velocidad: %.0f" % move_speed)
	print("   ⚔️  Ataque: %.0f" % attack_damage)
	print("   🛡️  Defensa: %.0f" % defense)
	print("   📦 Capacidad: %.1f" % carry_capacity)
	print("   🔧 Habilidades: %s" % ", ".join(special_abilities))
	print("   📝 %s" % description)

# ========== FÍSICA POR FRAME ==========
func _physics_process(delta: float) -> void:
	# Larvas y pupas no se mueven
	if development_stage != "ADULT":
		velocity = Vector2.ZERO
		
		# Procesar crecimiento si es larva
		if development_stage == "LARVA":
			process_larva_growth(delta)
		
		return
	
	# Dependiendo del estado, hacer algo diferente
	match state:
		AntState.MOVING:
			_move_to_target(delta)
		AntState.IDLE:
			_idle_behavior(delta)
		AntState.WORKING:
			_work_behavior(delta)
		AntState.RETURNING:
			_return_behavior(delta)
		AntState.ATTACKING:
			_attack_behavior(delta)
		AntState.DEFENDING:
			_defend_behavior(delta)
		AntState.FEEDING:
			_feed_behavior(delta)

# ========== MOVIMIENTO ==========
# Opción más simple: ELIMINAR la rotación completamente
func _move_to_target(_delta: float) -> void:
	# Si ya llegó, cambiar a IDLE
	if global_position.distance_to(target_position) < 5.0:
		state = AntState.IDLE
		print("📍 %s llegó a destino" % get_display_name())
		return
	
	# Calcular dirección y moverse SIN ROTAR
	var direction = (target_position - global_position).normalized()
	velocity = direction * move_speed
	move_and_slide()
	
	# ⭐⭐⭐ NO ROTAR NADA - VISTA TOP-DOWN CLÁSICA ⭐⭐⭐
# ========== COMPORTAMIENTOS BASE ==========
func _idle_behavior(_delta):
		# DEBUG: cada 60 frames (aprox 1 segundo a 60fps) muestra el estado
	if Engine.get_frames_drawn() % 60 == 0:
		print("DEBUG %s: is_selected = %s, state = %s" % [get_display_name(), is_selected, AntState.keys()[state]])
	
	if ant_caste == AntCaste.QUEEN or development_stage != "ADULT" or is_selected:
		return
	# Solo las obreras adultas NO seleccionadas deambulan
	
	var move_chance = 0.01
	var min_dist = 80
	var max_dist = 200
	
	match ant_caste:
		AntCaste.WORKER_MINIMA:
			move_chance = 0.015  # Más activas
			min_dist = 60
			max_dist = 150
		AntCaste.WORKER_MENOR:
			move_chance = 0.012
			min_dist = 80
			max_dist = 180
		AntCaste.WORKER_MEDIANA:
			move_chance = 0.008  # Más lentas, se mueven menos
			min_dist = 100
			max_dist = 250
		AntCaste.WORKER_MAYOR:
			move_chance = 0.005  # Soldados, más estáticos
			min_dist = 120
			max_dist = 300
	
	if randf() < move_chance:
		var random_angle = randf() * 2 * PI
		var random_distance = randf_range(min_dist, max_dist)
		var target_offset = Vector2(cos(random_angle), sin(random_angle)) * random_distance
		var new_target = global_position + target_offset
		set_target(new_target)
		
func _work_behavior(_delta: float) -> void:
	pass  # Sobreescribir en clases hijas

func _return_behavior(_delta: float) -> void:
	pass  # Sobreescribir en clases hijas

func _attack_behavior(_delta: float) -> void:
	pass  # Sobreescribir en clases hijas (soldados)

func _defend_behavior(_delta: float) -> void:
	pass  # Sobreescribir en clases hijas (soldados)

func _feed_behavior(_delta: float) -> void:
	pass  # Sobreescribir en clases hijas (mínimas)

# ========== CRECIMIENTO DE LARVA ==========
func process_larva_growth(delta: float) -> void:
	if development_stage != "LARVA":
		return
	
	# Aumentar tamaño gradualmente
	ant_size += caste_stats.get("growth_rate", 0.01) * delta
	ant_size = min(ant_size, 0.7)  # Máximo tamaño larva
	
	scale = Vector2(ant_size, ant_size)
	
	# Si alcanza tamaño máximo, convertirse en pupa
	if ant_size >= 0.7:
		metamorphose_to_pupa()

# ========== METAMORFOSIS ==========
func metamorphose_to_pupa() -> void:
	print("🔄 Larva se convierte en pupa")
	ant_caste = AntCaste.PUPA
	initialize_caste_stats()

func complete_metamorphosis(final_caste: AntCaste) -> void:
	if development_stage != "PUPA":
		return
	
	print("🦋 Pupa completa metamorfosis a %s" % AntCaste.keys()[final_caste])
	ant_caste = final_caste
	initialize_caste_stats()
	current_health = max_health
	
	# Emitir señal
	emit_signal("ant_task_completed", self, "METAMORPHOSIS")

# ========== MÉTODOS PÚBLICOS ==========
func set_target(pos: Vector2) -> void:
	if development_stage != "ADULT":
		print("⚠️  %s no puede moverse (etapa: %s)" % [get_display_name(), development_stage])
		return
	
	target_position = pos
	state = AntState.MOVING
	print("🎯 %s nuevo destino: %s" % [get_display_name(), str(pos)])

func take_damage(amount: float, source = null):
	var actual_damage = amount - defense
	actual_damage = max(actual_damage, 1.0)
	current_health -= actual_damage
	print("💥 %s recibe daño: -%.1f HP desde %s (%.1f/%.1f)" % [
		get_display_name(), actual_damage, source, current_health, max_health
	])
	emit_signal("ant_damaged", self, actual_damage)
	if current_health <= 0:
		die()

func die() -> void:
	print("💀 %s muerta" % get_display_name())
	
	# Emitir señal antes de eliminar
	emit_signal("ant_died", self)
	
	queue_free()

func is_alive() -> bool:
	return current_health > 0

func heal(amount: float) -> void:
	current_health += amount
	current_health = min(current_health, max_health)
	print("💚 %s curada: +%.1f HP (%.1f/%.1f)" % [
		get_display_name(), amount, current_health, max_health
	])

# ========== SISTEMA DE TAREAS ==========
func assign_task(task_type: String,_task_target = null) -> void:
	if development_stage != "ADULT":
		print("⚠️  %s no puede recibir tareas (etapa: %s)" % [get_display_name(), development_stage])
		return
	
	current_task = task_type
	
	match task_type:
		"FORAGE":
			print("🌿 %s asignada a forrajeo" % get_display_name())
			state = AntState.MOVING
		"TRANSPORT":
			print("🚚 %s asignada a transporte" % get_display_name())
			state = AntState.MOVING
		"NURSE":
			print("👶 %s asignada a cuidado de larvas" % get_display_name())
			state = AntState.FEEDING
		"DEFEND":
			print("🛡️ %s asignada a defensa" % get_display_name())
			state = AntState.DEFENDING
		"ATTACK":
			print("⚔️ %s asignada a ataque" % get_display_name())
			state = AntState.ATTACKING
		"CLEAN":
			print("🧹 %s asignada a limpieza" % get_display_name())
			state = AntState.WORKING
		_:
			print("❓ %s recibió tarea desconocida: %s" % [get_display_name(), task_type])

func complete_task() -> void:
	print("✅ %s completó tarea: %s" % [get_display_name(), current_task])
	emit_signal("ant_task_completed", self, current_task)
	current_task = "NONE"
	state = AntState.IDLE

# ========== SISTEMA DE RECURSOS ==========
func pickup_resource(resource_type: String, amount: float) -> bool:
	if is_carrying:
		print("⚠️  %s ya está cargando %s" % [get_display_name(), carried_resource])
		return false
	
	if amount > carry_capacity:
		print("⚠️  %s no puede cargar tanto (%.1f > %.1f)" % [get_display_name(), amount, carry_capacity])
		return false
	
	is_carrying = true
	carried_resource = resource_type
	carried_amount = amount
	
	print("📦 %s recogió %.1f de %s" % [get_display_name(), amount, resource_type])
	return true

func deliver_resource() -> Dictionary:
	if not is_carrying:
		print("⚠️  %s no está cargando nada" % get_display_name())
		return {"success": false}
	
	print("📤 %s entregó %.1f de %s" % [get_display_name(), carried_amount, carried_resource])
	
	var delivery_data = {
		"success": true,
		"resource": carried_resource,
		"amount": carried_amount,
		"ant": self
	}
	
	# Emitir señal
	emit_signal("ant_resource_delivered", self, carried_resource, carried_amount)
	
	# Resetear carga
	is_carrying = false
	carried_resource = ""
	carried_amount = 0.0
	
	return delivery_data

func drop_resource() -> void:
	if is_carrying:
		print("💥 %s soltó %.1f de %s" % [get_display_name(), carried_amount, carried_resource])
		is_carrying = false
		carried_resource = ""
		carried_amount = 0.0

# ========== UTILIDADES ==========
func get_display_name() -> String:
	if ant_name != "":
		return ant_name
	return caste_stats.get("display_name", "Hormiga")

func get_ant_info() -> Dictionary:
	return {
		"name": ant_name,
		"caste": caste_stats.get("display_name", "Desconocida"),
		"health": "%.1f/%.1f" % [current_health, max_health],
		"state": AntState.keys()[state],
		"stage": development_stage,
		"position": "(%d, %d)" % [int(global_position.x), int(global_position.y)],
		"is_carrying": is_carrying,
		"carried": "%s x%.1f" % [carried_resource, carried_amount],
		"task": current_task,
		"abilities": special_abilities,
		"colony": colony_id
	}

func quick_debug() -> void:
	var info = get_ant_info()
	print("=== DEBUG %s ===" % get_display_name())
	for key in info:
		print("  %s: %s" % [key, str(info[key])])
	print("==================")

# ========== MÉTODO ESPECIAL PARA REINA ==========
func move_to(pos: Vector2) -> void:
	# Solo la reina usa este método específico
	if ant_caste == AntCaste.QUEEN:
		set_target(pos)
	else:
		print("⚠️  Solo la reina usa move_to()")

func settle_at(pos: Vector2) -> void:
	if ant_caste == AntCaste.QUEEN:
		print("🏠 Reina asentando colonia en %s" % str(pos))
		# Aquí iría la lógica para fundar colonia
	else:
		print("⚠️  Solo la reina puede asentar colonias")

func add_food(amount: float) -> bool:
	if ant_caste == AntCaste.QUEEN:
		print("🍯 +%.1f comida para la reina" % amount)
		# Aquí iría la lógica para añadir comida
		return true
	else:
		print("⚠️  Solo la reina puede recibir comida directa")
		return false

# ========== SEÑALES DE ENTRADA ==========
func _on_clicked() -> void:
	if is_player_controlled:
		print("🖱️  %s clickeada (controlada por jugador)" % get_display_name())
		# Aquí iría la lógica de selección para el jugador

func _on_mouse_entered() -> void:
	# Resaltar al pasar mouse
	if has_node("Highlight"):
		$Highlight.visible = true

func _on_mouse_exited() -> void:
	# Quitar resaltado
	if has_node("Highlight"):
		$Highlight.visible = false
