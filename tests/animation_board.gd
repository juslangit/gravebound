extends "res://scripts/game.gd"
## Draw every directional pose through the actual gameplay sprite renderer.
var mode := "attack"

func _ready() -> void:
	super._ready()
	set_process(false)
	muted = true
	camera = Vector2.ZERO

func _draw() -> void:
	draw_set_transform(Vector2.ZERO)
	draw_rect(Rect2(0, 0, 1440, 1500), Color("273337"))
	text_at(Vector2(30, 34), "GRAVEBOUND / " + mode.to_upper() + " / ACTUAL GAME SPRITES", 20, PAPER)
	for row in range(8):
		for frame in range(8):
			player = unproject(Vector2(100 + frame * 176, 200 + row * 175))
			facing = Vector2.from_angle(row * PI / 4)
			moving = mode == "run"
			move_phase = frame
			attack_time = -1 if moving else [-1.0, 0.04, 0.12, 0.20, 0.34, 0.46, 0.56, 0.68][frame]
			released = frame >= 5
			draw_ranger()
			draw_set_transform(Vector2.ZERO)
			text_at(Vector2(35 + frame * 176, 216 + row * 175), ["E", "SE", "S", "SW", "W", "NW", "N", "NE"][row] + " / " + str(frame), 12, GOLD)
