extends Area2D

var spot_name: String = "Lugar sin nombre"
var spot_quality: int = 1
var spot_radius: float = 40.0
var is_discovered: bool = false
var is_selected: bool = false

func _ready():
	# Conectar señal de detección
	body_entered.connect(_on_body_entered)

func _on_body_entered(body):
	if body.name == "Queen" and not is_discovered:
		is_discovered = true
		print("🔍 Spot descubierto: ", spot_name)

func get_bonuses() -> Dictionary:
	var multiplier = 1.0 + (spot_quality * 0.25)
	return {
		"resource_multiplier": multiplier,
		"defense_bonus": spot_quality * 0.1,
		"fertility_bonus": spot_quality * 0.15
	}
