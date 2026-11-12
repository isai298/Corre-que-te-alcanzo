extends Node2D
# "La Inflación": una bola de billetes gigante que persigue al jugador.
# Si te golpean o frenas, se acerca. Si te alcanza, pierdes una vida y se aleja.

const RADIO := 144.0
const SUELO_Y := 520.0

var jugador
var gap: float = 1300.0
var activo: bool = true
var bola: Sprite2D
var cara: Sprite2D
var hud: Node

func iniciar(j, gap_inicial: float = 1300.0) -> void:
	jugador = j
	gap = gap_inicial
	global_position = Vector2(j.global_position.x - gap, SUELO_Y - RADIO + 14.0)

func _ready() -> void:
	z_index = 4
	bola = Sprite2D.new()
	bola.texture = load("res://arte/perseg_bola.png")
	bola.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(bola)
	cara = Sprite2D.new()
	cara.texture = load("res://arte/perseg_cara.png")
	cara.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	cara.position = Vector2(8, -18)
	add_child(cara)
	hud = get_parent().get_node_or_null("HUD")

func _physics_process(delta: float) -> void:
	if not activo or jugador == null or jugador.muerto:
		return
	var base: float = clampf(jugador.default_speed + jugador.tiempo_jugando * jugador.aceleracion, jugador.default_speed, jugador.default_run_speed)
	var v: float = base * 0.93
	if jugador.tiempo_jugando < jugador.retraso_arranque:
		v = 0.0
	gap = jugador.global_position.x - global_position.x
	if gap > 1000.0:
		v *= 1.25            # si te alejas demasiado, acelera para no perder la tensión
	global_position.x += v * delta
	bola.rotation += v / RADIO * delta
	cara.position.y = -18.0 + sin(Time.get_ticks_msec() * 0.012) * 3.0
	gap = jugador.global_position.x - global_position.x
	var peligro := clampf(1.0 - (gap - 280.0) / 700.0, 0.0, 1.0)
	if hud and hud.has_method("set_peligro"):
		hud.set_peligro(peligro)
	if gap <= RADIO * 0.85 + 30.0:
		_atrapar()

func _atrapar() -> void:
	jugador.recibir_dano(global_position.x)
	global_position.x = jugador.global_position.x - 1000.0

func detener() -> void:
	activo = false
	visible = false
	if hud and hud.has_method("set_peligro"):
		hud.set_peligro(0.0)
