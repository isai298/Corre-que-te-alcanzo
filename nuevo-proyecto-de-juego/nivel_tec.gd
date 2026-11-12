extends Node2D
# Nivel "Tec de Xalapa": corredor automático con mapa largo generado por tramos.
# El mapa es siempre el mismo (semilla fija). Cambia "semilla" para otro recorrido.

const SUELO_Y := 520.0
const X_INICIO := 448.0

@export var semilla: int = 2026
@export var inicio_x: float = 0.0  # para probar partes lejanas (0 = desde el principio)
var longitud: float = 46000.0      # largo aproximado del nivel en píxeles
var usar_perseguidor: bool = true
var perseguidor: Node2D

const OBS := {
	"cono":   {"col": Vector2(36, 56)},
	"bote":   {"col": Vector2(44, 64)},
	"libros": {"col": Vector2(60, 44)},
	"banca":  {"col": Vector2(112, 48)},
}
# nombre del patrón: [progreso mínimo, peso]
const PATRONES := {
	"_p_llano": [0.0, 0.6], "_p_conos": [0.0, 2.0], "_p_hueco": [0.03, 2.0],
	"_p_torta": [0.0, 1.6], "_p_escalera": [0.06, 2.0], "_p_portico": [0.1, 2.0],
	"_p_guardia": [0.1, 2.0], "_p_combo": [0.22, 2.0], "_p_zigzag": [0.15, 1.5],
	"_p_isla": [0.25, 2.0], "_p_hueco_doble": [0.4, 1.5], "_p_guardias": [0.4, 2.0],
	"_p_portico_cono": [0.5, 2.0],
	"_p_globos": [0.04, 2.0], "_p_rodantes": [0.08, 2.0], "_p_etiquetas": [0.12, 1.8],
	"_p_trampolin": [0.03, 1.8], "_p_mixto": [0.45, 2.0],
}

var rng := RandomNumberGenerator.new()
var texturas: Dictionary = {}
var alias: Dictionary = {}          # permite cambiar texturas (nivel 2)
var tipos_deco: Array = ["dec_arbol", "dec_arbusto", "dec_arbusto", "dec_farol", "dec_cartel", "dec_bici", "dec_arbol"]
var fin_suelo: float = 0.0
var segmentos: Array = []          # [x_inicio, x_fin] de cada tramo de suelo
var capa_deco: Node2D
var capa_suelo: Node2D
var capa_obj: Node2D
var x_meta: float = 0.0
var total_monedas: int = 0

var esc_moneda: PackedScene = preload("res://moneda_run.tscn")
var esc_torta: PackedScene = preload("res://torta_run.tscn")
var esc_guardia: PackedScene = preload("res://guardia.tscn")
var scr_obstaculo: Script = preload("res://obstaculo.gd")
var scr_meta: Script = preload("res://meta.gd")
var scr_globo: Script = preload("res://globo.gd")
var scr_rodante: Script = preload("res://rodante.gd")
var scr_etiqueta: Script = preload("res://etiqueta.gd")
var scr_trampolin: Script = preload("res://trampolin.gd")
var scr_perseguidor: Script = preload("res://perseguidor.gd")

@onready var jugador: CharacterBody2D = $Jugador
@onready var hud = $HUD

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--x="):
			inicio_x = float(a.substr(4))
		if a.begins_with("--semilla="):
			semilla = int(a.substr(10))
	rng.seed = semilla
	capa_deco = _nodo("Decoracion", -5)
	capa_suelo = _nodo("Suelo", 0)
	capa_obj = _nodo("Objetos", 2)
	_crear_fondo()
	_crear_mundo()
	jugador.global_position = Vector2(X_INICIO, SUELO_Y - 84.0 - 6.0)
	if inicio_x > 0.0:
		jugador.global_position.x = inicio_x
		jugador.ultimo_suelo_x = inicio_x
		jugador.tiempo_jugando = inicio_x / longitud * 45.0 + jugador.retraso_arranque
	jugador.camara.limit_right = int(x_meta + 1200.0)
	if usar_perseguidor:
		_crear_perseguidor()
	jugador.camara.global_position = jugador.global_position
	jugador.camara.reset_smoothing()

