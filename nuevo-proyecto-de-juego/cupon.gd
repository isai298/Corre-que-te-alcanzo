extends Area2D
# Cupón Dorado de la pelea final: al recogerlo, golpea a Don Inflación.

var nivel
var recogido: bool = false
var sprite: Sprite2D

func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	sprite = Sprite2D.new()
	sprite.texture = load("res://arte/meta_cupon.png")
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.scale = Vector2(1.0, 1.0)
	add_child(sprite)
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(110, 140)
	cs.shape = r
	add_child(cs)
	body_entered.connect(_al_entrar)
	var tw := create_tween().set_loops()
	tw.tween_property(sprite, "position:y", -10.0, 0.45).set_trans(Tween.TRANS_SINE)
	tw.tween_property(sprite, "position:y", 10.0, 0.45).set_trans(Tween.TRANS_SINE)
	var tw2 := create_tween().set_loops()
	tw2.tween_property(sprite, "modulate", Color(1.4, 1.3, 0.8), 0.5)
	tw2.tween_property(sprite, "modulate", Color(1, 1, 1), 0.5)

func _al_entrar(c: Node) -> void:
	if recogido:
		return
	if c is CharacterBody2D and c.is_in_group("jugador"):
		recogido = true
		visible = false
		set_deferred("monitoring", false)
		nivel.cupon_recogido(global_position)

func reaparecer() -> void:
	recogido = false
	visible = true
	set_deferred("monitoring", true)
