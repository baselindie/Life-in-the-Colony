# res://scripts/intro/princess_ant.gd
extends CharacterBody2D

@export var fly_speed: float = 150.0
@export var flap_force: float = 50.0
@export var max_height: float = 100.0
@export var min_height: float = 50.0

@onready var sprite = $Sprite2D
@onready var animation_player = $AnimationPlayer
@onready var wings_sound = $WingsSound

var target_position: Vector2
var is_flapping: bool = false
var current_height: float = 0.0
var flap_timer: float = 0.0

func _ready():
	# Iniciar animación de vuelo
	animation_player.play("fly")
	wings_sound.play()
	
	# Posición inicial aleatoria
	position = Vector2(100, get_viewport_rect().size.y / 2)
	target_position = Vector2(get_viewport_rect().size.x - 100, randf_range(100, 300))

func _physics_process(delta):
	# Movimiento hacia el objetivo
	var direction = (target_position - position).normalized()
	velocity = direction * fly_speed
	
	# Aleteo aleatorio
	flap_timer -= delta
	if flap_timer <= 0:
		is_flapping = true
		velocity.y -= flap_force
		flap_timer = randf_range(0.3, 0.8)
	
	# Gravedad suave
	if !is_flapping:
		velocity.y += 50.0 * delta
	
	# Limitar altura
	position.y = clamp(position.y, min_height, max_height)
	
	# Actualizar sprite
	if velocity.x > 0:
		sprite.flip_h = false
	elif velocity.x < 0:
		sprite.flip_h = true
	
	# Mover
	move_and_slide()
	
	# Si llegamos al objetivo, buscar nuevo
	if position.distance_to(target_position) < 10:
		pick_new_target()

func pick_new_target():
	var viewport = get_viewport_rect()
	target_position = Vector2(
		randf_range(100, viewport.size.x - 100),
		randf_range(min_height, max_height)
	)
		
