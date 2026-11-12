extends CanvasLayer

@onready var label_monedas: Label = $ContenedorMonedas/LabelMonedas
@onready var label_vidas: Label = $ContenedorMonedas/LabelVidas
@onready var pantalla_fin: Control = $PantallaFin
@onready var titulo: Label = $PantallaFin/Centro/Caja/Titulo
@onready var resumen: Label = $PantallaFin/Centro/Caja/Resumen
@onready var boton_reintentar: Button = $PantallaFin/Centro/Caja/BotonReintentar
@onready var boton_menu: Button = $PantallaFin/Centro/Caja/BotonMenu

var barra: ProgressBar
var progreso_oculto: bool = false
var boton_siguiente: Button
var jefe_panel: Control
var jefe_barra: ProgressBar
var jefe_label: Label
var poder_panel: Control
var poder_label: Label
var poder_barra: ProgressBar
var poder_tween: Tween
var label_metros: Label

func _ready() -> void:
	_crear_peligro()
	_crear_progreso()
	Global.monedas_cambiadas.connect(_on_monedas_cambiadas)
	Global.vidas_cambiadas.connect(_on_vidas_cambiadas)
	Global.juego_terminado.connect(_on_juego_terminado)
	boton_reintentar.pressed.connect(Global.reiniciar_juego)
	boton_menu.pressed.connect(Global.ir_al_menu)
	boton_siguiente = Button.new()
	boton_siguiente.text = "Siguiente nivel  ▶"
	boton_siguiente.custom_minimum_size = Vector2(260, 54)
	boton_siguiente.add_theme_font_size_override("font_size", 24)
	boton_siguiente.pressed.connect(Global.siguiente_nivel)
	boton_siguiente.visible = false
	boton_reintentar.get_parent().add_child(boton_siguiente)
	boton_reintentar.get_parent().move_child(boton_siguiente, boton_reintentar.get_index())
	pantalla_fin.visible = false
	for l in [label_monedas, label_vidas]:
		l.add_theme_color_override("font_outline_color", Color(0.04, 0.1, 0.23))
		l.add_theme_constant_override("outline_size", 8)
	actualizar_monedas()
	_on_vidas_cambiadas(Global.vidas)

# Se deja con este nombre por compatibilidad con otros scripts
func actualizar_monedas() -> void:
	if label_monedas:
		label_monedas.text = "Monedas: " + str(Global.monedas)

func _on_monedas_cambiadas(_total: int) -> void:
	actualizar_monedas()

func _on_vidas_cambiadas(total: int) -> void:
	label_vidas.text = "Vidas: " + str(total)

func _on_juego_terminado(victoria: bool) -> void:
	boton_siguiente.visible = false
	if victoria and Global.hay_siguiente():
		titulo.text = "¡NIVEL COMPLETADO!"
		resumen.text = "Recuperaste el Cupón Dorado\nMonedas: " + str(Global.monedas)
		boton_siguiente.visible = true
	elif victoria:
		titulo.text = "¡DERROTASTE A DON INFLACIÓN!"
		resumen.text = "Mercadópolis es libre otra vez\nMonedas: " + str(Global.monedas)
	else:
		titulo.text = "GAME OVER"
		resumen.text = "Don Inflación te ganó esta vez\nMonedas: " + str(Global.monedas)
	pantalla_fin.visible = true
	get_tree().paused = true

# ---- barra de progreso hacia el Cupón Dorado (se crea por código) ----
func _crear_progreso() -> void:
	barra = ProgressBar.new()
	barra.min_value = 0.0
	barra.max_value = 1.0
	barra.step = 0.0005
	barra.show_percentage = false
	barra.position = Vector2(356, 22)
	barra.size = Vector2(440, 20)
	var fondo := StyleBoxFlat.new()
	fondo.bg_color = Color(0.04, 0.1, 0.23, 0.7)
	fondo.set_corner_radius_all(10)
	fondo.set_border_width_all(2)
	fondo.border_color = Color(1, 1, 1, 0.85)
	var relleno := StyleBoxFlat.new()
	relleno.bg_color = Color(0.96, 0.72, 0.0)
	relleno.set_corner_radius_all(10)
	barra.add_theme_stylebox_override("background", fondo)
	barra.add_theme_stylebox_override("fill", relleno)
	barra.visible = false
	add_child(barra)
	label_metros = Label.new()
	label_metros.position = Vector2(356, 46)
	label_metros.size = Vector2(440, 30)
	label_metros.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label_metros.add_theme_font_size_override("font_size", 20)
	label_metros.add_theme_color_override("font_outline_color", Color(0.04, 0.1, 0.23))
	label_metros.add_theme_constant_override("outline_size", 6)
	label_metros.visible = false
	add_child(label_metros)

func actualizar_progreso(frac: float, metros: int) -> void:
	if progreso_oculto:
		return
	if barra:
		barra.visible = true
		barra.value = frac
	if label_metros:
		label_metros.visible = true
		label_metros.text = "%d m   ·   Cupón Dorado ★" % metros

# ---- indicador del poder activo ----
const COLORES_PODER := {"Imán": Color(0.95, 0.3, 0.3), "Escudo": Color(0.4, 0.75, 1.0), "Turbo": Color(1.0, 0.6, 0.15), "Gigante": Color(0.96, 0.72, 0.0), "Súper Salto": Color(0.4, 0.85, 0.4)}

