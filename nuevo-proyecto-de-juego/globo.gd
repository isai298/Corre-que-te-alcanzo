extends Area2D
# Globo inflado enemigo: flota. Si lo aplastas desde arriba explota y te da monedas.

@export var velocidad: float = 60.0
@export var amplitud: float = 36.0

var vivo: bool = true
var base_y: float = 0.0
var t: float = 0.0
var sprite: Sprite2D

func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	base_y = position.y
	t = randf() * 6.0
	sprite = Sprite2D.new()
	sprite.texture = load("res://arte/en_globo.png")
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(sprite)
	var cs := CollisionShape2D.new()
	var c := CircleShape2D.new()
	c.radius = 40.0
	cs.shape = c
	cs.position = Vector2(0, -14)
	add_child(cs)
	var n := VisibleOnScreenNotifier2D.new()
	n.rect = Rect2(-500, -500, 1000, 1000)
	add_child(n)
	n.screen_entered.connect(func(): set_physics_process(true))
	set_physics_process(false)

func _physics_process(delta: float) -> void:
	if not vivo:
		return
	t += delta
	global_position.x -= velocidad * delta
	position.y = base_y + sin(t * 2.0) * amplitud
	sprite.rotation = sin(t * 1.6) * 0.07
	for c in get_overlapping_bodies():
		if c is CharacterBody2D and c.is_in_group("jugador"):
			_tocar(c)
			break

func _tocar(j) -> void:
	if j.muerto:
		return
	if j.arrasa:
		_explotar()
		return
	if j.velocity.y > 0.0 and j.pies_y() <= global_position.y + 6.0:
		_explotar()
		j.rebotar()
	else:
		j.recibir_dano(global_position.x)

func _explotar() -> void:
	if not vivo:
		return
	vivo = false
	set_deferred("monitoring", false)
	Global.sumar_moneda(2)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(sprite, "scale", Vector2(1.8, 1.8), 0.18)
	tw.tween_property(sprite, "modulate:a", 0.0, 0.18)
	tw.chain().tween_callback(queue_free)
