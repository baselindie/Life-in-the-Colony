# chamber_system.gd - VERSIÓN CORREGIDA
extends Node

enum ChamberType {
	QUEEN_CHAMBER,      # Cámara de la reina
	NURSERY,            # Guardería (huevos/larvas)
	FUNGUS_GARDEN,      # Jardín de hongos
	STORAGE,            # Almacén de recursos
	GRAVEYARD,          # Cementerio (desechos)
	BARRACKS,           # Cuartel (soldados)
	EXPANSION           # Cámara vacía para expandir
}

class Chamber:
	var position: Vector2
	var type: ChamberType
	var size: Vector2
	var connections: Array = []  # Cámaras conectadas
	var resources: Dictionary = {}
	var capacity: int = 0
	var name: String = ""
	
	func _init(pos: Vector2, chamber_type: ChamberType, chamber_size: Vector2 = Vector2(100, 100)):
		position = pos
		type = chamber_type
		size = chamber_size
		setup_chamber()  # ✅ AHORA ESTA FUNCIÓN EXISTE
	
	func setup_chamber():
		# Asignar nombre según tipo
		match type:
			ChamberType.QUEEN_CHAMBER:
				name = "Cámara Real"
				capacity = 1
				resources["comfort"] = 100
				resources["security"] = 100
				
			ChamberType.NURSERY:
				name = "Guardería"
				capacity = 25
				resources["temperature"] = 30
				resources["humidity"] = 70
				resources["cleanliness"] = 90
				
			ChamberType.FUNGUS_GARDEN:
				name = "Jardín de Hongos"
				capacity = 50
				resources["fungus_quality"] = 100
				resources["growth_rate"] = 1.0
				resources["nutrition"] = 80
				
			ChamberType.STORAGE:
				name = "Almacén"
				capacity = 100
				resources["organization"] = 100
				resources["capacity_used"] = 0
				
			ChamberType.GRAVEYARD:
				name = "Cementerio"
				capacity = 30
				resources["waste_level"] = 0
				resources["cleanliness"] = 50
				
			ChamberType.BARRACKS:
				name = "Cuartel"
				capacity = 15
				resources["defense"] = 100
				resources["readiness"] = 100
				
			ChamberType.EXPANSION:
				name = "Cámara Vacía"
				capacity = 0
				resources["potential"] = 100
				
			_:
				name = "Cámara Desconocida"
				capacity = 10
	
	func add_connection(other_chamber: Chamber):
		if not other_chamber in connections:
			connections.append(other_chamber)
	
	func remove_connection(other_chamber: Chamber):
		if other_chamber in connections:
			connections.erase(other_chamber)
	
	func get_info() -> Dictionary:
		return {
			"name": name,
			"type": type,
			"position": position,
			"size": size,
			"capacity": capacity,
			"connections": connections.size(),
			"resources": resources
		}

# Variables del sistema
var chambers: Array = []
var tunnels: Array = []  # Túneles entre cámaras
var chamber_nodes: Array = []  # Nodos de Godot para las cámaras

func _ready():
	print("✅ Sistema de cámaras inicializado")
	print("📊 Tipos de cámaras: %d" % ChamberType.size())

# Crear cámara inicial de la reina
func create_queen_chamber(position: Vector2 = Vector2(400, 300)) -> Chamber:
	var queen_chamber = Chamber.new(position, ChamberType.QUEEN_CHAMBER, Vector2(150, 150))
	chambers.append(queen_chamber)
	print("👑 Cámara real creada en: %s" % position)
	return queen_chamber

# Crear cámaras básicas alrededor de una cámara central
func create_initial_chambers(center_chamber: Chamber):
	var directions = [
		Vector2(200, 0),    # Derecha - Almacén
		Vector2(-200, 0),   # Izquierda - Guardería
		Vector2(0, 200),    # Abajo - Jardín hongos
		Vector2(0, -200)    # Arriba - Cementerio
	]
	
	var chamber_types = [
		ChamberType.STORAGE,
		ChamberType.NURSERY,
		ChamberType.FUNGUS_GARDEN,
		ChamberType.GRAVEYARD
	]
	
	for i in range(4):
		var pos = center_chamber.position + directions[i]
		var new_chamber = Chamber.new(pos, chamber_types[i], Vector2(120, 120))
		chambers.append(new_chamber)
		
		# Conectar con cámara central
		create_tunnel(center_chamber, new_chamber)
		
		print("➕ %s creada en: %s" % [new_chamber.name, pos])

# Crear túnel entre dos cámaras
func create_tunnel(chamber_a: Chamber, chamber_b: Chamber):
	var tunnel = {
		"start": chamber_a.position,
		"end": chamber_b.position,
		"width": 40.0,
		"chamber_a": chamber_a,
		"chamber_b": chamber_b
	}
	tunnels.append(tunnel)
	
	# Conectar referencias
	chamber_a.add_connection(chamber_b)
	chamber_b.add_connection(chamber_a)
	
	print("🛤️  Túnel creado entre %s y %s" % [chamber_a.name, chamber_b.name])

