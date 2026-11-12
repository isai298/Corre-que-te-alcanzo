extends "res://nivel_tec.gd"
# Nivel 2: Mercadópolis. Recorrido por el mercado y pelea final contra Don Inflación.

const ARENA_LARGO := 15360.0
var arena_inicio: float = 0.0
var arena_fin: float = 0.0
var arena_activa: bool = false
var jefe: Node2D
var jefe_vivo: bool = true
var cupones: Array = []
var scr_jefe: Script = preload("res://jefe.gd")
var scr_cupon: Script = preload("res://cupon.gd")

func _init() -> void:
	semilla = 77
	longitud = 34000.0
	alias = {
		"suelo_pasto": "m_suelo_pasto", "suelo_tierra": "m_suelo_tierra", "plataforma": "m_plataforma",
		"obs_cono": "m_obs_caja", "obs_bote": "m_obs_canasta", "obs_libros": "m_obs_sandias",
		"obs_banca": "m_obs_carreta", "obs_portico": "m_obs_portico",
	}
	tipos_deco = ["dec_arbol", "m_dec_puesto", "m_dec_puesto", "dec_farol", "m_dec_macetas", "m_dec_cartel", "m_dec_macetas"]

func _ready() -> void:
	super._ready()
	jugador.camara.limit_right = int(arena_fin + 1500.0)

func _crear_fondo() -> void:
	var cl := CanvasLayer.new()
	cl.layer = -10
	add_child(cl)
	var cielo := TextureRect.new()
	cielo.texture = T("m_cielo")
	cielo.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	cielo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	cielo.stretch_mode = TextureRect.STRETCH_SCALE
	cielo.size = Vector2(1152, 648)
	cl.add_child(cielo)
	_capa("m_nubes", 0.10, 30.0, -10.0, -90)
	_capa("m_montanas", 0.18, 110.0, 0.0, -85)
	_capa("m_lomas_lejos", 0.30, 250.0, 0.0, -80)
	_capa("m_lomas_cerca", 0.40, 285.0, 0.0, -75)
	_capa("m_casas_lejos", 0.52, 262.0, 0.0, -70)
	_capa("m_mercado_cerca", 0.78, -12.0, 0.0, -65)

# ----------------------------------------------------------------------
# arena del jefe
# ----------------------------------------------------------------------
func _final_nivel(x: float) -> float:
	_suelo(x, 1408.0)
	_linea_monedas(x + 256.0, SUELO_Y - 100.0, 6)
	arena_inicio = x + 1408.0
	x_meta = arena_inicio
	arena_fin = arena_inicio + ARENA_LARGO
	_suelo(arena_inicio, ARENA_LARGO)
	for i in range(6):
		var cx := arena_inicio + 1900.0 + i * 2300.0
		var cy := SUELO_Y - 110.0
		match i % 3:
			1:
				_plataforma(cx - 96.0, SUELO_Y - 180.0, 3)
				cy = SUELO_Y - 280.0
			2:
				cy = SUELO_Y - 310.0
		var c := _objeto(scr_cupon, Vector2(cx, cy))
		c.nivel = self
		cupones.append(c)
		_arco_monedas(cx - 560.0, cx - 180.0, SUELO_Y - 100.0, 150.0, 5)
	return arena_fin

func _entrar_arena() -> void:
	arena_activa = true
	if perseguidor:
		perseguidor.detener()
	hud.ocultar_progreso()
	jefe = Node2D.new()
	jefe.set_script(scr_jefe)
	add_child(jefe)
	jefe.iniciar(self, jugador)
	jefe.derrotado.connect(_jefe_derrotado)
	jefe.activar()

func cupon_recogido(pos: Vector2) -> void:
	if jefe and is_instance_valid(jefe):
		jefe.recibir_cupon(pos)

func _jefe_derrotado() -> void:
	jefe_vivo = false
	# sale la meta final por delante del jugador
	var mx: float = jugador.global_position.x + 1800.0
	if mx + 900.0 > fin_suelo:
		_construir_segmento(fin_suelo, mx + 900.0 - fin_suelo)
		fin_suelo = mx + 900.0
	x_meta = mx
	_crear_meta(mx)
	jugador.camara.limit_right = int(maxf(mx, arena_fin) + 1500.0)

func _vuelta() -> void:
	# el jefe sigue en pie: damos otra vuelta a la calle (los cupones reaparecen)
	for c in cupones:
		c.reaparecer()
	jugador.global_position.x = arena_inicio + 700.0
	jugador.ultimo_suelo_x = jugador.global_position.x
	jugador.camara.global_position = jugador.global_position
	jugador.camara.reset_smoothing()

func _process(delta: float) -> void:
	if arena_activa:
		if jefe_vivo and jugador.global_position.x > arena_fin - 700.0:
			_vuelta()
		return
	super._process(delta)
	if jugador.global_position.x > arena_inicio:
		_entrar_arena()
