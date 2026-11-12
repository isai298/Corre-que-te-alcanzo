extends Node2D
# Don Inflación, el jefe final. Huye de ti por la calle y te lanza cosas.
# Los Cupones que recojas lo debilitan: con 3 cupones es derrotado.

signal derrotado

const SUELO_Y := 520.0
const FW := 304
const FH := 336

var hp: int = 3
var hp_max: int = 3
var jugador
var nivel
var activo: bool = false
var vivo: bool = true
var estado: String = "idle"
var t: float = 0.0
var t_ataque: float = 2.0
var spr: Sprite2D
var hud: Node

func iniciar(n, j) -> void:
	nivel = n
	jugador = j

func _ready() -> void:
	z_index = 3
	scale = Vector2(0.9, 0.9)
	spr = Sprite2D.new()
	spr.texture = load("res://arte/jefe_sheet.png")
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	spr.region_enabled = true
	spr.centered = false
	spr.offset = Vector2(-FW / 2.0, -320.0)
	add_child(spr)
	_frame(0)
	hud = get_parent().get_node_or_null("HUD")

func _frame(i: int) -> void:
	spr.region_rect = Rect2(i * FW, 0, FW, FH)

func activar() -> void:
	activo = true
	global_position = Vector2(jugador.global_position.x + 1500.0, SUELO_Y)
	t_ataque = 2.2
	if hud and hud.has_method("mostrar_jefe"):
		hud.mostrar_jefe("DON INFLACIÓN", hp, hp_max)

func _physics_process(delta: float) -> void:
	if not activo or not vivo or jugador == null:
		return
	t += delta
	var objetivo: float = jugador.global_position.x + 720.0
	global_position.x = lerpf(global_position.x, objetivo, clampf(3.0 * delta, 0.0, 1.0))
	global_position.y = SUELO_Y
	spr.position.y = -absf(sin(t * 5.0)) * 16.0
	if estado == "idle":
		_frame(int(t * 3.0) % 2)
		t_ataque -= delta
		if t_ataque <= 0.0:
			_atacar()

func _atacar() -> void:
	estado = "lanzar"
	_frame(2)
	await get_tree().create_timer(0.45).timeout
	if not vivo:
		return
	var tipo := randi() % 3
	var px: float = jugador.global_position.x
	match tipo:
		0:
			var r = nivel._objeto(nivel.scr_rodante, Vector2(global_position.x - 140.0, SUELO_Y))
			r.velocidad = 440.0
			r.z_index = 3
		1:
			var g = nivel._objeto(nivel.scr_globo, Vector2(global_position.x - 140.0, SUELO_Y - 140.0))
			g.velocidad = 400.0
			g.amplitud = 12.0
			g.z_index = 3
		2:
			nivel._objeto(nivel.scr_etiqueta, Vector2(px + 900.0, SUELO_Y))
			if hp <= 2:
				nivel._objeto(nivel.scr_etiqueta, Vector2(px + 1380.0, SUELO_Y))
	estado = "idle"
	t_ataque = randf_range(1.6, 2.2) - 0.35 * float(hp_max - hp)

func recibir_cupon(origen: Vector2) -> void:
	if not vivo:
		return
	var vuelo := Sprite2D.new()
	vuelo.texture = load("res://arte/meta_cupon.png")
	vuelo.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	vuelo.z_index = 10
	nivel.add_child(vuelo)
	vuelo.global_position = origen
	var tw := create_tween()
	tw.tween_property(vuelo, "global_position", global_position + Vector2(0, -170), 0.45)
	tw.parallel().tween_property(vuelo, "rotation", 8.0, 0.45)
	tw.tween_callback(vuelo.queue_free)
	tw.tween_callback(_herir)

func _herir() -> void:
	if not vivo:
		return
	hp -= 1
	if hud and hud.has_method("actualizar_jefe"):
		hud.actualizar_jefe(hp)
	estado = "herido"
	_frame(3)
	var tw := create_tween()
	for i in range(6):
		tw.tween_property(spr, "modulate", Color(1, 0.4, 0.4) if i % 2 == 0 else Color(1, 1, 1), 0.06)
	if hp <= 0:
		_derrotar()
		return
	await get_tree().create_timer(0.6).timeout
	if vivo:
		estado = "idle"

func _derrotar() -> void:
	vivo = false
	if hud and hud.has_method("ocultar_jefe"):
		hud.ocultar_jefe()
	derrotado.emit()
	# se desinfla y sale volando como un globo
	var tw := create_tween().set_parallel(true)
	tw.tween_property(self, "scale", Vector2(1.25, 1.25), 0.4)
	tw.chain().tween_property(self, "scale", Vector2(0.3, 0.3), 0.7)
	tw.parallel().tween_property(self, "global_position", global_position + Vector2(900, -700), 0.9)
	tw.parallel().tween_property(self, "rotation", 5.0, 0.9)
	tw.parallel().tween_property(self, "modulate:a", 0.0, 0.9)
	tw.chain().tween_callback(queue_free)
