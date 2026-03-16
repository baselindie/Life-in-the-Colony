# spot_generator_final_distance.gd
extends Node2D
class_name SpotGenerator

@export var min_spots: int = 5
@export var max_spots: int = 12
@export var min_distance_between_spots: float = 150.0
@export var spot_scene: PackedScene

var spots: Array = []

func _ready():
	# Si no se asignó spot_scene en el editor, cargar por defecto
	if not spot_scene:
		spot_scene = preload("res://scenes/exterior/world/settlement_spot_clean.tscn")
	
	generate_spots()
	print("✅ SpotGenerator: %d spots creados" % spots.size())

func generate_spots():
	# Limpiar spots anteriores
	for spot in spots:
		spot.queue_free()
	spots.clear()
	
	var num_spots = randi_range(min_spots, max_spots)
	var viewport = get_viewport_rect().size
	
	print("🔧 Generando %d spots en área: %s" % [num_spots, viewport])
	print("📏 Distancia mínima entre spots: %dpx" % min_distance_between_spots)
	
	var attempts = 0
	var max_attempts = 200
	
	for i in range(num_spots):
		var spot_placed = false
		var attempts_for_this_spot = 0
		
		while not spot_placed and attempts_for_this_spot < 50:
			# Posición aleatoria
			var pos = Vector2(
				randf_range(100, viewport.x - 100),
				randf_range(100, viewport.y - 100)
			)
			
			# Verificar distancia mínima
			var valid_position = true
			for existing_spot in spots:
				var distance = pos.distance_to(existing_spot.position)
				if distance < min_distance_between_spots:
					valid_position = false
					break
			
			if valid_position:
				# Calidad aleatoria
				var rand = randf()
				var quality = 0
				
				if rand < 0.1:
					quality = 2
				elif rand < 0.4:
					quality = 1
				
				# Crear spot
				var spot = spot_scene.instantiate()
				spot.position = pos
				spot.name = "Spot_%d" % i
				
				# Asignar propiedades
				assign_spot_properties(spot, i, quality)
				
				add_child(spot)
				spots.append(spot)
				
				print("📍 Spot %d creado en %s (Calidad: %d)" % [i, pos, quality])
				spot_placed = true
			
			attempts_for_this_spot += 1
			attempts += 1
			
			if attempts >= max_attempts:
				print("⚠️  Se alcanzó el máximo de intentos.")
				break
		
		if not spot_placed:
			print("⚠️  No se pudo colocar spot %d" % i)
		
		if attempts >= max_attempts:
			break
	
	print("📊 Total spots colocados: %d de %d intentados" % [spots.size(), num_spots])

func assign_spot_properties(spot, index: int, quality: int):
	# Asignar calidad
	if "spot_quality" in spot:
		spot.spot_quality = quality
	elif spot.has_method("set_spot_quality"):
		spot.set_spot_quality(quality)
	else:
		spot.set("spot_quality", quality)
	
	# Asignar nombre según calidad
	var quality_text = ""
	match quality:
		2: quality_text = "Excelente"
		1: quality_text = "Bueno"
		_: quality_text = "Común"
	
	var spot_name_value = "Spot %d (%s)" % [index + 1, quality_text]
	
	if "spot_name" in spot:
		spot.spot_name = spot_name_value
	elif spot.has_method("set_spot_name"):
		spot.set_spot_name(spot_name_value)
	else:
		spot.set("spot_name", spot_name_value)

func get_spot_at_position(pos: Vector2, max_distance: float = 50.0) -> Node:
	for spot in spots:
		if spot.position.distance_to(pos) < max_distance:
			return spot
	return null

func get_all_spots() -> Array:
	return spots.duplicate()

func get_spots_count() -> int:
	return spots.size()

# CAMBIADO: position → target_position para evitar shadowing
func get_closest_spot(target_position: Vector2) -> Node:
	var closest = null
	var closest_distance = INF
	
	for spot in spots:
		var distance = target_position.distance_to(spot.position)  # CAMBIADO
		if distance < closest_distance:
			closest_distance = distance
			closest = spot
	
	return closest

func get_spots_in_radius(center: Vector2, radius: float) -> Array:
	var nearby_spots = []
	
	for spot in spots:
		var distance = center.distance_to(spot.position)
		if distance <= radius:
			nearby_spots.append({
				"spot": spot,
				"distance": distance
			})
	
	# Ordenar por distancia
	nearby_spots.sort_custom(func(a, b): return a["distance"] < b["distance"])
	return nearby_spots

func debug_print_spots():
	print("=== DEBUG SPOTS ===")
	for i in range(spots.size()):
		var spot = spots[i]
		var pos = spot.position
		
		var spot_name_value = spot.get("spot_name") if "spot_name" in spot else "Sin nombre"
		var quality = spot.get("spot_quality") if "spot_quality" in spot else 0
		var quality_text = ["Común", "Bueno", "Excelente"][quality]
		
		print("  [%d] %s (%s) en %s" % [i, spot_name_value, quality_text, pos])
