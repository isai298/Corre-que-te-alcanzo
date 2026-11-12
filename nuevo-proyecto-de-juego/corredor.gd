extends CharacterBody2D
# Corredor automático estilo Banana Kong.
#   ↑ / Espacio : saltar (otra vez en el aire = doble salto; mantén pulsado para planear)
#   ↓           : deslizarte (para pasar bajo letreros) / caer rápido en el aire
#   ← / →       : frenar / acelerar un poco

# --- Nombres heredados (la ruleta de power ups los usa) ---
var SPEED: float = 430.0          # velocidad base
var RUN_SPEED: float = 640.0      # velocidad máxima
var JUMP_VELOCITY: float = -820.0

@export var aceleracion: float = 5.0         # cuánto sube la velocidad por segundo
@export var gravedad_extra: float = 1.7
@export var tiempo_coyote: float = 0.1
@export var tiempo_buffer: float = 0.12
@export var duracion_deslizar: float = 0.7
@export var limite_caida: float = 900.0
@export var suelo_y: float = 520.0
@export var tiempo_invulnerable: float = 1.6
@export var retraso_arranque: float = 1.0

const FW := 176
const FH := 208
const ANCHO := 64.0
const ALTO := 168.0
const ALTO_DESLIZAR := 84.0

# nombre: [fila, columna, cuadros, fps, repetir]
const ANIMS := {
	"idle": [0, 0, 8, 9.0, true],
	"run": [1, 0, 10, 15.0, true],
	"jump": [2, 0, 2, 8.0, false],
	"fall": [2, 2, 2, 8.0, true],
	"slide": [2, 4, 2, 10.0, true],
	"hurt": [2, 6, 2, 8.0, true],
}

var default_speed: float = 430.0
var default_run_speed: float = 640.0
var default_jump: float = -820.0
var default_scale: Vector2 = Vector2.ONE
var powerup_token: int = 0
var gigante: bool = false
var arrasa: bool = false      # gigante o turbo: rompe obstáculos y arrolla enemigos
var escudo: bool = false
var iman: bool = false
var turbo: bool = false
var t_estela: float = 0.0
var escudo_nodo: Node2D

var activo: bool = true
var muerto: bool = false
var invulnerable: bool = false
var aturdido: float = 0.0
var hurt_t: float = 0.0
var tiempo_jugando: float = 0.0
var coyote: float = 0.0
var buffer: float = 0.0
var saltos_restantes: int = 2
var corte_salto: bool = false
var planeo: float = 0.0
var deslizando: bool = false
var t_deslizar: float = 0.0
var buffer_desl: float = 0.0
var era_suelo: bool = true
var ultimo_suelo_x: float = 0.0
var anim_actual: String = ""
var forma_rect: RectangleShape2D

@onready var sprite: AnimatedSprite2D = $Movimientos
@onready var forma: CollisionShape2D = $CollisionShape2D
@onready var camara: Camera2D = $Camera2D
@onready var polvo: CPUParticles2D = $Polvo
@onready var polvo_salto: CPUParticles2D = $PolvoSalto

func _ready() -> void:
	add_to_group("jugador")
	collision_layer = 2
	collision_mask = 1
	default_speed = SPEED
	default_run_speed = RUN_SPEED
	default_jump = JUMP_VELOCITY
	default_scale = scale
	forma_rect = RectangleShape2D.new()
	forma_rect.size = Vector2(ANCHO, ALTO)
	forma.shape = forma_rect
	_crear_animaciones()
	_config_polvo(polvo, 10, false)
	_config_polvo(polvo_salto, 14, true)
	camara.top_level = true
	camara.position_smoothing_enabled = true
	camara.position_smoothing_speed = 14.0
	camara.offset = Vector2(250, -30)
	camara.limit_bottom = 648
	camara.limit_top = -500
	camara.limit_left = 0
	ultimo_suelo_x = global_position.x
	camara.global_position = global_position
	camara.reset_smoothing()
	sprite.play("idle")
	anim_actual = "idle"

