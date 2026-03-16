# queen_acromyrmex.gd - VERSIÓN MODIFICADA (sin producción automática)
extends AntBase

# Variables específicas de la reina
@export var max_food_storage: float = 100.0
var current_food: float = 20.0
var egg_production_timer: float = 0.0
var eggs_in_belly: int = 0
var is_settled: bool = false
var colony_position: Vector2 = Vector2.ZERO

func _ready() -> void:
	ant_caste = AntCaste.QUEEN
	ant_name = "Reina Acromyrmex"
	current_health = max_health
	current_food = 20.0
	print("👑 Reina Acromyrmex creada | Comida: %.1f/%.1f" % [current_food, max_food_storage])
	print("⭐ Casta: %s" % caste_stats.get("display_name", "Reina"))

func initialize_caste_stats() -> void:
	super.initialize_caste_stats()
	caste_stats["max_food_storage"] = max_food_storage
	caste_stats["egg_production_rate"] = 0.05
	caste_stats["metabolism_rate"] = 0.2
	if not "Poner huevos" in special_abilities:
		special_abilities.append("Poner huevos")
	if not "Fundar colonias" in special_abilities:
		special_abilities.append("Fundar colonias")
	if not "Feromonas reales" in special_abilities:
		special_abilities.append("Feromonas reales")

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if development_stage == "ADULT":
		# Metabolismo y producción desactivados
		process_queen_metabolism(delta)
		# process_egg_production(delta)
		pass

func process_queen_metabolism(delta: float) -> void:
	if current_food > 0:
		var consumption = caste_stats.get("metabolism_rate", 0.02) * delta
		current_food -= consumption
		current_food = max(current_food, 0.0)
		if current_food <= 0:
			take_damage(0.2 * delta)
	else:
		take_damage(0.2 * delta)

func process_egg_production(delta: float) -> void:
	if current_food <= 0:
		return
	egg_production_timer += delta
	var egg_rate = caste_stats.get("egg_production_rate", 0.05)
	if egg_production_timer >= (1.0 / egg_rate):
		egg_production_timer = 0.0
		produce_egg()

func produce_egg() -> void:
	var egg_food_cost = 5.0
	if current_food >= egg_food_cost:
		current_food -= egg_food_cost
		eggs_in_belly += 1
		print("🥚 Reina produjo un huevo | Huevos en vientre: %d" % eggs_in_belly)
		if has_signal("egg_produced"):
			emit_signal("egg_produced", eggs_in_belly)
	else:
		print("⚠️ Reina necesita más comida para producir huevos")

func lay_egg() -> bool:
	if eggs_in_belly > 0 and is_settled:
		eggs_in_belly -= 1
		print("🥚 Reina puso un huevo en la colonia")
		if has_signal("egg_layed"):
			emit_signal("egg_layed", colony_position)
		return true
	return false

func settle_at(pos: Vector2) -> void:
	if not is_settled:
		is_settled = true
		colony_position = pos
		print("🏠 Reina asentada en: %s" % str(pos))
		state = AntState.IDLE
		target_position = pos
		if has_signal("colony_settled"):
			emit_signal("colony_settled", pos)
	else:
		is_settled = false
		print("🚀 Reina levantando colonia")

func add_food(amount: float) -> bool:
	var new_food = current_food + amount
	if new_food <= max_food_storage:
		current_food = new_food
		print("🍯 +%.1f comida para reina | Total: %.1f/%.1f" % [amount, current_food, max_food_storage])
		return true
	else:
		current_food = max_food_storage
		print("⚠️ Capacidad máxima de comida alcanzada")
		return false

func get_food_consumption() -> float:
	return caste_stats.get("metabolism_rate", 0.1)

func _work_behavior(_delta: float) -> void:
	pass

func _idle_behavior(_delta: float) -> void:
	if is_settled:
		# No poner huevos automáticamente
		pass
	else:
		super._idle_behavior(_delta)

func get_queen_info() -> Dictionary:
	var base_info = super.get_ant_info()
	base_info["food"] = "%.1f/%.1f" % [current_food, max_food_storage]
	base_info["eggs_ready"] = eggs_in_belly
	base_info["is_settled"] = is_settled
	base_info["colony_position"] = str(colony_position)
	return base_info

func quick_debug() -> void:
	var info = get_queen_info()
	print("=== 👑 DEBUG REINA ===")
	for key in info:
		print("  %s: %s" % [key, str(info[key])])
	print("=====================")
