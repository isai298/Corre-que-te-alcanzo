extends CharacterBody2D

var SPEED = 300.0
var RUN_SPEED = 480.0       # Velocidad más rápida al correr
var JUMP_VELOCITY = -550.0  # Salto más rápido y alto
var AIR_SPEED = 350.0       # Mayor velocidad horizontal al saltar para avanzar más

# --- NUEVO: vidas, daño y caídas ---
@export var tiempo_coyote: float = 0.12        # permite saltar justo al salir de una plataforma
@export var limite_caida: float = 900.0        # si pasa de esta altura (global) cae al vacío
@export var tiempo_invulnerable: float = 1.5   # segundos sin recibir daño después de un golpe

var coyote: float = 0.0
var invulnerable: bool = false
var muerto: bool = false
var posicion_inicio: Vector2 = Vector2.ZERO

# Valores por defecto para restaurar después
@onready var default_speed = SPEED
@onready var default_run_speed = RUN_SPEED
@onready var default_jump = JUMP_VELOCITY
@onready var default_scale = scale

var powerup_token: int = 0  # Evita conflictos si tomas otro poder antes de tiempo

@onready var sprite = $Movimientos

func _ready() -> void:
	default_speed = SPEED
	default_run_speed = RUN_SPEED
	default_jump = JUMP_VELOCITY
	default_scale = scale
	posicion_inicio = global_position
	add_to_group("jugador")

func _physics_process(delta: float) -> void:
	if muerto:
		return

	# 1. Aplicar gravedad si está en el aire (y llevar la cuenta del "coyote time")
	if is_on_floor():
		coyote = tiempo_coyote
	else:
		velocity += get_gravity() * delta
		coyote -= delta

	# 2. Salto (Solo Flecha Arriba "ui_up" para dejar Espacio libre para Correr)
	if Input.is_action_just_pressed("ui_up") and coyote > 0.0:
		velocity.y = JUMP_VELOCITY
		coyote = 0.0

	# 3. Obtener dirección horizontal (-1 izquierda, 1 derecha, 0 quieto)
	var direction := Input.get_axis("ui_left", "ui_right")

	# 4. Control de estados y animaciones
	if not is_on_floor():
		# Estado: EN EL AIRE / SALTO
		sprite.play("Saltando")
		if direction != 0:
			velocity.x = direction * AIR_SPEED
			sprite.flip_h = direction < 0
		else:
			# Desaceleración progresiva en el aire para mantener inercia al avanzar
			velocity.x = move_toward(velocity.x, 0, SPEED * delta * 3)

	elif Input.is_action_pressed("ui_down"):
		# Estado: AGACHADO (Suelo + Flecha Abajo)
		velocity.x = move_toward(velocity.x, 0, SPEED)
		sprite.play("Agacharce")

	elif direction != 0:
		# Verificar si se mantiene presionado Espacio ("ui_accept") mientras se avanza
		if Input.is_action_pressed("ui_accept"):
			# Estado: CORRIENDO (Suelo + Movimiento + Espacio)
			velocity.x = direction * RUN_SPEED
			sprite.flip_h = direction < 0
			sprite.play("Corriendo")
		else:
			# Estado: CAMINANDO (Suelo + Movimiento normal)
			velocity.x = direction * SPEED
			sprite.flip_h = direction < 0
			sprite.play("Caminando")

	else:
		# Estado: QUIETO / ESTÁTICO (Suelo sin pulsar teclas)
		velocity.x = move_toward(velocity.x, 0, SPEED)
		sprite.play("Estatico")

	# 5. Ejecutar movimiento físico
	move_and_slide()

	# 6. NUEVO: caída al vacío
	if global_position.y > limite_caida:
		caer()

# ----------------------------------------------------------------------
# NUEVO: vidas, daño, rebote al aplastar enemigos
# ----------------------------------------------------------------------

# Y global de los pies del jugador (la usan los enemigos para saber si los aplastaste)
func pies_y() -> float:
	var forma := $CollisionShape2D.shape as RectangleShape2D
	return $CollisionShape2D.global_position.y + forma.size.y * 0.5 * absf(global_scale.y)

# Lo llama el enemigo cuando lo aplastas desde arriba
func rebotar() -> void:
	velocity.y = JUMP_VELOCITY * 0.6

# Lo llama el enemigo cuando te toca de lado
func recibir_dano(desde_x: float) -> void:
	if invulnerable or muerto:
		return
	Global.perder_vida()
	if Global.vidas <= 0:
		muerto = true
		velocity = Vector2.ZERO
		return
	var dir := signf(global_position.x - desde_x)
	if dir == 0.0:
		dir = 1.0
	velocity = Vector2(dir * 350.0, -350.0)
	_hacer_invulnerable()

func caer() -> void:
	Global.perder_vida()
	if Global.vidas <= 0:
		muerto = true
		return
	# Reaparece en el punto de inicio
	global_position = posicion_inicio
	velocity = Vector2.ZERO
	_hacer_invulnerable()

func _hacer_invulnerable() -> void:
	invulnerable = true
	var parpadeo := create_tween().set_loops(int(tiempo_invulnerable / 0.2))
	parpadeo.tween_property(sprite, "modulate:a", 0.25, 0.1)
	parpadeo.tween_property(sprite, "modulate:a", 1.0, 0.1)
	await parpadeo.finished
	sprite.modulate.a = 1.0
	invulnerable = false

# ----------------------------------------------------------------------
# Power ups (ruleta)  -- sin cambios
# ----------------------------------------------------------------------
func aplicar_habilidad(habilidad: String) -> void:
	# Restauramos valores previos antes de aplicar uno nuevo
	restaurar_valores()

	# Incrementamos el token para cancelar temporizadores anteriores en curso
	powerup_token += 1
	var current_token = powerup_token

	match habilidad:
		"Súper Velocidad":
			SPEED = 500.0
			RUN_SPEED = 700.0
			print("¡Habilidad aplicada: Súper Velocidad!")
		"Súper Salto":
			JUMP_VELOCITY = -750.0
			print("¡Habilidad aplicada: Súper Salto!")
		"Tamaño Gigante":
			scale = Vector2(1.5, 1.5)
			print("¡Habilidad aplicada: Tamaño Gigante!")
		"Tamaño Mini":
			scale = Vector2(0.6, 0.6)
			print("¡Habilidad aplicada: Tamaño Mini!")

	# Esperamos 10 segundos (puedes cambiar este número si quieres que dure más o menos)
	await get_tree().create_timer(10.0).timeout

	# Si se tomó otro poder mientras tanto, este temporizador se descarta
	if powerup_token != current_token:
		return

	restaurar_valores()
	print("¡Efecto terminado, vuelta a la normalidad!")

func restaurar_valores() -> void:
	SPEED = default_speed
	RUN_SPEED = default_run_speed
	JUMP_VELOCITY = default_jump
	scale = default_scale