func _crear_animaciones() -> void:
	var tex: Texture2D = load("res://arte/jugador_sheet.png")
	var sf := SpriteFrames.new()
	sf.remove_animation("default")
	for nombre in ANIMS:
		var d: Array = ANIMS[nombre]
		sf.add_animation(nombre)
		sf.set_animation_speed(nombre, d[3])
		sf.set_animation_loop(nombre, d[4])
		for i in range(d[2]):
			var at := AtlasTexture.new()
			at.atlas = tex
			at.region = Rect2((d[1] + i) * FW, d[0] * FH, FW, FH)
			sf.add_frame(nombre, at)
	sprite.sprite_frames = sf
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

func _config_polvo(p: CPUParticles2D, cantidad: int, una_vez: bool) -> void:
	p.amount = cantidad
	p.lifetime = 0.45
	p.one_shot = una_vez
	p.explosiveness = 0.9 if una_vez else 0.0
	p.direction = Vector2(-1, -0.5)
	p.spread = 35.0
	p.gravity = Vector2(0, 160)
	p.initial_velocity_min = 60.0
	p.initial_velocity_max = 170.0
	p.scale_amount_min = 4.0
	p.scale_amount_max = 9.0
	p.color = Color(0.9, 0.86, 0.74, 0.9)
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 0.9))
	g.set_color(1, Color(1, 1, 1, 0.0))
	p.color_ramp = g
	p.position = Vector2(-26, 82)
	p.emitting = false

func _physics_process(delta: float) -> void:
	if muerto or not activo:
		return
	tiempo_jugando += delta
	hurt_t = maxf(hurt_t - delta, 0.0)
	var en_suelo := is_on_floor()

	# ---- gravedad y estado de suelo ----
	if en_suelo:
		coyote = tiempo_coyote
		saltos_restantes = 2
		planeo = 0.9
		corte_salto = false
		if global_position.y >= suelo_y - 100.0 * scale.y:
			ultimo_suelo_x = global_position.x
	else:
		velocity.y += get_gravity().y * gravedad_extra * delta
		coyote -= delta
		if coyote <= 0.0 and saltos_restantes == 2:
			saltos_restantes = 1

	# ---- salto ----
	buffer -= delta
	if Input.is_action_just_pressed("ui_up") or Input.is_action_just_pressed("ui_accept"):
		buffer = tiempo_buffer
	var mantiene := Input.is_action_pressed("ui_up") or Input.is_action_pressed("ui_accept")
	if buffer > 0.0 and saltos_restantes > 0:
		_saltar()
		buffer = 0.0
	if not en_suelo and not mantiene and velocity.y < JUMP_VELOCITY * 0.45 and not corte_salto:
		velocity.y *= 0.5          # salto corto si sueltas la tecla
		corte_salto = true
	# planeo: mantén pulsado después del doble salto
	if not en_suelo and mantiene and velocity.y > 140.0 and saltos_restantes == 0 and planeo > 0.0:
		velocity.y = move_toward(velocity.y, 140.0, 2600.0 * delta)
		planeo -= delta
	# caída rápida (y deslizamiento "encolado" para cuando aterrices)
	buffer_desl -= delta
	if not en_suelo and Input.is_action_just_pressed("ui_down"):
		velocity.y = maxf(velocity.y, 950.0)
		buffer_desl = 0.3

	# ---- deslizar ----
	var pide_desl := Input.is_action_pressed("ui_down")
	if en_suelo and not deslizando and aturdido <= 0.0 and (Input.is_action_just_pressed("ui_down") or buffer_desl > 0.0):
		buffer_desl = 0.0
		_empezar_deslizar()
	if deslizando:
		t_deslizar -= delta
		var bloqueado := test_move(global_transform, Vector2(0, -(ALTO - ALTO_DESLIZAR) * scale.y))
		if not bloqueado and ((t_deslizar <= 0.0 and not pide_desl) or not en_suelo):
			_terminar_deslizar()

	# ---- velocidad horizontal (corre solo) ----
	var dir := Input.get_axis("ui_left", "ui_right")
	var objetivo := clampf(SPEED + tiempo_jugando * aceleracion, SPEED, RUN_SPEED)
	objetivo *= 1.0 + 0.22 * dir
	if deslizando:
		objetivo *= 1.12
	if tiempo_jugando < retraso_arranque:
		objetivo = 0.0
	if aturdido > 0.0:
		objetivo *= 0.45
		aturdido -= delta
	velocity.x = move_toward(velocity.x, objetivo, 1800.0 * delta)

	var vy_antes := velocity.y
	move_and_slide()

	var ahora_suelo := is_on_floor()
	if ahora_suelo and not era_suelo:
		_al_aterrizar(vy_antes)
	era_suelo = ahora_suelo

	polvo.emitting = ahora_suelo and velocity.x > 200.0
	if iman:
		for m in get_tree().get_nodes_in_group("monedas"):
			if m.global_position.distance_to(global_position) < 520.0:
				m.global_position = m.global_position.move_toward(global_position + Vector2(0, -40), 1200.0 * delta)
	t_estela -= delta
	if (turbo or velocity.x > 780.0) and t_estela <= 0.0:
		t_estela = 0.05
		_crear_estela()
	polvo.position = Vector2(-26, 82 * 1.0)
	camara.global_position = global_position
	_animar()

	if global_position.y > limite_caida:
		caer()

