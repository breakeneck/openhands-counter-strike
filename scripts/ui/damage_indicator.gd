extends Control
# Draws an arc segment pointing toward damage source (rotation set by HUD).

func _draw() -> void:
	var c := size / 2.0
	var r := minf(c.x, c.y) * 0.55
	draw_set_transform(c, rotation, Vector2.ONE)
	for i in 7:
		var a := deg_to_rad(-45.0 + i * 15.0)
		var p := Vector2(cos(a - PI / 2), sin(a - PI / 2)) * r
		draw_circle(p, 3.0, Color(0.9, 0.2, 0.1, 1.0 - abs(i - 3) * 0.15))
