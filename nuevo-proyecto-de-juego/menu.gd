extends Control

@onready var boton_jugar: Button = $Centro/Caja/BotonJugar
@onready var boton_nivel2: Button = $Centro/Caja/BotonNivel2
@onready var boton_salir: Button = $Centro/Caja/BotonSalir

func _ready() -> void:
	get_tree().paused = false
	_crear_corredor()
	boton_jugar.pressed.connect(func(): Global.empezar_partida(0))
	boton_nivel2.pressed.connect(func(): Global.empezar_partida(1))
	boton_salir.pressed.connect(get_tree().quit)
	boton_jugar.grab_focus()

# Personaje corriendo en el menú (para ver las animaciones)
func _crear_corredor() -> void:
	var tex: Texture2D = load("res://arte/jugador_sheet.png")
	var sf := SpriteFrames.new()
	sf.remove_animation("default")
	sf.add_animation("run")
	sf.set_animation_speed("run", 13.0)
	for i in range(8):
		var at := AtlasTexture.new()
		at.atlas = tex
		at.region = Rect2(i * 176, 208, 176, 208)
		sf.add_frame("run", at)
	var s := AnimatedSprite2D.new()
	s.sprite_frames = sf
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	s.position = Vector2(180, 520 - 96)
	s.scale = Vector2(1.15, 1.15)
	s.position.y = 520 - 96 * 1.15
	add_child(s)
	s.play("run")