func _process(delta: float) -> void:
	var frac := clampf((jugador.global_position.x - X_INICIO) / (x_meta - X_INICIO), 0.0, 1.0)
	hud.actualizar_progreso(frac, int(maxf(jugador.global_position.x - X_INICIO, 0.0) / 64.0))

func _crear_perseguidor() -> void:
	perseguidor = Node2D.new()
	perseguidor.set_script(scr_perseguidor)
	add_child(perseguidor)
	perseguidor.iniciar(jugador, 1100.0)

# ----------------------------------------------------------------------
# utilidades
# ----------------------------------------------------------------------
func _nodo(nombre: String, z: int) -> Node2D:
	var n := Node2D.new()
	n.name = nombre
	n.z_index = z
	add_child(n)
	return n

func T(nombre: String) -> Texture2D:
	var clave: String = alias.get(nombre, nombre)
	if not texturas.has(clave):
		texturas[clave] = load("res://arte/%s.png" % clave)
	return texturas[clave]

func _sprite_base(nombre: String, padre: Node, escala: float = 1.0) -> Sprite2D:
	# el origen queda en el centro de la base del dibujo
	var s := Sprite2D.new()
	s.texture = T(nombre)
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	s.centered = false
	var tam := s.texture.get_size() * escala
	s.scale = Vector2(escala, escala)
	s.offset = Vector2(-s.texture.get_width() / 2.0, -s.texture.get_height())
	padre.add_child(s)
	return s

func _region(nombre: String, x: float, y: float, w: float, h: float, padre: Node) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = T(nombre)
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	s.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	s.centered = false
	s.region_enabled = true
	s.region_rect = Rect2(0, 0, w, h)
	s.position = Vector2(x, y)
	padre.add_child(s)
	return s

# ----------------------------------------------------------------------
# fondo con parallax
# ----------------------------------------------------------------------
func _crear_fondo() -> void:
	var cl := CanvasLayer.new()
	cl.layer = -10
	add_child(cl)
	var cielo := TextureRect.new()
	cielo.texture = T("bg_cielo")
	cielo.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	cielo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	cielo.stretch_mode = TextureRect.STRETCH_SCALE
	cielo.size = Vector2(1152, 648)
	cl.add_child(cielo)
	_capa("bg_nubes", 0.10, 30.0, -10.0, -90)
	_capa("bg_montanas", 0.18, 110.0, 0.0, -85)
	_capa("bg_lomas_lejos", 0.30, 250.0, 0.0, -80)
	_capa("bg_lomas_cerca", 0.40, 285.0, 0.0, -75)
	_capa("bg_campus_lejos", 0.52, 262.0, 0.0, -70)
	_capa("bg_campus_cerca", 0.78, -12.0, 0.0, -65)

func _capa(nombre: String, factor: float, y: float, auto: float, z: int) -> void:
	var p := Parallax2D.new()
	var tex := T(nombre)
	p.scroll_scale = Vector2(factor, 1.0)
	p.repeat_size = Vector2(tex.get_width(), 0)
	p.repeat_times = 3
	p.autoscroll = Vector2(auto, 0)
	p.z_index = z
	var s := Sprite2D.new()
	s.texture = tex
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	s.centered = false
	s.position = Vector2(0, y)
	p.add_child(s)
	add_child(p)

# ----------------------------------------------------------------------
# construcción del mundo
# ----------------------------------------------------------------------
func _crear_mundo() -> void:
	# tramo de arranque
	_suelo(-640.0, 2240.0)
	_linea_monedas(960.0, SUELO_Y - 100.0, 6)
	_obstaculo("cono", 1344.0)
	_arco_monedas(1184.0, 1504.0, SUELO_Y - 100.0, 180.0, 7)
	var x := 1600.0
	var anterior := ""
	while x < longitud - 2400.0:
		var prog := x / longitud
		var nombre := _elegir_patron(prog, anterior)
		if Global.modo_prueba:
			print("patron ", nombre, " x=", int(x))
		x += float(call(nombre, x))
		anterior = nombre
	_final_nivel(x)
	_construir_suelo()
	_decorar()

