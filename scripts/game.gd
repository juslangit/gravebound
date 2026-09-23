extends Node2D
## Gravebound: one square courtyard, one ranger, two bow attacks.
## Coordinates on the floor are kept separate from the isometric screen projection.

const SIZE := 1040.0
const SPEED := 240.0
const ARROW_SPEED := 1050.0
const ATTACK_LENGTH := 0.72
const RELEASE_TIME := 0.43
const ARROW_HEIGHT := 76.0
const GOLD := Color("c9ac71")
const TEAL := Color("70dbc3")
const INK := Color("101b20")
const PAPER := Color("ede7d6")
var attack_atlas: Texture2D
var run_atlas: Texture2D
var axial_atlas: Texture2D
var walk_atlas: Texture2D
var atlas_data: Dictionary
var frame_textures: Dictionary = {}
var player := Vector2(520, 650)
var destination := player
var facing := Vector2(0, 1)
var camera := Vector2.ZERO
var elapsed := 0.0
var move_phase := 0.0
var moving := false
var attack_time := -1.0
var attack_count := 0
var released := false
var shot_direction := Vector2.RIGHT
var arrows: Array[Dictionary] = []
var sparks: Array[Dictionary] = []
var numbers: Array[Dictionary] = []
var targets: Array[Dictionary] = []
var shots_fired := 0
var arrows_fired := 0
var hits := 0
var paused := false
var cursor := Vector2.ZERO
var click_mark := Vector2.ZERO
var click_life := 0.0
var font: Font = ThemeDB.fallback_font
var heading_font: Font
var last_attack := "READY"
var sound_players: Array[AudioStreamPlayer] = []
var muted := false
var terrain: Array[Dictionary] = []
var screenshot_mode := false

func _ready() -> void:
	Engine.max_fps = 120
	attack_atlas = load("res://assets/characters/ranger_attack.png")
	axial_atlas = load("res://assets/characters/ranger_axial.png")
	walk_atlas = load("res://assets/characters/ranger_walk.png")
	atlas_data = JSON.parse_string(FileAccess.get_file_as_string("res://assets/characters/atlas.json"))
	if ResourceLoader.exists("res://assets/characters/ranger_run.png"):
		run_atlas = load("res://assets/characters/ranger_run.png")
	for entry in [["attack", attack_atlas], ["run", run_atlas], ["axial", axial_atlas], ["walk", walk_atlas]]:
		var source_image: Image = entry[1].get_image()
		source_image.convert(Image.FORMAT_RGBA8)
		var frames: Array[Texture2D] = []
		for info in atlas_data[entry[0]]:
			var r: Array = info.rect
			var cropped := Image.create(r[2], r[3], false, Image.FORMAT_RGBA8)
			for span in info.spans:
				cropped.blit_rect(source_image, Rect2i(r[0] + span[1], r[1] + span[0], span[2], 1), Vector2i(span[1], span[0]))
			frames.append(ImageTexture.create_from_image(cropped))
		frame_textures[entry[0]] = frames
	if ResourceLoader.exists("res://assets/heading.ttf"):
		heading_font = load("res://assets/heading.ttf")
	else:
		heading_font = font
	reset_targets()
	camera = project(player) - Vector2(720, 530)
	var rng := RandomNumberGenerator.new()
	rng.seed = 137
	for x in range(13):
		for y in range(13):
			terrain.append({"p": Vector2(x, y) * 80, "shade": rng.randf_range(-0.018, 0.018), "crack": rng.randf() < 0.23})
	for i in range(10):
		var audio := AudioStreamPlayer.new()
		add_child(audio)
		sound_players.append(audio)
	queue_redraw()

func reset_targets() -> void:
	attack_time = -1.0
	attack_count = 0
	released = false
	destination = player
	moving = false
	last_attack = "READY"
	targets.clear()
	for p in [Vector2(270, 250), Vector2(520, 210), Vector2(770, 250), Vector2(800, 510), Vector2(250, 500)]:
		targets.append({"p": p, "hp": 100, "flash": 0.0, "reset": 0.0, "hits": 0})
	hits = 0
	shots_fired = 0
	arrows_fired = 0
	arrows.clear()
	sparks.clear()
	numbers.clear()

