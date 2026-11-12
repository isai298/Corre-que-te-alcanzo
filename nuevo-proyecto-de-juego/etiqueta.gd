extends Area2D
# Etiqueta de precio que cae del cielo cuando te acercas (avisa con un triángulo rojo).

var estado: int = 0       # 0 esperando, 1 cayendo, 2 en el suelo
var vy: float = 0.0
var t_suelo: float = 0.0
var tag: Sprite2D
var marca: Sprite2D
var cs: CollisionShape2D
var jugador

func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	marca = Sprite2D.new()
	marca.texture = load("res://arte/en_marcador.png")
	marca.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	marca.position = Vector2(0, -34)
	add_child(marca)
	tag = Sprite2D.new()
	tag.texture = load("res://arte/en_etiqueta.png")
	tag.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	tag.centered = false
	tag.offset = Vector2(-44, -120)
	tag.position = Vector2(0, -900)
	tag.visible = false
	add_child(tag)
	cs = CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(64, 100)
	cs.shape = r
	cs.disabled = true
	add_child(cs)
	jugador = get_tree().current_scene.get_node_or_null("Jugador")

func _physics_process(delta: float) -> void:
	match estado:
		0:
			marca.modulate.a = 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.014)
			if jugador and jugador.global_position.x > global_position.x - 780.0:
				estado = 1
				tag.visible = true
				cs.disabled = false
		1:
			vy += 3200.0 * delta
			tag.position.y += vy * delta
			if tag.position.y >= 0.0:
				tag.position.y = 0.0
				estado = 2
				marca.visible = false
			cs.position.y = tag.position.y - 50.0
		2:
			t_suelo += delta
			if t_suelo > 1.8:
				var tw := create_tween()
				tw.tween_property(tag, "modulate:a", 0.0, 0.25)
				tw.tween_callback(queue_free)
				set_physics_process(false)
				cs.set_deferred("disabled", true)
	if estado >= 1:
		for c in get_overlapping_bodies():
			if c is CharacterBody2D and c.is_in_group("jugador"):
				if c.muerto:
					return
				if c.arrasa:
					_romper()
				else:
					c.recibir_dano(global_position.x)
				break

func _romper() -> void:
	set_physics_process(false)
	cs.set_deferred("disabled", true)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(tag, "position", tag.position + Vector2(260, -300), 0.5)
	tw.tween_property(tag, "rotation", 6.0, 0.5)
	tw.tween_property(tag, "modulate:a", 0.0, 0.5)
	tw.chain().tween_callback(queue_free)
