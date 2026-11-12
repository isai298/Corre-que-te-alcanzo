extends Area2D
# Bola de billetes pequeña que rueda hacia ti. Salta sobre ella o aplástala.

@export var velocidad: float = 320.0

var vivo: bool = true
var giro: Sprite2D

func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	giro = Sprite2D.new()
	giro.texture = load("res://arte/en_rodante.png")
	giro.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	giro.position = Vector2(0, -36)
	add_child(giro)
	var cs := CollisionShape2D.new()
	var c := CircleShape2D.new()
	c.radius = 28.0
	cs.shape = c
	cs.position = Vector2(0, -36)
	add_child(cs)
	var n := VisibleOnScreenNotifier2D.new()
	n.rect = Rect2(-100, -200, 200, 220)
	add_child(n)
	n.screen_entered.connect(func(): set_physics_process(true))
	n.screen_exited.connect(func(): if is_physics_processing() and global_position.x < get_tree().current_scene.get_node("Jugador").global_position.x: queue_free())
	set_physics_process(false)

func _physics_process(delta: float) -> void:
	if not vivo:
		return
	global_position.x -= velocidad * delta
	giro.rotation -= velocidad / 36.0 * delta
	for c in get_overlapping_bodies():
		if c is CharacterBody2D and c.is_in_group("jugador"):
			_tocar(c)
			break

func _tocar(j) -> void:
	if j.muerto:
		return
	if j.arrasa:
		_morir()
		return
	if j.velocity.y > 0.0 and j.pies_y() <= global_position.y - 40.0:
		_morir()
		j.rebotar()
	else:
		j.recibir_dano(global_position.x)

func _morir() -> void:
	if not vivo:
		return
	vivo = false
	set_deferred("monitoring", false)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(giro, "scale", Vector2(1.5, 0.2), 0.15)
	tw.tween_property(giro, "modulate:a", 0.0, 0.2)
	tw.chain().tween_callback(queue_free)