func project(p: Vector2) -> Vector2:
	return Vector2((p.x - p.y) * 0.8, (p.x + p.y) * 0.42)

func unproject(p: Vector2) -> Vector2:
	return Vector2(p.x / 1.6 + p.y / 0.84, p.y / 0.84 - p.x / 1.6)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			paused = not paused
		if event.keycode == KEY_M:
			muted = not muted
		if event.keycode == KEY_R:
			reset_targets()
	if paused:
		return
	if event is InputEventMouseButton and event.pressed:
		if event.position.y > 785 or event.position.y < 90:
			return
		var aim := unproject(event.position + camera)
		var shot_aim := unproject(event.position + camera + Vector2(0, ARROW_HEIGHT))
		if event.button_index == MOUSE_BUTTON_RIGHT:
			start_attack(5, shot_aim)
		elif event.button_index == MOUSE_BUTTON_LEFT:
			var target_clicked := false
			for target in targets:
				var target_screen: Vector2 = project(target.p) - camera - Vector2(0, 71)
				if event.position.distance_to(target_screen) < 38:
					start_attack(1, target.p)
					target_clicked = true
					break
			if not target_clicked:
				if event.shift_pressed:
					start_attack(1, shot_aim)
				else:
					destination = aim.clamp(Vector2(42, 42), Vector2(SIZE - 42, SIZE - 42))
					click_mark = destination
					click_life = 0.8

func start_attack(count: int, aim: Vector2) -> bool:
	if attack_time >= 0 or paused:
		return false
	var delta := aim - player
	if delta.length() < 1:
		return false
	shot_direction = delta.normalized()
	facing = project(shot_direction).normalized()
	destination = player
	moving = false
	attack_count = count
	attack_time = 0.0
	released = false
	last_attack = "SINGLE SHOT" if count == 1 else "FIVEFOLD VOLLEY"
	play_sound("draw", -12)
	return true

func _process(dt: float) -> void:
	cursor = get_global_mouse_position()
	if not paused:
		tick(minf(dt, 0.05))
	queue_redraw()

func tick(dt: float) -> void:
	elapsed += dt
	click_life = maxf(0, click_life - dt)
	if attack_time >= 0:
		attack_time += dt
		if attack_time >= RELEASE_TIME and not released:
			release_arrows()
		if attack_time >= ATTACK_LENGTH:
			attack_time = -1.0
	else:
		var distance := player.distance_to(destination)
		moving = distance > 3
		if moving:
			var direction := player.direction_to(destination)
			var next := player.move_toward(destination, SPEED * dt)
			for target in targets:
				if next.distance_to(target.p) < 38:
					var outward: Vector2 = target.p.direction_to(player)
					var tangent := outward.orthogonal()
					if tangent.dot(direction) < -0.01:
						tangent = -tangent
					next = player + tangent * SPEED * dt
					if next.distance_to(target.p) < 38:
						next = target.p + target.p.direction_to(next) * 38
			player = next.clamp(Vector2(42, 42), Vector2(SIZE - 42, SIZE - 42))
			facing = project(direction).normalized()
			move_phase += dt * 8
			if distance < 6:
				destination = player
		else:
			move_phase = 0
	camera = camera.lerp(project(player) - Vector2(720, 530), 1.0 - exp(-dt * 6))
	for target in targets:
		target.flash = maxf(0, target.flash - dt)
		if target.hp <= 0:
			target.reset -= dt
			if target.reset <= 0:
				target.hp = 100
	for i in range(arrows.size() - 1, -1, -1):
		var a: Dictionary = arrows[i]
		var previous: Vector2 = a.p
		var arrow_dt := dt
		if a.has("first_step"):
			arrow_dt = minf(dt, a.first_step)
			a.erase("first_step")
		a.p += a.v * arrow_dt
		a.life -= arrow_dt
		var collided := false
		for target in targets:
			if target.hp <= 0:
				continue
			var closest := Geometry2D.get_closest_point_to_segment(target.p, previous, a.p)
			if closest.distance_to(target.p) < 28:
				target.hp = maxi(0, target.hp - a.damage)
				target.flash = 0.18
				target.hits += 1
				hits += 1
				if target.hp == 0:
					target.reset = 2.5
				numbers.append({"p": project(target.p) - Vector2(0, 175), "life": 0.85, "value": str(a.damage)})
				for j in range(7):
					sparks.append({"p": project(a.p) - Vector2(0, ARROW_HEIGHT), "v": Vector2.from_angle(j * TAU / 7) * (45 + j * 9), "life": 0.30})
				play_sound("hit", -15)
				collided = true
				break
		if collided or a.life <= 0 or a.p.x < 10 or a.p.y < 10 or a.p.x > SIZE - 10 or a.p.y > SIZE - 10:
			arrows.remove_at(i)
	for i in range(sparks.size() - 1, -1, -1):
		sparks[i].p += sparks[i].v * dt
		sparks[i].life -= dt
		if sparks[i].life <= 0:
			sparks.remove_at(i)
	for i in range(numbers.size() - 1, -1, -1):
		numbers[i].p.y -= dt * 30
		numbers[i].life -= dt
		if numbers[i].life <= 0:
			numbers.remove_at(i)