func _final_nivel(x: float) -> float:
	# tramo final con la meta
	_suelo(x, 2560.0)
	_linea_monedas(x + 320.0, SUELO_Y - 100.0, 8)
	x_meta = x + 1792.0
	if Global.modo_prueba:
		print("meta x=", int(x_meta))
	_crear_meta(x_meta)
	return x + 2560.0

func _elegir_patron(prog: float, anterior: String) -> String:
	var candidatos: Array = []
	var pesos: Array = []
	var suma := 0.0
	for n in PATRONES:
		var d: Array = PATRONES[n]
		if prog < d[0] or n == anterior:
			continue
		if n == "_p_llano" and prog > 0.4:
			continue
		candidatos.append(n)
		pesos.append(d[1])
		suma += d[1]
	var r := rng.randf() * suma
	for i in range(candidatos.size()):
		r -= pesos[i]
		if r <= 0.0:
			return candidatos[i]
	return candidatos[0]

func _suelo(x: float, w: float) -> void:
	segmentos.append([x, x + w])

func _construir_suelo() -> void:
	segmentos.sort_custom(func(a, b): return a[0] < b[0])
	var fusion: Array = []
	for s in segmentos:
		if fusion.size() > 0 and absf(fusion[-1][1] - s[0]) < 1.0:
			fusion[-1][1] = s[1]
		else:
			fusion.append([s[0], s[1]])
	segmentos = fusion
	for i in range(segmentos.size()):
		var x: float = segmentos[i][0]
		var w: float = segmentos[i][1] - segmentos[i][0]
		_construir_segmento(x, w)
		fin_suelo = maxf(fin_suelo, segmentos[i][1])
		# hueco oscuro hasta el siguiente tramo
		if i < segmentos.size() - 1:
			var x2: float = segmentos[i][1]
			var w2: float = segmentos[i + 1][0] - x2
			var h := ColorRect.new()
			h.color = Color(0.07, 0.09, 0.2)
			h.position = Vector2(x2, SUELO_Y)
			h.size = Vector2(w2, 500)
			h.z_index = -1
			capa_suelo.add_child(h)

func _construir_segmento(x: float, w: float) -> void:
	var cuerpo := StaticBody2D.new()
	cuerpo.collision_layer = 1
	cuerpo.collision_mask = 0
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(w, 300)
	cs.shape = r
	cs.position = Vector2(x + w / 2.0, SUELO_Y + 150.0)
	cuerpo.add_child(cs)
	capa_suelo.add_child(cuerpo)
	_region("suelo_pasto", x, SUELO_Y, w, 64, capa_suelo)
	_region("suelo_tierra", x, SUELO_Y + 64.0, w, 300, capa_suelo)

func _plataforma(x: float, y_top: float, tiles: int) -> void:
	var w := tiles * 64.0
	var cuerpo := StaticBody2D.new()
	cuerpo.collision_layer = 1
	cuerpo.collision_mask = 0
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(w, 32)
	cs.shape = r
	cs.one_way_collision = true
	cs.position = Vector2(x + w / 2.0, y_top + 16.0)
	cuerpo.add_child(cs)
	capa_suelo.add_child(cuerpo)
	_region("plataforma", x, y_top, w, 32, capa_suelo)

func _moneda(x: float, y: float) -> void:
	var m := esc_moneda.instantiate()
	m.position = Vector2(x, y)
	m.z_index = 3
	capa_obj.add_child(m)
	total_monedas += 1

func _linea_monedas(x: float, y: float, n: int, sep: float = 76.0) -> void:
	for i in range(n):
		_moneda(x + i * sep, y)

func _arco_monedas(xa: float, xb: float, y0: float, alto: float, n: int) -> void:
	for i in range(n):
		var t := float(i) / float(n - 1)
		_moneda(lerpf(xa, xb, t), y0 - alto * 4.0 * t * (1.0 - t))