# Generar visualización de todas las cámaras
func generate_chamber_visuals(parent_node: Node):
	# Limpiar nodos antiguos
	for node in chamber_nodes:
		node.queue_free()
	chamber_nodes.clear()
	
	# Crear nodos para cada cámara
	for chamber in chambers:
		var chamber_node = create_chamber_node(chamber)
		parent_node.add_child(chamber_node)
		chamber_nodes.append(chamber_node)
	
	# Crear túneles
	for tunnel in tunnels:
		var tunnel_node = create_tunnel_node(tunnel)
		parent_node.add_child(tunnel_node)
		chamber_nodes.append(tunnel_node)
	
	print("🎨 Visualización generada: %d cámaras, %d túneles" % [chambers.size(), tunnels.size()])

# Crear nodo Godot para una cámara
func create_chamber_node(chamber: Chamber) -> Node2D:
	var area = Area2D.new()
	area.position = chamber.position
	area.name = "%s_%d" % [chamber.name.replace(" ", "_"), chambers.find(chamber)]
	
	# Collision shape
	var collider = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	shape.size = chamber.size
	collider.shape = shape
	area.add_child(collider)
	
	# Sprite visual
	var sprite = Sprite2D.new()
	sprite.texture = get_chamber_texture(chamber.type)
	sprite.scale = chamber.size / 64.0  # Ajustar a sprite 64x64
	area.add_child(sprite)
	
	# Label con nombre
	var label = Label.new()
	label.text = chamber.name
	label.position = Vector2(-chamber.size.x/2, -chamber.size.y/2 - 25)
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_constant_override("outline_size", 2)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	area.add_child(label)
	
	return area

# Crear nodo Godot para un túnel
func create_tunnel_node(tunnel: Dictionary) -> Line2D:
	var line = Line2D.new()
	line.points = [tunnel["start"], tunnel["end"]]
	line.width = tunnel["width"]
	line.default_color = Color(0.3, 0.2, 0.1, 0.8)
	
	# Intentar cargar textura, sino usar color sólido
	var tunnel_texture = load("res://assets/textures/tunnel.png")
	if tunnel_texture:
		line.texture = tunnel_texture
		line.texture_mode = Line2D.LINE_TEXTURE_TILE
	
	line.z_index = -1  # Detrás de las cámaras
	return line

# Obtener textura para un tipo de cámara
func get_chamber_texture(type: ChamberType) -> Texture2D:
	var image = Image.create(64, 64, false, Image.FORMAT_RGBA8)
	var color: Color
	
	match type:
		ChamberType.QUEEN_CHAMBER:
			color = Color(0.8, 0.6, 0.4, 0.7)  # Marrón real
		ChamberType.NURSERY:
			color = Color(0.4, 0.8, 0.6, 0.7)  # Verde bebé
		ChamberType.FUNGUS_GARDEN:
			color = Color(0.6, 0.4, 0.8, 0.7)  # Púrpura hongo
		ChamberType.STORAGE:
			color = Color(0.8, 0.8, 0.4, 0.7)  # Amarillo almacén
		ChamberType.GRAVEYARD:
			color = Color(0.4, 0.4, 0.4, 0.7)  # Gris cementerio
		ChamberType.BARRACKS:
			color = Color(0.8, 0.4, 0.4, 0.7)  # Rojo cuartel
		ChamberType.EXPANSION:
			color = Color(0.5, 0.5, 0.5, 0.5)  # Gris semi-transparente
		_:
			color = Color(0.5, 0.5, 0.5, 0.7)
	
	image.fill(color)
	return ImageTexture.create_from_image(image)

# Funciones de utilidad
func get_chamber_at_position(position: Vector2, max_distance: float = 50.0):
	for chamber in chambers:
		if chamber.position.distance_to(position) <= max_distance:
			return chamber
	return null

func get_chambers_by_type(chamber_type: ChamberType) -> Array:
	var result = []
	for chamber in chambers:
		if chamber.type == chamber_type:
			result.append(chamber)
	return result

func debug_print_chambers():
	print("\n=== 🏠 CÁMARAS DE LA COLONIA ===")
	for chamber in chambers:
		var info = chamber.get_info()
		print("📍 %s" % info["name"])
		print("   Tipo: %s" % ChamberType.keys()[chamber.type])
		print("   Posición: %s" % info["position"])
		print("   Conexiones: %d" % info["connections"])
		print("   Capacidad: %d" % info["capacity"])
		print("---")
	print("Total: %d cámaras, %d túneles" % [chambers.size(), tunnels.size()])
