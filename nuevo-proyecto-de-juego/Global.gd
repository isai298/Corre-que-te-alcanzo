extends Node
# Autoload "Global": guarda monedas y vidas, y avisa a la interfaz cuando cambian.

signal monedas_cambiadas(total: int)
signal vidas_cambiadas(total: int)
signal juego_terminado(victoria: bool)

const VIDAS_INICIALES := 3
const NIVELES := ["res://nivel_tec.tscn", "res://nivel_mercado.tscn"]
var nivel_idx: int = 0

# Solo para pruebas (godot -- --prueba): el jugador no pierde vidas
var modo_prueba: bool = OS.get_cmdline_user_args().has("--prueba")

var monedas: int = 0
var vidas: int = VIDAS_INICIALES
var terminado: bool = false

func sumar_moneda(cantidad: int = 1) -> void:
	monedas += cantidad
	monedas_cambiadas.emit(monedas)

func perder_vida() -> void:
	vidas = maxi(vidas - 1, 0)
	vidas_cambiadas.emit(vidas)
	if vidas <= 0:
		terminar(false)

# victoria = true cuando se agarra el Cupón Dorado, false cuando se acaban las vidas
func terminar(victoria: bool) -> void:
	if terminado:
		return
	terminado = true
	juego_terminado.emit(victoria)

func _ready() -> void:
	# Solo para pruebas: godot -- --vidas=1
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--vidas="):
			vidas = int(a.substr(8))

func _reiniciar_valores() -> void:
	monedas = 0
	vidas = VIDAS_INICIALES
	terminado = false
	get_tree().paused = false

func reiniciar_juego() -> void:
	_reiniciar_valores()
	get_tree().reload_current_scene()

func empezar_partida(idx: int = 0) -> void:
	_reiniciar_valores()
	nivel_idx = idx
	get_tree().change_scene_to_file(NIVELES[nivel_idx])

func hay_siguiente() -> bool:
	return nivel_idx < NIVELES.size() - 1

func siguiente_nivel() -> void:
	nivel_idx += 1
	terminado = false
	vidas = mini(vidas + 1, VIDAS_INICIALES)
	get_tree().paused = false
	get_tree().change_scene_to_file(NIVELES[nivel_idx])

func ir_al_menu() -> void:
	_reiniciar_valores()
	nivel_idx = 0
	get_tree().change_scene_to_file("res://menu.tscn")
