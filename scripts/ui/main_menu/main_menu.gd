# res://scripts/ui/main_menu/main_menu.gd
extends Control

func _ready():
	print("=== MENÚ PRINCIPAL ===")
	
	# Asegurar conexiones
	if $PlayButton:
		$PlayButton.pressed.connect(_on_play_pressed)
	if $QuitButton:
		$QuitButton.pressed.connect(_on_quit_pressed)

func _on_play_pressed():
	print("▶️  Iniciando juego...")
	get_tree().change_scene_to_file("res://scenes/intro/nuptial_flight.tscn")

func _on_quit_pressed():
	print("🚪 Saliendo del juego...")
	get_tree().quit()
