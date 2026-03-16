# nuptial_flight_animation.gd - SOLO ANIMACIÓN
extends Node2D

func _ready():
	print("=== VUELO NUPCIAL ===")
	print("🦋 La princesa emprende su viaje...")
	print("💡 Presiona CUALQUIER TECLA para continuar")
	
	# Animación simple (puedes mejorar después)
	animate_princess()
	
	# Auto-skip después de 10 segundos
	get_tree().create_timer(10.0).timeout.connect(skip_to_game)

func animate_princess():
	# Aquí iría tu animación de la princesa volando
	# Por ahora solo un mensaje
	print("🎬 Animación: Princesa volando por el bosque...")

func _input(event):
	# Cualquier tecla para saltar
	if event is InputEventKey and event.pressed:
		skip_to_game()

func skip_to_game():
	print("🚀 Terminando animación...")
	print("🚀 Saltando a EXTERIOR...")
	print("🔍 Verificando escenas...")
	
	# Listar qué escenas existen
	var test_scenes = [
		"res://scenes/exterior/main_exterior.tscn",
		"res://scenes/interior/main_interior.tscn",
		"res://main_exterior.tscn",
		"res://main_interior.tscn"
	]
	
	for scene in test_scenes:
		if ResourceLoader.exists(scene):
			print("✅ Existe:", scene)
	
	# Cargar EXTERIOR
	print("📂 Cargando: res://scenes/exterior/main_exterior.tscn")
	get_tree().change_scene_to_file("res://scenes/exterior/main_exterior.tscn")
