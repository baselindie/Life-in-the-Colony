# res://scripts/ui/scene_manager.gd
extends Node

# NOTA: El nombre del autoload se define en Project Settings, no aquí

func _ready():
	print("✅ SCENE_MANAGER inicializado")

func change_scene(scene_path: String):
	print("Cambiando a escena: ", scene_path)
	if ResourceLoader.exists(scene_path):
		get_tree().change_scene_to_file(scene_path)
	else:
		print("❌ Error: La escena no existe: ", scene_path)

func quit_game():
	get_tree().quit()

func load_scene(scene_path: String):
	var scene = load(scene_path)
	if scene:
		get_tree().change_scene_to_packed(scene)
	else:
		print("❌ No se pudo cargar escena: %s" % scene_path)
		