func release_arrows() -> void:
	released = true
	shots_fired += 1
	arrows_fired += attack_count
	for i in range(attack_count):
		var angle := (i - (attack_count - 1) / 2.0) * deg_to_rad(8)
		var direction := shot_direction.rotated(angle)
		arrows.append({"p": player + direction * 30, "v": direction * ARROW_SPEED, "life": 1.4, "damage": 25 if attack_count == 1 else 15, "first_step": maxf(0, attack_time - RELEASE_TIME)})
	play_sound("shot", -9 if attack_count == 1 else -6)

func play_sound(sound_name: String, db: float) -> void:
	if muted:
		return
	var path := "res://assets/audio/" + sound_name + ".wav"
	if not ResourceLoader.exists(path):
		return
	for voice in sound_players:
		if not voice.playing:
			voice.stream = load(path)
			voice.volume_db = db
			voice.play()
			break

func polygon(points: Array, color: Color) -> void:
	draw_colored_polygon(PackedVector2Array(points), color)

func diamond(p: Vector2, radius: float, color: Color) -> void:
	polygon([p + Vector2(-radius, 0), p + Vector2(0, -radius * 0.525), p + Vector2(radius, 0), p + Vector2(0, radius * 0.525)], color)

func text_at(p: Vector2, text: String, size: int, color: Color = PAPER, use_heading := false) -> void:
	draw_string(heading_font if use_heading else font, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

func _draw() -> void:
	draw_set_transform(-camera)
	draw_ground()
	if click_life > 0:
		var p := project(click_mark)
		draw_arc(p, 14 + (0.8 - click_life) * 10, 0, TAU, 32, Color(0.44, 0.86, 0.76, click_life), 1.5, true)
		for d in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
			draw_line(p + d * 4, p + d * 9, TEAL, 1, true)
	var entities: Array[Dictionary] = []
	entities.append({"kind": "player", "p": player})
	for target in targets:
		entities.append({"kind": "target", "p": target.p, "data": target})
	entities.sort_custom(func(a, b): return project(a.p).y < project(b.p).y)
	for entity in entities:
		if entity.kind == "player":
			draw_ranger()
		else:
			draw_target(entity.data)
	for a in arrows:
		var p := project(a.p) - Vector2(0, ARROW_HEIGHT)
		var direction := project(a.v).normalized()
		draw_line(p - direction * 35, p - direction * 15, Color(0.32, 0.92, 0.76, 0.12), 5, true)
		draw_line(p - direction * 23, p, GOLD, 2, true)
		draw_line(p - direction * 21, p - direction * 15, PAPER, 4, true)
		polygon([p + direction * 5, p - direction * 3 + direction.orthogonal() * 3, p - direction * 3 - direction.orthogonal() * 3], TEAL)
	for spark in sparks:
		draw_circle(spark.p, 2, Color(0.65, 0.98, 0.8, spark.life / 0.3))
	for number in numbers:
		text_at(number.p, number.value, 25, Color(0.93, 0.86, 0.65, minf(1, number.life * 3)))
	draw_foreground()
	draw_set_transform(Vector2.ZERO)
	draw_hud()

func draw_ground() -> void:
	var corners := [project(Vector2.ZERO), project(Vector2(SIZE, 0)), project(Vector2(SIZE, SIZE)), project(Vector2(0, SIZE))]
	polygon([corners[0] + Vector2(0, 20), corners[1] + Vector2(0, 20), corners[2] + Vector2(0, 20), corners[3] + Vector2(0, 20)], Color("080f12"))
	polygon(corners, Color("344344"))
	for tile in terrain:
		var p: Vector2 = tile.p
		var shade: float = tile.shade
		var color := Color(0.16 + shade, 0.205 + shade, 0.205 + shade)
		polygon([project(p + Vector2(2, 2)), project(p + Vector2(78, 2)), project(p + Vector2(78, 78)), project(p + Vector2(2, 78))], color)
		draw_line(project(p + Vector2(3, 77)), project(p + Vector2(77, 77)), Color(0.27, 0.32, 0.31, 0.22), 1)
		if tile.crack:
			var c := project(p + Vector2(18, 29))
			draw_polyline(PackedVector2Array([c, c + Vector2(11, 4), c + Vector2(14, 13), c + Vector2(30, 18)]), Color("172426"), 1, true)
	# The circular ward is set into a modern paved courtyard.
	var center := project(Vector2(520, 520))
	for radius in [118.0, 126.0, 160.0]:
		var line := PackedVector2Array()
		for i in range(97):
			line.append(center + Vector2(cos(i * TAU / 96) * radius, sin(i * TAU / 96) * radius * 0.525))
		draw_polyline(line, Color(0.49, 0.47, 0.32, 0.4), 1.4, true)
	for i in range(12):
		var angle := i * TAU / 12
		var p := center + Vector2(cos(angle) * 143, sin(angle) * 143 * 0.525)
		diamond(p, 4, Color("778579"))
	diamond(center, 36, Color("263b3a"))
	diamond(center, 24, Color("4b6154"))
	diamond(center, 18, Color("263b3a"))
	# Boundary coping, bronze conduit, and evenly spaced ward lamps.
	for i in range(4):
		draw_line(corners[i], corners[(i + 1) % 4], Color("52625b"), 9, true)
		draw_line(corners[i] + Vector2(0, -2), corners[(i + 1) % 4] + Vector2(0, -2), Color("8c8a68"), 1, true)
	for p in [Vector2(55, 55), Vector2(520, 30), Vector2(985, 55), Vector2(30, 520), Vector2(1010, 520)]:
		draw_lamp(project(p))
	# Moss rooted in the outside paving seams, deterministic positions.
	for i in range(90):
		var v := fmod(i * 117.3, SIZE - 80) + 40
		var p := project(Vector2(v, 24 + fmod(i * 7, 22)) if i % 2 == 0 else Vector2(24 + fmod(i * 7, 22), v))
		draw_line(p, p + Vector2(sin(i) * 5, -5 - i % 4), Color("53694d"), 1, true)

func draw_lamp(p: Vector2) -> void:
	diamond(p, 18, Color("111c1e"))
	polygon([p + Vector2(-8, 0), p + Vector2(-8, -57), p + Vector2(0, -61), p + Vector2(8, -57), p + Vector2(8, 0)], Color("293739"))
	draw_line(p + Vector2(2, -5), p + Vector2(2, -49), GOLD.darkened(0.5), 2)
	for r in range(4, 0, -1):
		draw_circle(p + Vector2(0, -58), r * 8, Color(0.3, 0.95, 0.7, 0.012 * (5 - r)))
	polygon([p + Vector2(-5, -54), p + Vector2(-5, -65), p + Vector2(5, -65), p + Vector2(5, -54)], TEAL)

func draw_foreground() -> void:
	for p in [Vector2(55, 985), Vector2(520, 1010), Vector2(985, 985)]:
		draw_lamp(project(p))

func draw_target(target: Dictionary) -> void:
	var p := project(target.p)
	var dead: bool = target.hp <= 0
	var shake: float = sin(target.flash * 90) * target.flash * 14
	p.x += shake
	draw_set_transform(-camera + p, 0, Vector2(1, 0.45))
	draw_circle(Vector2.ZERO, 30, Color(0, 0, 0, 0.3))
	draw_set_transform(-camera + p, 0, Vector2(1.15, 1.45))
	p = Vector2.ZERO
	diamond(p, 27, Color("15262b"))
	draw_line(p, p + Vector2(0, -60), Color("5c5140"), 8, true)
	draw_line(p + Vector2(-23, -45), p + Vector2(23, -45), GOLD.darkened(0.55), 5, true)
	var body := [p + Vector2(-20, -68), p + Vector2(20, -68), p + Vector2(15, -27), p + Vector2(-15, -27)]
	polygon(body, Color("4b5149") if dead else Color("867e65"))
	draw_polyline(PackedVector2Array([p + Vector2(-20, -68), p + Vector2(20, -68), p + Vector2(15, -27)]), GOLD.darkened(0.18), 2, true)
	for i in range(5):
		draw_line(p + Vector2(-15, -61 + i * 7), p + Vector2(15, -61 + i * 7), Color("4e5147"), 1)
	draw_circle(p + Vector2(0, -49), 13, Color("273d3d"))
	draw_arc(p + Vector2(0, -49), 11, 0, TAU, 32, GOLD, 2, true)
	draw_circle(p + Vector2(0, -49), 5, Color("51605a") if dead else TEAL)
	polygon([p + Vector2(-10, -72), p + Vector2(-9, -89), p + Vector2(7, -92), p + Vector2(12, -74)], Color("535e57"))
	draw_line(p + Vector2(-5, -81), p + Vector2(6, -81), TEAL.darkened(0.7) if dead else TEAL, 2)
	if target.flash > 0:
		polygon(body, Color(0.9, 1, 0.8, target.flash * 2.5))
	draw_rect(Rect2(p + Vector2(-29, -111), Vector2(58, 5)), Color("101a1b"))
	draw_rect(Rect2(p + Vector2(-28, -110), Vector2(56 * target.hp / 100.0, 3)), TEAL)
	if dead:
		text_at(p + Vector2(-32, -119), "RESETTING", 11, GOLD)
	draw_set_transform(-camera)

func direction_row() -> int:
	return posmod(roundi(facing.angle() / (PI / 4)), 8)

func animation_frame() -> int:
	if attack_time >= 0:
		if attack_time < 0.08: return 1
		if attack_time < 0.16: return 2
		if attack_time < 0.27: return 3
		if attack_time < RELEASE_TIME: return 4
		if attack_time < 0.51: return 5
		if attack_time < 0.61: return 6
		return 7
	if moving and run_atlas:
		return int(move_phase) % 8
	return 0

func draw_ranger() -> void:
	var p := project(player)
	draw_set_transform(-camera + p, 0, Vector2(1, 0.43))
	draw_circle(Vector2.ZERO, 22, Color(0, 0, 0, 0.34))
	draw_arc(Vector2.ZERO, 26, 0, TAU, 48, Color(0.41, 0.77, 0.67, 0.38), 1.4, true)
	draw_set_transform(-camera)
	var is_running := moving and attack_time < 0 and run_atlas != null
	var row := direction_row()
	var flip := row in [3, 4, 5]
	var source_row: int = [0, 1, 2, 1, 0, 7, 6, 7][row]
	var atlas := run_atlas if is_running else attack_atlas
	var data_name := "run" if is_running else "attack"
	var art_scale := 1.05 if is_running else 1.0
	var columns := 8
	var frame := animation_frame()
	if is_running and row != 6:
		atlas = walk_atlas
		data_name = "walk"
		source_row = [0, 1, 2, 1, 0, 3, 3, 3][row]
		columns = 4
		frame = int(move_phase) % 4
		art_scale = 0.52
	if not is_running and row in [2, 6]:
		atlas = axial_atlas
		data_name = "axial"
		source_row = 0 if row == 2 else 2
		art_scale = 0.54
	if atlas:
		var info: Dictionary = atlas_data[data_name][source_row * columns + frame]
		var r: Array = info.rect
		var source := Rect2(r[0], r[1], r[2], r[3])
		var breath := sin(elapsed * 2.8) * 0.7 if attack_time < 0 and not moving else 0.0
		var anchor := Vector2(source.size.x - info.foot_x if flip else info.foot_x, info.foot_y)
		var rect := Rect2(p - anchor * art_scale + Vector2(0, breath), source.size * art_scale)
		if flip:
			rect.size.x = -rect.size.x
		draw_texture_rect(frame_textures[data_name][source_row * columns + frame], rect, false)
	if attack_time >= 0 and not released:
		var progress := clampf(attack_time / RELEASE_TIME, 0, 1)
		draw_arc(p + Vector2(0, 10), 32, PI, PI + PI * progress, 32, TEAL, 2, true)

func draw_hud() -> void:
	# Quiet, large typography and a compact brass/charcoal combat bar.
	draw_rect(Rect2(0, 0, 1440, 90), Color(0.035, 0.055, 0.062, 0.94))
	draw_line(Vector2(32, 89), Vector2(1408, 89), Color(0.78, 0.66, 0.43, 0.25), 1)
	text_at(Vector2(38, 40), "G R A V E B O U N D", 28, PAPER, true)
	text_at(Vector2(40, 66), "RANGER PROTOTYPE  /  THE WARD COURTYARD", 13, GOLD)
	text_at(Vector2(1040, 36), "MODERN FANTASY  ·  TRAINING", 14, GOLD)
	text_at(Vector2(1088, 63), "%02d  SHOTS     %02d  HITS" % [shots_fired, hits], 17, PAPER)
	# Small arena map: the square floor is displayed as an isometric diamond.
	var map_origin := Vector2(1300, 165)
	diamond(map_origin, 71, Color(0.04, 0.08, 0.09, 0.8))
	for t in targets:
		draw_circle(map_origin + project(t.p - Vector2(520, 520)) * 0.079, 3, GOLD if t.hp > 0 else GOLD.darkened(0.6))
	draw_circle(map_origin + project(player - Vector2(520, 520)) * 0.079, 4, TEAL)
	draw_rect(Rect2(0, 789, 1440, 111), Color(0.035, 0.052, 0.058, 0.98))
	draw_line(Vector2(32, 789), Vector2(1408, 789), GOLD.darkened(0.6), 1)
	draw_circle(Vector2(77, 838), 31, Color("213735"))
	draw_arc(Vector2(77, 838), 32, 0, TAU, 64, GOLD.darkened(0.25), 1.5, true)
	text_at(Vector2(54, 845), "R", 24, TEAL, true)
	text_at(Vector2(130, 827), "THE RANGER", 19, PAPER, true)
	text_at(Vector2(130, 852), last_attack if attack_time >= 0 else "READY  ·  UNLIMITED ARROWS", 12, TEAL)
	ability(Vector2(430, 808), "01", "SINGLE SHOT", "SHIFT + LEFT CLICK", attack_count == 1 and attack_time >= 0)
	ability(Vector2(740, 808), "05", "FIVEFOLD VOLLEY", "RIGHT CLICK", attack_count == 5 and attack_time >= 0)
	text_at(Vector2(1088, 825), "LEFT CLICK  Move / target", 15, PAPER)
	text_at(Vector2(1088, 851), "R  Reset    ESC  Pause", 14, GOLD)
	text_at(Vector2(1088, 875), "M  " + ("Sound off" if muted else "Sound on"), 12, GOLD.darkened(0.15))
	text_at(Vector2(40, 762), "Click a dummy to shoot. Hold Shift to fire anywhere.", 16, Color(0.82, 0.85, 0.79, 0.9))
	if paused:
		draw_rect(Rect2(0, 90, 1440, 699), Color(0.015, 0.025, 0.03, 0.80))
		text_at(Vector2(570, 404), "PAUSED", 56, PAPER, true)
		text_at(Vector2(562, 452), "Press Escape to return", 23, GOLD)
	if cursor.y > 90 and cursor.y < 789 and not paused:
		for direction in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
			draw_line(cursor + direction * 6, cursor + direction * 11, GOLD, 1, true)

func ability(p: Vector2, count: String, title: String, control: String, active: bool) -> void:
	draw_rect(Rect2(p, Vector2(278, 69)), Color("182b2c") if active else Color("111e23"))
	draw_rect(Rect2(p, Vector2(278, 69)), TEAL.darkened(0.4) if active else GOLD.darkened(0.65), false, 1)
	text_at(p + Vector2(13, 42), count, 29, TEAL if active else GOLD, true)
	text_at(p + Vector2(65, 27), title, 17, PAPER)
	text_at(p + Vector2(65, 50), control, 12, GOLD)
	if active:
		draw_rect(Rect2(p + Vector2(0, 66), Vector2(278 * clampf(attack_time / ATTACK_LENGTH, 0, 1), 3)), TEAL)
