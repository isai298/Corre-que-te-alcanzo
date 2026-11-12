extends Area2D
# Trampolín: te lanza muy alto (para llegar a plataformas altas y monedas).

var sprite: Sprite2D
var tex_arriba: Texture2D
var tex_abajo: Texture2D

func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	tex_arriba = load("res://arte/obj_trampolin1.png")
	tex_abajo = load("res://arte/obj_trampolin0.png")
	sprite = Sprite2D.new()
	sprite.texture = tex_arriba
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.centered = false
	sprite.offset = Vector2(-48, -56)
	add_child(sprite)
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(96, 36)
	cs.shape = r
	cs.position = Vector2(0, -18)
	add_child(cs)
	body_entered.connect(_al_entrar)

func _al_entrar(c: Node) -> void:
	if c is CharacterBody2D and c.is_in_group("jugador"):
		c.velocity.y = -1380.0
		c.saltos_restantes = 1
		c.coyote = 0.0
		c.corte_salto = true
		sprite.texture = tex_abajo
		await get_tree().create_timer(0.25).timeout
		sprite.texture = tex_arriba
