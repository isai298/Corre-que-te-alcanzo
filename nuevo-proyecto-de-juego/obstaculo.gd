extends Area2D
# Obstáculo que quita una vida al tocarlo. Con el power up "Gigante" se rompe.

var roto: bool = false

func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	set_physics_process(false)
	body_entered.connect(_al_entrar)
	body_exited.connect(_al_salir)

func _al_entrar(c: Node) -> void:
	if c is CharacterBody2D and c.is_in_group("jugador"):
		set_physics_process(true)
		_golpear(c)

func _al_salir(c: Node) -> void:
	if c is CharacterBody2D and c.is_in_group("jugador"):
		set_physics_process(false)

# mientras siga tocándolo, vuelve a intentar al terminar la invulnerabilidad
func _physics_process(_delta: float) -> void:
	for c in get_overlapping_bodies():
		if c is CharacterBody2D and c.is_in_group("jugador"):
			_golpear(c)
			break

func _golpear(c) -> void:
	if roto or c.muerto:
		return
	if c.arrasa:
		_romper()
	else:
		c.recibir_dano(global_position.x)

func _romper() -> void:
	roto = true
	set_deferred("monitoring", false)
	var t := create_tween().set_parallel(true)
	t.tween_property(self, "position", position + Vector2(randf_range(150, 320), -340), 0.55)
	t.tween_property(self, "rotation", 7.0, 0.55)
	t.tween_property(self, "modulate:a", 0.0, 0.55)
	t.chain().tween_callback(queue_free)