func _obstaculo(tipo: String, cx: float) -> void:
	var d: Dictionary = OBS[tipo]
	var col: Vector2 = d["col"]
	var a := Area2D.new()
	a.set_script(scr_obstaculo)
	a.position = Vector2(cx, SUELO_Y)
	a.set_meta("tipo", tipo)
	_sprite_base("obs_" + tipo, a)
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = col
	cs.shape = r
	cs.position = Vector2(0, -col.y / 2.0 - 2.0)
	a.add_child(cs)
	capa_obj.add_child(a)

func _portico(cx: float) -> void:
	# letrero que cuelga: hay que deslizarse (↓) para pasar por debajo
	var a := Area2D.new()
	a.set_script(scr_obstaculo)
	a.position = Vector2(cx, SUELO_Y)
	a.set_meta("tipo", "portico")
	_sprite_base("obs_portico", a)
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(176, 60)
	cs.shape = r
	cs.position = Vector2(0, -138)
	a.add_child(cs)
	capa_obj.add_child(a)

func _guardia(cx: float, dist: float) -> void:
	var g := esc_guardia.instantiate()
	g.position = Vector2(cx, SUELO_Y)
	g.set_meta("tipo", "guardia")
	g.distancia = dist
	g.z_index = 3
	capa_obj.add_child(g)

func _objeto(scr: Script, pos: Vector2) -> Area2D:
	var a := Area2D.new()
	a.set_script(scr)
	a.position = pos
	capa_obj.add_child(a)
	return a

func _globo(x: float, y: float) -> void:
	var g := _objeto(scr_globo, Vector2(x, y))
	g.set_meta("tipo", "globo")
	g.z_index = 3

func _rodante(x: float) -> void:
	var r := _objeto(scr_rodante, Vector2(x, SUELO_Y))
	r.set_meta("tipo", "rodante")
	r.z_index = 3

func _etiqueta(x: float) -> void:
	var e := _objeto(scr_etiqueta, Vector2(x, SUELO_Y))
	e.set_meta("tipo", "etiqueta")

func _trampolin(x: float) -> void:
	_objeto(scr_trampolin, Vector2(x, SUELO_Y))

func _torta(x: float, y: float) -> void:
	var t := esc_torta.instantiate()
	t.position = Vector2(x, y)
	t.z_index = 3
	capa_obj.add_child(t)

func _crear_meta(cx: float) -> void:
	var a := Area2D.new()
	a.set_script(scr_meta)
	a.collision_layer = 0
	a.collision_mask = 2
	a.position = Vector2(cx, SUELO_Y)
	var s := _sprite_base("meta_cupon", a, 1.6)
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(130, 200)
	cs.shape = r
	cs.position = Vector2(0, -100)
	a.add_child(cs)
	capa_obj.add_child(a)
	# monedas de celebración alrededor
	_arco_monedas(cx - 420.0, cx - 120.0, SUELO_Y - 90.0, 200.0, 6)

# ----------------------------------------------------------------------
# patrones (cada uno devuelve su ancho, múltiplo de 64)
# ----------------------------------------------------------------------
func _p_llano(x: float) -> float:
	_suelo(x, 1024)
	_linea_monedas(x + 192.0, SUELO_Y - 100.0, 8)
	return 1024.0

func _p_conos(x: float) -> float:
	_suelo(x, 1344)
	_obstaculo("cono", x + 448.0)
	_arco_monedas(x + 288.0, x + 608.0, SUELO_Y - 100.0, 180.0, 7)
	_obstaculo("bote", x + 960.0)
	_arco_monedas(x + 800.0, x + 1120.0, SUELO_Y - 100.0, 190.0, 7)
	return 1344.0

func _p_hueco(x: float) -> float:
	_suelo(x, 576)
	_suelo(x + 896.0, 640)
	_arco_monedas(x + 440.0, x + 1000.0, SUELO_Y - 120.0, 260.0, 9)
	return 1536.0

