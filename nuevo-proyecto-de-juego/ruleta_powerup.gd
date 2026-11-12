extends CanvasLayer
# Ruleta rápida que NO pausa el juego: gira un instante en un letrero arriba y aplica el poder.

@onready var label_resultado: Label = find_child("LabelResultado", true, true)

# [nombre, peso]
const OPCIONES := [["Imán", 2.0], ["Escudo", 2.2], ["Turbo", 2.0], ["Gigante", 1.4], ["Súper Salto", 1.6]]

func _ready() -> void:
	girar_ruleta()

func _elegir() -> String:
	var suma := 0.0
	for o in OPCIONES:
		suma += o[1]
	var r := randf() * suma
	for o in OPCIONES:
		r -= o[1]
		if r <= 0.0:
			return o[0]
	return OPCIONES[0][0]

func girar_ruleta() -> void:
	for i in range(9):
		if label_resultado:
			label_resultado.text = OPCIONES.pick_random()[0]
		await get_tree().create_timer(0.07).timeout
	var habilidad := _elegir()
	if label_resultado:
		label_resultado.text = "¡" + habilidad + "!"
	var jugador = get_tree().current_scene.get_node_or_null("Jugador")
	if jugador == null:
		jugador = get_parent().get_node_or_null("Jugador")
	if jugador and jugador.has_method("aplicar_habilidad"):
		jugador.aplicar_habilidad(habilidad)
	await get_tree().create_timer(1.1).timeout
	queue_free()
