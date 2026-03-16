# res://scripts/systems/global.gd
extends Node

var selected_settlement_spot: Dictionary = {}
var player_species: String = "acromyrmex"
var colony_food: float = 20.0

func _ready():
	print("✅ GLOBAL autoload cargado correctamente")

func save_spot(position: Vector2, quality: String, bonuses: Dictionary):
	selected_settlement_spot = {
		"position": position,
		"quality": quality,
		"bonuses": bonuses
	}
	print("📌 Spot guardado en GLOBAL: ", selected_settlement_spot)