func _p_isla(x: float) -> float:
	_suelo(x, 576)
	_suelo(x + 1472.0, 832)
	_plataforma(x + 832.0, SUELO_Y - 130.0, 5)
	_linea_monedas(x + 880.0, SUELO_Y - 200.0, 4, 80.0)
	_arco_monedas(x + 520.0, x + 880.0, SUELO_Y - 130.0, 170.0, 6)
	_arco_monedas(x + 1120.0, x + 1540.0, SUELO_Y - 130.0, 180.0, 6)
	return 2304.0

func _p_escalera(x: float) -> float:
	_suelo(x, 2048)
	_plataforma(x + 320.0, SUELO_Y - 150.0, 5)
	_linea_monedas(x + 380.0, SUELO_Y - 220.0, 4, 80.0)
	_plataforma(x + 832.0, SUELO_Y - 280.0, 5)
	_linea_monedas(x + 892.0, SUELO_Y - 350.0, 4, 80.0)
	_plataforma(x + 1344.0, SUELO_Y - 150.0, 5)
	_linea_monedas(x + 1404.0, SUELO_Y - 220.0, 4, 80.0)
	_obstaculo("cono", x + 1856.0)
	return 2048.0

func _p_portico(x: float) -> float:
	_suelo(x, 2048)
	_obstaculo("cono", x + 320.0)
	_arco_monedas(x + 160.0, x + 480.0, SUELO_Y - 100.0, 180.0, 6)
	_portico(x + 1152.0)
	_linea_monedas(x + 980.0, SUELO_Y - 50.0, 6, 70.0)
	return 2048.0

func _p_guardia(x: float) -> float:
	_suelo(x, 1600)
	_guardia(x + 832.0, 150.0)
	_arco_monedas(x + 560.0, x + 1100.0, SUELO_Y - 100.0, 300.0, 8)
	return 1600.0

func _p_torta(x: float) -> float:
	_suelo(x, 1664)
	_plataforma(x + 512.0, SUELO_Y - 170.0, 4)
	_torta(x + 640.0, SUELO_Y - 250.0)
	_linea_monedas(x + 160.0, SUELO_Y - 100.0, 4)
	_linea_monedas(x + 1000.0, SUELO_Y - 100.0, 5)
	return 1664.0

func _p_combo(x: float) -> float:
	_suelo(x, 2560)
	_obstaculo("cono", x + 448.0)
	_arco_monedas(x + 288.0, x + 608.0, SUELO_Y - 100.0, 180.0, 6)
	_obstaculo("banca", x + 960.0)
	_arco_monedas(x + 760.0, x + 1160.0, SUELO_Y - 100.0, 200.0, 7)
	_obstaculo("libros", x + 1600.0)
	_arco_monedas(x + 1420.0, x + 1780.0, SUELO_Y - 100.0, 190.0, 6)
	_obstaculo("cono", x + 2048.0)
	_obstaculo("bote", x + 2368.0)
	return 2560.0

func _p_zigzag(x: float) -> float:
	_suelo(x, 1856)
	_plataforma(x + 320.0, SUELO_Y - 130.0, 3)
	_linea_monedas(x + 360.0, SUELO_Y - 200.0, 3, 70.0)
	_plataforma(x + 768.0, SUELO_Y - 240.0, 3)
	_linea_monedas(x + 808.0, SUELO_Y - 310.0, 3, 70.0)
	_plataforma(x + 1216.0, SUELO_Y - 130.0, 3)
	_linea_monedas(x + 1256.0, SUELO_Y - 200.0, 3, 70.0)
	_obstaculo("bote", x + 1664.0)
	return 1856.0

func _p_hueco_doble(x: float) -> float:
	_suelo(x, 640)
	_suelo(x + 960.0, 640)
	_suelo(x + 1984.0, 704)
	_arco_monedas(x + 500.0, x + 1100.0, SUELO_Y - 120.0, 260.0, 9)
	_arco_monedas(x + 1500.0, x + 2100.0, SUELO_Y - 120.0, 280.0, 9)
	return 2688.0