# ----------------------------------------------------------------------
func _saltar() -> void:
	var doble := saltos_restantes == 1
	if deslizando:
		_terminar_deslizar()
	velocity.y = JUMP_VELOCITY * (0.88 if doble else 1.0)
	saltos_restantes -= 1
	coyote = 0.0
	corte_salto = false
	polvo_salto.restart()
	polvo_salto.emitting = true
	if doble:
		# voltereta en el aire
		sprite.rotation = 0.0
		var t := create_tween()
		t.tween_property(sprite, "rotation", TAU, 0.38).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		t.tween_callback(func(): sprite.rotation = 0.0)
	else:
		sprite.scale = Vector2(0.82, 1.22)
		create_tween().tween_property(sprite, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _al_aterrizar(vy: float) -> void:
	if vy > 350.0:
		sprite.scale = Vector2(1.25, 0.78)
		create_tween().tween_property(sprite, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		polvo_salto.restart()
		polvo_salto.emitting = true

func _empezar_deslizar() -> void:
	deslizando = true
	t_deslizar = duracion_deslizar
	forma_rect.size = Vector2(ANCHO * 1.2, ALTO_DESLIZAR)
	forma.position.y = (ALTO - ALTO_DESLIZAR) / 2.0

func _terminar_deslizar() -> void:
	deslizando = false
	forma_rect.size = Vector2(ANCHO, ALTO)
	forma.position.y = 0.0

func _animar() -> void:
	var nombre := "idle"
	if hurt_t > 0.0:
		nombre = "hurt"
	elif deslizando:
		nombre = "slide"
	elif not is_on_floor():
		nombre = "jump" if velocity.y < 0.0 else "fall"
	elif velocity.x > 30.0:
		nombre = "run"
	if nombre != anim_actual:
		anim_actual = nombre
		sprite.play(nombre)
	if nombre == "run":
		sprite.speed_scale = clampf(velocity.x / 430.0, 0.8, 1.9)
	elif nombre == "jump":
		sprite.speed_scale = 0.0
		sprite.frame = 0 if velocity.y < -300.0 else 1
	else:
		sprite.speed_scale = 1.0

# ----------------------------------------------------------------------
# Vidas, daño y caídas
# ----------------------------------------------------------------------
func pies_y() -> float:
	return forma.global_position.y + forma_rect.size.y * 0.5 * absf(global_scale.y)

func rebotar() -> void:   # al aplastar a un enemigo
	velocity.y = JUMP_VELOCITY * 0.7
	saltos_restantes = maxi(saltos_restantes, 1)

func recibir_dano(_desde_x: float = 0.0) -> void:
	if invulnerable or muerto or arrasa or Global.modo_prueba:
		return
	if escudo:
		_quitar_escudo()
		invulnerable = true
		_sacudir_camara()
		await get_tree().create_timer(0.9).timeout
		invulnerable = false
		return
	Global.perder_vida()
	hurt_t = 0.55
	if Global.vidas <= 0:
		muerto = true
		velocity = Vector2.ZERO
		sprite.play("hurt")
		return
	aturdido = 0.9
	velocity.y = -420.0
	_hacer_invulnerable()
	_sacudir_camara()

func caer() -> void:
	if Global.modo_prueba == false:
		Global.perder_vida()
		if Global.vidas <= 0:
			muerto = true
			return
	# Reaparece un poco antes del hueco
	var nueva_x := maxf(ultimo_suelo_x - 300.0, 300.0)
	global_position = Vector2(nueva_x, suelo_y - 84.0 * scale.y - 6.0)
	velocity = Vector2(0, 0)
	aturdido = 0.0
	camara.global_position = global_position
	camara.reset_smoothing()
	# la Inflación se aleja otra vez para que el castigo no sea doble
	var nivel := get_parent()
	if nivel and "perseguidor" in nivel and nivel.perseguidor:
		nivel.perseguidor.global_position.x = global_position.x - 1000.0
	_hacer_invulnerable()

func _hacer_invulnerable() -> void:
	invulnerable = true
	var parpadeo := create_tween().set_loops(int(tiempo_invulnerable / 0.2))
	parpadeo.tween_property(sprite, "modulate:a", 0.25, 0.1)
	parpadeo.tween_property(sprite, "modulate:a", 1.0, 0.1)
	await parpadeo.finished
	sprite.modulate.a = 1.0
	invulnerable = false

func _sacudir_camara() -> void:
	var base := Vector2(250, -30)
	var t := create_tween()
	for i in range(6):
		t.tween_property(camara, "offset", base + Vector2(randf_range(-14, 14), randf_range(-10, 10)), 0.03)
	t.tween_property(camara, "offset", base, 0.04)

# ----------------------------------------------------------------------
# Power ups (la ruleta ya no pausa el juego)
# ----------------------------------------------------------------------
const DURACIONES := {"Imán": 12.0, "Escudo": 15.0, "Turbo": 6.0, "Gigante": 10.0, "Súper Salto": 12.0}

func _hud() -> Node:
	return get_parent().get_node_or_null("HUD")

func _cambiar_escala(nueva: Vector2) -> void:
	var pies := global_position.y + 84.0 * scale.y
	scale = nueva
	global_position.y = pies - 84.0 * scale.y

func aplicar_habilidad(habilidad: String) -> void:
	restaurar_valores()
	powerup_token += 1
	var current_token := powerup_token
	var dur: float = DURACIONES.get(habilidad, 10.0)
	match habilidad:
		"Imán":
			iman = true
		"Escudo":
			escudo = true
			_poner_escudo()
		"Turbo":
			turbo = true
			arrasa = true
			SPEED = default_speed * 1.7
			RUN_SPEED = default_run_speed * 1.7
			sprite.self_modulate = Color(0.7, 0.9, 1.0)
		"Gigante":
			_cambiar_escala(Vector2(1.5, 1.5))
			gigante = true
			arrasa = true
			sprite.self_modulate = Color(1.0, 0.92, 0.6)
		"Súper Salto":
			JUMP_VELOCITY = default_jump * 1.22
	var h := _hud()
	if h and h.has_method("mostrar_poder"):
		h.mostrar_poder(habilidad, dur)
	await get_tree().create_timer(dur).timeout
	if powerup_token != current_token:
		return
	restaurar_valores()

func restaurar_valores() -> void:
	SPEED = default_speed
	RUN_SPEED = default_run_speed
	JUMP_VELOCITY = default_jump
	if scale != default_scale:
		_cambiar_escala(default_scale)
	gigante = false
	arrasa = false
	turbo = false
	iman = false
	if escudo:
		_quitar_escudo()
	sprite.self_modulate = Color(1, 1, 1)
	var h := _hud()
	if h and h.has_method("ocultar_poder"):
		h.ocultar_poder()

func _poner_escudo() -> void:
	if escudo_nodo == null:
		escudo_nodo = Node2D.new()
		escudo_nodo.set_script(load("res://escudo_visual.gd"))
		escudo_nodo.z_index = 6
		add_child(escudo_nodo)

func _quitar_escudo() -> void:
	escudo = false
	if escudo_nodo:
		escudo_nodo.queue_free()
		escudo_nodo = null
	var h := _hud()
	if h and h.has_method("ocultar_poder"):
		h.ocultar_poder()

func _crear_estela() -> void:
	var tex: Texture2D = sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame)
	if tex == null:
		return
	var g := Sprite2D.new()
	g.texture = tex
	g.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	g.z_index = 4
	get_parent().add_child(g)
	g.global_position = sprite.global_position
	g.global_scale = sprite.global_scale
	g.modulate = Color(0.5, 0.85, 1.0, 0.55)
	var t := g.create_tween()
	t.tween_property(g, "modulate:a", 0.0, 0.3)
	t.tween_callback(g.queue_free)
