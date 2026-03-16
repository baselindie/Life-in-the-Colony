# construction_system.gd - VERSIÓN CORREGIDA
extends Node

class_name ConstructionSystem

# Señales que SÍ vamos a usar
signal construction_started(chamber_type, position)
signal construction_progress_updated(progress_percent)
signal construction_completed(chamber_data)
signal construction_cancelled(chamber_type)

# Tipos de cámaras disponibles con sus costos
enum ChamberType {
	NURSERY,        # Guardería para larvas
	FUNGUS_GARDEN,  # Jardín de hongos
	STORAGE,        # Almacén de recursos
	BARRACKS,       # Cuartel para soldados
	EXPANSION       # Cámara vacía para expandir
}

# Datos de cada tipo de cámara
var chamber_data = {
	ChamberType.NURSERY: {
		"name": "Guardería",
		"cost": {"leaves": 50, "fungus": 20},
		"build_time": 30.0,
		"description": "Lugar para criar larvas y pupas",
		"icon_color": Color("4cd964"),  # Verde
		"atlas_coords": Vector2i(0, 0)
	},
	ChamberType.FUNGUS_GARDEN: {
		"name": "Jardín de Hongos",
		"cost": {"leaves": 80, "soil": 30},
		"build_time": 45.0,
		"description": "Cultiva hongos para alimentar la colonia",
		"icon_color": Color("9b59b6"),  # Púrpura
		"atlas_coords": Vector2i(1, 0)  # Coordenada de atlas para jardín
	},
	ChamberType.STORAGE: {
		"name": "Almacén",
		"cost": {"soil": 60},
		"build_time": 25.0,
		"description": "Almacena recursos de la colonia",
		"icon_color": Color("f1c40f"),  # Amarillo
		"atlas_coords": Vector2i(2, 0)  # Coordenada de atlas para almacén
	},
	ChamberType.BARRACKS: {
		"name": "Cuartel",
		"cost": {"soil": 100, "protein": 20},
		"build_time": 60.0,
		"description": "Cuartel para hormigas soldado",
		"icon_color": Color("e74c3c"),  # Rojo
		"atlas_coords": Vector2i(3, 0)  # Coordenada de atlas para cuartel
	},
	ChamberType.EXPANSION: {
		"name": "Cámara de Expansión",
		"cost": {"soil": 40},
		"build_time": 20.0,
		"description": "Cámara vacía para futuras expansiones",
		"icon_color": Color("95a5a6"),  # Gris
		"atlas_coords": Vector2i(4, 0)  # Coordenada de atlas para expansión
	}
}

# ... el resto del script continúa igual (no necesita cambios) ...

# Variables del sistema
var current_construction = null
var construction_workers = []  # Hormigas trabajando en la construcción

# -------------------------------------------------------------------
# FUNCIONES PÚBLICAS (para usar desde otros scripts)
# -------------------------------------------------------------------

# Iniciar una nueva construcción
func start_construction(chamber_type: ChamberType, position: Vector2, colony_resources: Dictionary) -> bool:
	print("🏗️  Intentando iniciar construcción...")
	
	# 1. Verificar que el tipo de cámara existe
	if not chamber_data.has(chamber_type):
		print("❌ Error: Tipo de cámara no válido")
		return false
	
	# 2. Obtener datos de la cámara
	var data = chamber_data[chamber_type]
	
	# 3. Verificar recursos (forma segura)
	if not can_afford_construction(data["cost"], colony_resources):
		print("❌ Recursos insuficientes")
		return false
	
	# 4. Consumir recursos
	consume_resources(data["cost"], colony_resources)
	
	# 5. Crear objeto de construcción
	current_construction = {
		"type": chamber_type,
		"position": position,
		"data": data.duplicate(true),  # Copia profunda de los datos
		"progress": 0.0,
		"workers": [],
		"start_time": Time.get_unix_time_from_system()
	}
	
	print("✅ Construcción iniciada: %s en %s" % [data["name"], position])
	construction_started.emit(chamber_type, position)
	return true

# Añadir trabajador a la construcción
func assign_worker(worker) -> bool:
	if not current_construction:
		print("⚠️  No hay construcción activa")
		return false
	
	if worker in current_construction["workers"]:
		return true  # Ya está asignado
	
	current_construction["workers"].append(worker)
	construction_workers.append(worker)
	
	print("👷 %s asignado a construcción" % worker.name)
	return true

# Actualizar construcción (llamar en _process)
func update_construction(delta: float):
	if not current_construction:
		return
	
	# Calcular progreso basado en trabajadores
	var worker_count = current_construction["workers"].size()
	var progress_rate = calculate_progress_rate(worker_count)
	
	# Añadir progreso
	current_construction["progress"] += progress_rate * delta
	
	# Emitir señal de progreso
	var progress_percent = get_progress_percent()
	construction_progress_updated.emit(progress_percent)
	
	# Verificar si se completó
	if current_construction["progress"] >= current_construction["data"]["build_time"]:
		complete_construction()

# Obtener porcentaje de progreso actual
func get_progress_percent() -> float:
	if not current_construction:
		return 0.0
	
	var build_time = current_construction["data"]["build_time"]
	if build_time <= 0:
		return 0.0
	
	return min(current_construction["progress"] / build_time, 1.0) * 100

# Cancelar construcción actual
func cancel_construction(colony_resources: Dictionary) -> bool:
	if not current_construction:
		print("⚠️  No hay construcción para cancelar")
		return false
	
	# Obtener datos
	var chamber_type = current_construction["type"]
	var chamber_name = chamber_data[chamber_type]["name"]
	
	# Devolver 50% de recursos
	var cost = current_construction["data"]["cost"]
	return_resources(cost, colony_resources, 0.5)
	
	# Liberar trabajadores
	for worker in current_construction["workers"]:
		if worker and worker.has_method("on_construction_cancelled"):
			worker.on_construction_cancelled()
	
	# Limpiar
	print("❌ Construcción cancelada: %s" % chamber_name)
	construction_cancelled.emit(chamber_type)
	
	current_construction = null
	construction_workers.clear()
	
	return true