func _p_guardias(x: float) -> float:
	_suelo(x, 2048)
	_guardia(x + 640.0, 120.0)
	_arco_monedas(x + 440.0, x + 860.0, SUELO_Y - 100.0, 290.0, 7)
	_obstaculo("banca", x + 1280.0)
	_guardia(x + 1664.0, 140.0)
	_arco_monedas(x + 1440.0, x + 1900.0, SUELO_Y - 100.0, 300.0, 7)
	return 2048.0

func _p_portico_cono(x: float) -> float:
	_suelo(x, 3008)
	_portico(x + 768.0)
	_linea_monedas(x + 600.0, SUELO_Y - 50.0, 6, 70.0)
	_obstaculo("cono", x + 1600.0)
	_arco_monedas(x + 1440.0, x + 1760.0, SUELO_Y - 100.0, 190.0, 7)
	_portico(x + 2496.0)
	_linea_monedas(x + 2330.0, SUELO_Y - 50.0, 6, 70.0)
	return 3008.0

func _p_globos(x: float) -> float:
	_suelo(x, 2176)
	_globo(x + 768.0, SUELO_Y - 150.0)
	_linea_monedas(x + 700.0, SUELO_Y - 340.0, 4, 76.0)
	_globo(x + 1344.0, SUELO_Y - 270.0)
	_arco_monedas(x + 1250.0, x + 1500.0, SUELO_Y - 100.0, 160.0, 5)
	_globo(x + 1856.0, SUELO_Y - 150.0)
	return 2176.0

func _p_rodantes(x: float) -> float:
	_suelo(x, 2112)
	_rodante(x + 896.0)
	_arco_monedas(x + 640.0, x + 900.0, SUELO_Y - 100.0, 170.0, 5)
	_rodante(x + 1408.0)
	_rodante(x + 1856.0)
	_arco_monedas(x + 1500.0, x + 1900.0, SUELO_Y - 100.0, 210.0, 6)
	return 2112.0

func _p_etiquetas(x: float) -> float:
	_suelo(x, 2368)
	_etiqueta(x + 832.0)
	_arco_monedas(x + 660.0, x + 960.0, SUELO_Y - 100.0, 170.0, 6)
	_etiqueta(x + 1344.0)
	_etiqueta(x + 1856.0)
	_arco_monedas(x + 1700.0, x + 2000.0, SUELO_Y - 100.0, 170.0, 6)
	return 2368.0

func _p_trampolin(x: float) -> float:
	_suelo(x, 2432)
	_trampolin(x + 576.0)
	_plataforma(x + 1088.0, SUELO_Y - 400.0, 8)
	_torta(x + 1340.0, SUELO_Y - 480.0)
	_linea_monedas(x + 1120.0, SUELO_Y - 470.0, 3, 80.0)
	_linea_monedas(x + 1500.0, SUELO_Y - 470.0, 2, 80.0)
	_linea_monedas(x + 1700.0, SUELO_Y - 100.0, 5)
	return 2432.0

func _p_mixto(x: float) -> float:
	_suelo(x, 3072)
	_obstaculo("cono", x + 512.0)
	_arco_monedas(x + 352.0, x + 672.0, SUELO_Y - 100.0, 180.0, 6)
	_globo(x + 1280.0, SUELO_Y - 150.0)
	_rodante(x + 1856.0)
	_guardia(x + 2240.0, 140.0)
	_arco_monedas(x + 2000.0, x + 2480.0, SUELO_Y - 100.0, 300.0, 8)
	_obstaculo("bote", x + 2944.0)
	return 3072.0

# ----------------------------------------------------------------------
# decoración del campus (no estorba)
# ----------------------------------------------------------------------
func _decorar() -> void:
	var tipos: Array = tipos_deco
	for s in segmentos:
		var x: float = float(s[0]) + 140.0
		while x < float(s[1]) - 160.0:
			var tipo: String = tipos[rng.randi() % tipos.size()]
			var d := Node2D.new()
			d.position = Vector2(x, SUELO_Y + 6.0)
			var sp := _sprite_base(tipo, d)
			if not tipo.ends_with("cartel") and rng.randf() < 0.5:
				sp.flip_h = true
			capa_deco.add_child(d)
			x += rng.randf_range(260.0, 640.0)
