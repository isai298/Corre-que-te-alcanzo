extends Area2D

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var collision: CollisionShape2D = $CollisionShape2D

func _ready() -> void:
	add_to_group("monedas")
	if sprite:
		sprite.visible = true
		sprite.play("default")

func _on_body_entered(body: Node2D) -> void:
	# Solo se recolecta si el cuerpo pertenece al grupo "jugador" o se llama "Jugador"
	if body.is_in_group("jugador") or body.name == "Jugador":
		# Suma la moneda; el HUD se actualiza solo con la señal de Global
		Global.sumar_moneda(1)

		# Ocultar sprite y desactivar colisión
		if sprite:
			sprite.visible = false
		if collision:
			collision.set_deferred("disabled", true)

		# Reproducir sonido de recolección si existe
		if has_node("AudioStreamPlayer2D"):
			var audio = $AudioStreamPlayer2D
			if audio.stream != null:
				audio.play()
				await audio.finished

		queue_free()
