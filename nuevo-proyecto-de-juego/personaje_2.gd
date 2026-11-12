extends CharacterBody2D

const SPEED = 300.0
const JUMP_VELOCITY = -550.0  # Salto más rápido y alto
const AIR_SPEED = 350.0       # Mayor velocidad horizontal al saltar para avanzar más

@onready var sprite = $Movimientos

func _physics_process(delta: float) -> void:
	# 1. Aplicar gravedad si está en el aire
	if not is_on_floor():
		velocity += get_gravity() * delta

	# 2. Salto (Flecha Arriba o Espacio/Enter)
	if (Input.is_action_just_pressed("ui_up") or Input.is_action_just_pressed("ui_accept")) and is_on_floor():
		velocity.y = JUMP_VELOCITY

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
		# Estado: CAMINANDO (Suelo + Movimiento horizontal)
		velocity.x = direction * SPEED
		sprite.flip_h = direction < 0
		sprite.play("Caminando")

	else:
		# Estado: QUIETO / ESTÁTICO (Suelo sin pulsar teclas)
		velocity.x = move_toward(velocity.x, 0, SPEED)
		sprite.play("Estatico")

	# 5. Ejecutar movimiento físico
	move_and_slide()
