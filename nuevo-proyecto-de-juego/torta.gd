extends Area2D

@export var escena_ruleta: PackedScene = preload("res://ruleta_powerup.tscn")

func _ready() -> void:
	# La torta flota suavemente para que se note que es un premio
	var s := get_node_or_null("Sprite2D")
	if s:
		var base: float = s.position.y
		var t := create_tween().set_loops()
		t.tween_property(s, "position:y", base - 8.0, 0.5).set_trans(Tween.TRANS_SINE)
		t.tween_property(s, "position:y", base + 8.0, 0.5).set_trans(Tween.TRANS_SINE)

func _on_body_entered(body: Node2D) -> void:
	if body.name == "Jugador" or body is CharacterBody2D:
		# Instanciamos la ruleta en la escena principal
		if escena_ruleta:
			var ruleta = escena_ruleta.instantiate()
			get_tree().current_scene.add_child(ruleta)
		
		# Eliminamos la torta del mapa
		queue_free()