# Verificar si hay construcción en progreso
func is_building() -> bool:
	return current_construction != null

# Obtener datos de la construcción actual
func get_current_construction_info():
	if not current_construction:
		return null
	
	return {
		"type": current_construction["type"],
		"name": chamber_data[current_construction["type"]]["name"],
		"position": current_construction["position"],
		"progress_percent": get_progress_percent(),
		"workers": current_construction["workers"].size(),
		"remaining_time": get_remaining_time()
	}

# -------------------------------------------------------------------
# FUNCIONES PRIVADAS (solo para uso interno)
# -------------------------------------------------------------------

# Verificar si se pueden pagar los recursos
func can_afford_construction(cost: Dictionary, colony_resources: Dictionary) -> bool:
	for resource in cost:
		# Verificar que el recurso existe en la colonia
		if not colony_resources.has(resource):
			print("❌ Recurso no disponible en colonia: %s" % resource)
			return false
		
		# Verificar cantidad suficiente
		if colony_resources[resource] < cost[resource]:
			print("❌ Necesitas más %s (tienes: %.1f, necesitas: %.1f)" % [
				resource, colony_resources[resource], cost[resource]
			])
			return false
	
	return true

# Consumir recursos de la colonia
func consume_resources(cost: Dictionary, colony_resources: Dictionary):
	for resource in cost:
		if colony_resources.has(resource):
			colony_resources[resource] -= cost[resource]
			print("💰 Consumido %s: %.1f" % [resource, cost[resource]])

# Devolver recursos a la colonia
func return_resources(cost: Dictionary, colony_resources: Dictionary, percentage: float):
	for resource in cost:
		if colony_resources.has(resource):
			var amount = cost[resource] * percentage
			colony_resources[resource] += amount
			print("💰 Devuelto %s: %.1f (%.0f%%)" % [resource, amount, percentage * 100])

# Calcular tasa de progreso basada en trabajadores
func calculate_progress_rate(worker_count: int) -> float:
	# Cada trabajador aporta 0.15 unidades por segundo
	var base_rate = 0.15
	
	# Bonus por múltiples trabajadores (diminishing returns)
	if worker_count > 1:
		base_rate *= (1.0 + log(worker_count) * 0.3)
	
	return base_rate

# Completar construcción
func complete_construction():
	if not current_construction:
		return
	
	var chamber_type = current_construction["type"]
	var chamber_name = chamber_data[chamber_type]["name"]
	
	print("🎉 ¡Construcción completada: %s!" % chamber_name)
	
	# Crear datos para la señal
	var completed_data = {
		"type": chamber_type,
		"name": chamber_name,
		"position": current_construction["position"],
		"data": current_construction["data"].duplicate(true)
	}
	
	# Recompensar trabajadores
	for worker in current_construction["workers"]:
		if worker and worker.has_method("on_construction_completed"):
			worker.on_construction_completed(chamber_name)
	
	# Emitir señal
	construction_completed.emit(completed_data)
	
	# Limpiar
	current_construction = null
	construction_workers.clear()

# Calcular tiempo restante
func get_remaining_time() -> float:
	if not current_construction:
		return 0.0
	
	var progress = current_construction["progress"]
	var total_time = current_construction["data"]["build_time"]
	var remaining = total_time - progress
	
	return max(remaining, 0.0)

# -------------------------------------------------------------------
# FUNCIONES DE DEBUG Y UTILIDAD
# -------------------------------------------------------------------

# Imprimir estado actual del sistema
func debug_status():
	print("\n=== 🏗️  ESTADO SISTEMA CONSTRUCCIÓN ===")
	
	if current_construction:
		var info = get_current_construction_info()
		print("📦 Construyendo: %s" % info["name"])
		print("📈 Progreso: %.1f%%" % info["progress_percent"])
		print("👷 Trabajadores: %d" % info["workers"])
		print("⏱️  Tiempo restante: %.1f segundos" % info["remaining_time"])
		print("📍 Posición: %s" % info["position"])
	else:
		print("💤 No hay construcción en progreso")
	
	print("📊 Cámaras disponibles:")
	for chamber_type in chamber_data:
		var data = chamber_data[chamber_type]
		print("  • %s: %s" % [data["name"], data["description"]])
	
	print("===============================\n")

# Obtener lista de cámaras construibles
func get_available_chambers(colony_resources: Dictionary) -> Array:
	var available = []
	
	for chamber_type in chamber_data:
		var data = chamber_data[chamber_type]
		
		if can_afford_construction(data["cost"], colony_resources):
			available.append({
				"type": chamber_type,
				"name": data["name"],
				"cost": data["cost"],
				"build_time": data["build_time"],
				"description": data["description"],
				"icon_color": data["icon_color"]
			})
	
	return available

# Verificar si se puede construir una cámara específica
func can_build_chamber(chamber_type: ChamberType, colony_resources: Dictionary) -> bool:
	if not chamber_data.has(chamber_type):
		return false
	
	var data = chamber_data[chamber_type]
	return can_afford_construction(data["cost"], colony_resources)

# -------------------------------------------------------------------
# FUNCIÓN DE INICIALIZACIÓN
# -------------------------------------------------------------------

func _ready():
	print("✅ Sistema de construcción inicializado")
	print("📊 Tipos de cámaras cargados: %d" % chamber_data.size())