func _crear_poder() -> void:
	poder_panel = Control.new()
	poder_panel.position = Vector2(20, 118)
	poder_panel.visible = false
	add_child(poder_panel)
	poder_label = Label.new()
	poder_label.add_theme_font_size_override("font_size", 24)
	poder_label.add_theme_color_override("font_outline_color", Color(0.04, 0.1, 0.23))
	poder_label.add_theme_constant_override("outline_size", 7)
	poder_panel.add_child(poder_label)
	poder_barra = ProgressBar.new()
	poder_barra.position = Vector2(0, 34)
	poder_barra.size = Vector2(200, 14)
	poder_barra.show_percentage = false
	poder_barra.max_value = 1.0
	var fondo := StyleBoxFlat.new()
	fondo.bg_color = Color(0.04, 0.1, 0.23, 0.7)
	fondo.set_corner_radius_all(7)
	poder_barra.add_theme_stylebox_override("background", fondo)
	poder_panel.add_child(poder_barra)

func mostrar_poder(nombre: String, dur: float) -> void:
	if poder_panel == null:
		_crear_poder()
	var col: Color = COLORES_PODER.get(nombre, Color.WHITE)
	poder_label.text = "★ " + nombre
	poder_label.add_theme_color_override("font_color", col)
	var relleno := StyleBoxFlat.new()
	relleno.bg_color = col
	relleno.set_corner_radius_all(7)
	poder_barra.add_theme_stylebox_override("fill", relleno)
	poder_barra.value = 1.0
	poder_panel.visible = true
	if poder_tween:
		poder_tween.kill()
	poder_tween = create_tween()
	poder_tween.tween_property(poder_barra, "value", 0.0, dur)

func ocultar_poder() -> void:
	if poder_tween:
		poder_tween.kill()
	if poder_panel:
		poder_panel.visible = false

# ---- aviso rojo cuando te alcanza la Inflación ----
var peligro_rect: TextureRect
var peligro_label: Label

func ocultar_progreso() -> void:
	progreso_oculto = true
	if barra:
		barra.visible = false
	if label_metros:
		label_metros.visible = false

func _crear_peligro() -> void:
	var g := Gradient.new()
	g.set_color(0, Color(0.9, 0.1, 0.1, 0.85))
	g.set_color(1, Color(0.9, 0.1, 0.1, 0.0))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(1, 0)
	gt.width = 256
	gt.height = 8
	peligro_rect = TextureRect.new()
	peligro_rect.texture = gt
	peligro_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	peligro_rect.stretch_mode = TextureRect.STRETCH_SCALE
	peligro_rect.size = Vector2(340, 648)
	peligro_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	peligro_rect.modulate.a = 0.0
	add_child(peligro_rect)
	move_child(peligro_rect, 0)
	peligro_label = Label.new()
	peligro_label.text = "¡CORRE!"
	peligro_label.position = Vector2(24, 300)
	peligro_label.add_theme_font_size_override("font_size", 44)
	peligro_label.add_theme_color_override("font_color", Color(1, 0.95, 0.5))
	peligro_label.add_theme_color_override("font_outline_color", Color(0.5, 0.05, 0.05))
	peligro_label.add_theme_constant_override("outline_size", 10)
	peligro_label.visible = false
	add_child(peligro_label)

func set_peligro(v: float) -> void:
	if peligro_rect == null:
		return
	var parpadeo := 0.65 + 0.35 * sin(Time.get_ticks_msec() * 0.014)
	peligro_rect.modulate.a = v * parpadeo
	peligro_label.visible = v > 0.55

# ---- barra de vida del jefe ----
func mostrar_jefe(nombre: String, hp: int, hp_max: int) -> void:
	if jefe_panel == null:
		jefe_panel = Control.new()
		jefe_panel.position = Vector2(326, 18)
		add_child(jefe_panel)
		jefe_label = Label.new()
		jefe_label.position = Vector2(0, 30)
		jefe_label.size = Vector2(500, 30)
		jefe_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		jefe_label.add_theme_font_size_override("font_size", 22)
		jefe_label.add_theme_color_override("font_color", Color(1, 0.9, 0.5))
		jefe_label.add_theme_color_override("font_outline_color", Color(0.3, 0.03, 0.05))
		jefe_label.add_theme_constant_override("outline_size", 8)
		jefe_panel.add_child(jefe_label)
		jefe_barra = ProgressBar.new()
		jefe_barra.size = Vector2(500, 26)
		jefe_barra.show_percentage = false
		var fondo := StyleBoxFlat.new()
		fondo.bg_color = Color(0.15, 0.02, 0.04, 0.8)
		fondo.set_corner_radius_all(13)
		fondo.set_border_width_all(3)
		fondo.border_color = Color(1, 1, 1, 0.9)
		var relleno := StyleBoxFlat.new()
		relleno.bg_color = Color(0.86, 0.18, 0.2)
		relleno.set_corner_radius_all(13)
		jefe_barra.add_theme_stylebox_override("background", fondo)
		jefe_barra.add_theme_stylebox_override("fill", relleno)
		jefe_panel.add_child(jefe_barra)
	jefe_label.text = "☠ " + nombre + " ☠   (recoge cupones para debilitarlo)"
	jefe_barra.max_value = float(hp_max)
	jefe_barra.value = float(hp)
	jefe_panel.visible = true

func actualizar_jefe(hp: int) -> void:
	if jefe_barra:
		create_tween().tween_property(jefe_barra, "value", float(hp), 0.3)

func ocultar_jefe() -> void:
	if jefe_panel:
		jefe_panel.visible = false
