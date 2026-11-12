extends Area2D
# Enemigo que patrulla de lado a lado (usa el arte del antagónico).
# Si lo aplastas desde arriba muere; si te toca de lado pierdes una vida.

@export var velocidad: float = 110.0
@export var distancia: float = 220.0          # cuánto camina hacia cada lado desde donde lo pongas
@export var mira_a_la_derecha: bool = true    # pon false si su sprite original mira a la izquierda

var direccion: float = 1.0
var x_min: float = 0.0
var x_max: float = 0.0
var vivo: bool = true

@onready var sprite: AnimatedSprite2D = $Movimientos
@onready var colision: CollisionShape2D = $CollisionShape2D

func _ready() -> void:
	x_min = global_position.x - distancia
	x_max = global_position.x + distancia
	sprite.play("Caminando")

func _physics_process(delta: float) -> void:
	if not vivo:
		return

	global_position.x += direccion * velocidad * delta
	if global_position.x >= x_max:
		direccion = -1.0
	elif global_position.x <= x_min:
		direccion = 1.0
	if mira_a_la_derecha:
		sprite.flip_h = direccion < 0.0
	else:
		sprite.flip_h = direccion > 0.0

	# Revisa cada cuadro si está tocando al jugador (así también hace daño si se queda encima)
	for cuerpo in get_overlapping_bodies():
		if cuerpo is CharacterBody2D and cuerpo.is_in_group("jugador"):
			_tocar_jugador(cuerpo)
			break

func _tocar_jugador(j) -> void:
	if j.muerto:
		return
	var cae_encima: bool = j.velocity.y > 0.0 and j.pies_y() <= colision.global_position.y
	if cae_encima:
		_morir()
		j.rebotar()
	else:
		j.recibir_dano(global_position.x)

func _morir() -> void:
	vivo = false
	set_deferred("monitoring", false)
	var t := create_tween()
	t.tween_property(self, "scale:y", 0.1, 0.15)
	t.tween_callback(queue_free)
