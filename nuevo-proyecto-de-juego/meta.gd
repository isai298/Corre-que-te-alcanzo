extends Area2D
# Cupón Dorado: al tocarlo se termina el nivel con victoria.

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	# Pequeño brillo para que se note
	var t := create_tween().set_loops()
	t.tween_property(self, "modulate", Color(1.4, 1.3, 0.8), 0.6)
	t.tween_property(self, "modulate", Color(1, 1, 1), 0.6)

func _on_body_entered(cuerpo: Node2D) -> void:
	if cuerpo is CharacterBody2D and cuerpo.is_in_group("jugador"):
		set_deferred("monitoring", false)
		Global.terminar(true)
