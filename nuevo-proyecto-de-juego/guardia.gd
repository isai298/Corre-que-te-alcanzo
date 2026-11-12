extends Area2D
# Guardia (antagónico) que patrulla. Si lo aplastas desde arriba muere;
# si te toca de frente pierdes una vida. Con el power up "Gigante" lo arrollas.

@export var velocidad: float = 120.0
@export var distancia: float = 170.0

const FW := 124
const FH := 200
const CUADROS := 21
const COLUMNAS := 5

var direccion: float = -1.0
var x_min: float = 0.0
var x_max: float = 0.0
var vivo: bool = true

@onready var sprite: AnimatedSprite2D = $Movimientos

func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	x_min = global_position.x - distancia
	x_max = global_position.x + distancia
	var tex: Texture2D = load("res://arte/guardia_sheet.png")
	var sf := SpriteFrames.new()
	sf.remove_animation("default")
	sf.add_animation("caminar")
	sf.set_animation_speed("caminar", 11.0)
	sf.set_animation_loop("caminar", true)
	for i in range(CUADROS):
		var at := AtlasTexture.new()
		at.atlas = tex
		at.region = Rect2((i % COLUMNAS) * FW, (i / COLUMNAS) * FH, FW, FH)
		sf.add_frame("caminar", at)
	sprite.sprite_frames = sf
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.play("caminar")
	set_physics_process(false)
	# Solo se mueve cuando el jugador está cerca (ahorra trabajo)
	var visible_notifier := VisibleOnScreenNotifier2D.new()
	visible_notifier.rect = Rect2(-300, -220, 600, 260)
	add_child(visible_notifier)
	visible_notifier.screen_entered.connect(func(): set_physics_process(true))

func _physics_process(delta: float) -> void:
	if not vivo:
		return
	global_position.x += direccion * velocidad * delta
	if global_position.x >= x_max:
		direccion = -1.0
	elif global_position.x <= x_min:
		direccion = 1.0
	sprite.flip_h = direccion < 0.0       # el sprite original mira a la derecha
	for cuerpo in get_overlapping_bodies():
		if cuerpo is CharacterBody2D and cuerpo.is_in_group("jugador"):
			_tocar_jugador(cuerpo)
			break

func _tocar_jugador(j) -> void:
	if j.muerto:
		return
	if j.arrasa:
		_morir()
		return
	var cae_encima: bool = j.velocity.y > 0.0 and j.pies_y() <= global_position.y - 100.0
	if cae_encima:
		_morir()
		j.rebotar()
	else:
		j.recibir_dano(global_position.x)

func _morir() -> void:
	if not vivo:
		return
	vivo = false
	set_deferred("monitoring", false)
	var t := create_tween()
	t.tween_property(self, "scale:y", 0.12, 0.15)
	t.parallel().tween_property(self, "modulate:a", 0.0, 0.25)
	t.tween_callback(queue_free)
