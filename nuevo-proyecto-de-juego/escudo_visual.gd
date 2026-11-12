extends Node2D
# Burbuja del escudo (se dibuja por código)
var t := 0.0
func _process(delta: float) -> void:
	t += delta
	queue_redraw()
func _draw() -> void:
	var r := 128.0 + sin(t * 5.0) * 4.0
	draw_circle(Vector2.ZERO, r, Color(0.45, 0.78, 1.0, 0.18))
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 48, Color(0.75, 0.92, 1.0, 0.9), 4.0)
	draw_arc(Vector2.ZERO, r - 14.0, -2.4, -1.2, 16, Color(1, 1, 1, 0.8), 5.0)
