# res://scripts/ui/buttons/menu_button.gd
extends Button

@export var scene_to_load: String = ""
@export var is_quit_button: bool = false

func _on_pressed():
	print("Botón presionado: ", self.name)
	
	if is_quit_button:
		get_tree().quit()
	elif scene_to_load != "":
		# Intentar usar SCENE_MANAGER si existe
		if Engine.get_main_loop().has_node("/root/SCENE_MANAGER"):
			var sm = Engine.get_main_loop().get_node("/root/SCENE_MANAGER")
			sm.change_scene(scene_to_load)
		else:
			get_tree().change_scene_to_file(scene_to_load)
	
	# Animación
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2(0.95, 0.95), 0.05)
	tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.05)
