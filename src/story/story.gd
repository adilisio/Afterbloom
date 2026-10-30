extends Node
## The story: cold open, Ch.1 Good Morning, Ch.2 The Bloom, Ch.3 Shelter No. 9, Ch.4 Afterbloom, free roam.
## Each chapter is an awaitable sequence. Checkpoints: ch1, ch2, ch3b (wake in shelter), ch4 (left shelter),
## ch4b (reunited with Tuppence), free (after the ending).

const Q_MORNING := "morning"
const Q_SHELTER := "shelter9"
const Q_MAIN := "follow_music"
const Q_RIFLE := "cd_rifle"

var main: Node
var world: World
var player: Player
var hud: Hud
var dlg: Dialogue
var tup: Tuppence
var radio: PocketRadio
var _talk_busy := false
var _tea_ready_at := -999.0
var _combat := false
var _music_explore := ""
var _enemies: Array = []


func run(cp: String) -> void:
	auto = Game.shot_args.has("auto")
	hud = main.hud
	dlg = main.dialogue
	match cp:
		"ch1":
			await cold_open()
			await ch1_morning()
		"ch2":
			await ch1_setup(true)
			await ch2_bloom()
		"ch3b":
			await ch3_wake()
		"ch4":
			await ch4_setup("ch4")
			await ch4_afterbloom()
		"ch4b":
			await ch4_setup("ch4b")
			await ch4_afterbloom()
		"free":
			await ch4_setup("free")
			await free_roam()
		"test_wave":
			await ch1_setup(true)
			Game.set_flag("ch2")
			player.teleport(Vector3(-70, Layout.road_center_h(Vector2(-70, 0)) + 0.3, 1.0), 90.0)
			player.set_look(80.0, 4.0)
			_dash_events(Time.get_ticks_msec())
			var t0 := Time.get_ticks_msec()
			while true:
				await get_tree().process_frame
				_bloom_progress(float(Game.shot_args.get("wave_t", "60")) + (Time.get_ticks_msec() - t0) / 1000.0)
		"test_gun":
			await _world("after")
			world.set_time(10.0)
			Game.add_item("pistol", 1, true)
			Game.add_item("rifle", 1, true)
			Game.add_item("ammo_38", 40, true)
			Game.add_item("ammo_30", 20, true)
			player.teleport(Vector3(20, Layout.height(20, 40) + 0.2, 40), 0.0)
			if not Game.shot_args.has("nogun"):
				player.weapons.call("equip", Game.shot_args.get("gun", "pistol"))
			if Game.shot_args.has("enemy"):
				Game.set_flag("god")
				var ep := player.global_position + Vector3(2, 0, -14)
				ep.y = Layout.height(ep.x, ep.z) + 0.1
				var e := Enemy.spawn(world, Game.shot_args.enemy, ep, player)
				_enemies.append(e)
				_combat_watch()
				await wait(6.0)
				while is_instance_valid(e) and e.alive:
					player.look_toward(e.global_position + Vector3(0, 1.2 if e.kind != "mite" else 0.3, 0), 0.15)
					await wait(0.2)
					player.weapons.call("try_fire")
					await wait(0.5)
		_:
			await ch1_morning()


# ======================================================================== helpers

func _world(era: String) -> void:
	world = await main.make_world(era)
	player = main.player
	radio = PocketRadio.new()
	if not Game.shot_args.has("noradio"):
		player.add_child(radio)
	hud.enemies = _enemies
	if world.sky and not Game.shot_args.has("nosig"):
		if world.sky.has_signal("lights_should_be_on"):
			world.sky.connect("lights_should_be_on", _on_lights)
		if world.sky.has_signal("lightning"):
			world.sky.connect("lightning", _on_lightning)
		if world.sky.has_signal("weather_changed"):
			world.sky.connect("weather_changed", _on_weather)


func _on_lights(on: bool) -> void:
	if world.town:
		world.town.call("lights_on", on)
	if world.home and world.era == "after":
		world.home.set_lamps(on, 0.9)


func _on_lightning(_strength: float, distance: float) -> void:
	await get_tree().create_timer(clampf(distance / 340.0, 0.1, 4.0)).timeout
	Audio.sfx("thunder_near" if distance < 600.0 else "thunder_far", -2.0)


func _on_weather(w: String) -> void:
	match w:
		"rain":
			Audio.ambience("weather", "amb_rain_loop", -6.0, 6.0)
		"storm":
			Audio.ambience("weather", "amb_storm_wind_loop", -4.0, 6.0)
		"bloom":
			Audio.ambience("weather", "amb_bloom_loop", -6.0, 6.0)
			if tup and tup.mode == "follow":
				tup.bark("tp_c12")
		_:
			Audio.ambience("weather", "", 0.0, 6.0)


func _spawn_tuppence(pos: Vector3, yaw: float, aged: bool) -> void:
	tup = Tuppence.new()
	tup.name = "Tuppence"
	world.add_child(tup)
	tup.setup(player, aged)
	tup.place(pos, yaw)
	tup.talk_requested.connect(_on_talk)


func wait(t: float) -> void:
	await get_tree().create_timer(t).timeout


func near(p: Vector3, r: float) -> bool:
	return player != null and player.global_position.distance_to(p) < r


var auto := false


## Wait until the player is within r of p (polls every frame). Autopilot teleports there.
func until_near(p: Vector3, r: float) -> void:
	if auto and not near(p, r):
		await wait(0.8)
		var dir := (player.global_position - p)
		dir.y = 0
		var t := p + (dir.normalized() if dir.length() > 0.1 else Vector3.RIGHT) * minf(r * 0.6, 2.0)
		t.y = (p.y if p.y > 0.5 else Layout.height(t.x, t.z)) + 0.2
		player.teleport(t, rad_to_deg(atan2(-(p - t).x, -(p - t).z)))
	while not near(p, r):
		await get_tree().process_frame


## Await an Interactable being used. Autopilot uses it.
func use_of(it: Interactable) -> void:
	if auto:
		get_tree().create_timer(0.8).timeout.connect(func(): if is_instance_valid(it): it.use())
	await it.used


## Await a pickup being taken. Autopilot takes it.
func taken(p: Pickup) -> void:
	if auto:
		get_tree().create_timer(0.8).timeout.connect(func(): if is_instance_valid(p): p.use.use())
	await p.taken


## Wait for enemies to die. Autopilot kills them.
func until_dead(list: Array) -> void:
	if auto:
		await wait(2.0)
		for e in list:
			if is_instance_valid(e) and e.alive:
				e.take_hit("head", 9999.0, Vector3.FORWARD, e.global_position + Vector3.UP)
	await until(func(): return list.all(func(m): return not is_instance_valid(m) or not m.alive))


func until(cond: Callable) -> void:
	while not cond.call():
		await get_tree().process_frame


func lock() -> void:
	Game.input_locked += 1


func unlock() -> void:
	Game.input_locked = maxi(Game.input_locked - 1, 0)


func say(id: String, who: Node3D = null) -> void:
	await dlg.say(id, who)


func checkpoint(cp: String) -> void:
	Game.save_game(cp)
	Game.toast.emit("Progress saved")


# ======================================================================== cold open

func cold_open() -> void:
	hud.set_fade(1.0)
	hud.hide_all = true
	lock()
	Audio.music("coldopen", 1.0)
	await wait(1.5)
	var slide := TextureRect.new()
	slide.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	slide.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	slide.set_anchors_preset(Control.PRESET_FULL_RECT)
	slide.modulate = Color(1.0, 0.92, 0.8, 0.0)
	hud.root.add_child(slide)
	hud.root.move_child(slide, 0)
	hud.fade(0.0, 0.01)
	var bg := ColorRect.new()
	bg.color = Color.BLACK
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud.root.add_child(bg)
	hud.root.move_child(bg, 0)
	var pics := {"co_1": "tv_comet", "co_2": "photo_lighthouse", "co_3": "billboard_halcyon"}
	for id in ["co_1", "co_2", "co_3"]:
		var p := "res://assets/textures/gen/%s.png" % pics[id]
		slide.texture = load(p) if ResourceLoader.exists(p) else null
		slide.pivot_offset = get_viewport().get_visible_rect().size * 0.5
		slide.scale = Vector2.ONE * 1.02
		var d := Audio.voice(id)
		var tw0 := create_tween().set_parallel(true)
		tw0.tween_property(slide, "modulate:a", 0.85, 1.2)
		tw0.tween_property(slide, "scale", Vector2.ONE * 1.12, d + 1.5)
		await wait(d + 0.2)
		var tw1 := create_tween()
		tw1.tween_property(slide, "modulate:a", 0.0, 0.9)
		await tw1.finished
	slide.queue_free()
	# title logo
	var logo := TextureRect.new()
	if ResourceLoader.exists("res://assets/textures/gen/logo_title.png"):
		logo.texture = load("res://assets/textures/gen/logo_title.png")
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.set_anchors_preset(Control.PRESET_CENTER)
	logo.offset_left = -560
	logo.offset_right = 560
	logo.offset_top = -140
	logo.offset_bottom = 140
	logo.modulate.a = 0.0
	hud.root.add_child(logo)
	var d4 := Audio.voice("co_4")
	var tw := create_tween()
	tw.tween_property(logo, "modulate:a", 1.0, 2.0)
	tw.tween_interval(maxf(d4, 3.0))
	tw.tween_property(logo, "modulate:a", 0.0, 1.5)
	await tw.finished
	logo.queue_free()
	bg.queue_free()
	hud.set_fade(1.0)
	unlock()
	hud.hide_all = false


# ======================================================================== chapter 1

func ch1_setup(for_ch2 := false) -> void:
	await _world("before")
	world.set_time(8.65 if not for_ch2 else 9.05)
	world.set_weather("clear", 0.0)
	if world.sky:
		world.sky.set("time_paused", true)
	player.weapons.lowered = true
	_spawn_tuppence(world.home.spot("tuppence_wake"), -90.0, false)
	world.home.tv.start("morning")
	world.home.radio.set_on(true, true)
	world.home.set_lamps(true, 0.35)
	Audio.ambience("base", "amb_house_morning_loop", -10.0, 2.0)
	if for_ch2:
		world.home.open_curtains(0.1)
		player.teleport(world.home.spot("hall"), 180.0)
		tup.place(world.home.spot("entry") + Vector3(-0.6, 0, -1.2), 0.0)


func ch1_morning() -> void:
	await ch1_setup()
	Game.save_game("ch1")
	var home := world.home
	# wake up in bed: camera lies low, looking toward the window
	player.teleport(home.spot("bed"), -128.0)
	player.set_look(-128.0, 4.0)
	player.head.position.y = 0.35
	lock()
	hud.letterbox(true, 0.01)
	hud.set_fade(1.0)
	hud.fade(0.0, 3.0)
	Audio.music("morning_loop", 4.0, -6.0)
	await wait(1.6)
	tup.model.look_at_point(player.cam.global_position)
	tup.set_talking(true)
	await dlg.say("tp_wake_1", tup)
	tup.gesture("curtains")
	await wait(0.6)
	home.open_curtains(1.6)
	await wait(1.4)
	await dlg.say("tp_wake_2", tup)
	# sit up and stand beside the bed
	var stand := home.spot("bedroom") + Vector3(0.0, 0, 0.3)
	var tw := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(player, "global_position", stand, 1.6)
	tw.parallel().tween_property(player.head, "position:y", Player.EYE, 1.6)
	player.look_toward(tup.get_head_node().global_position, 1.6)
	await tw.finished
	hud.letterbox(false)
	unlock()
	# how should Tuppence address you?
	dlg.begin(tup)
	await dlg.say("tp_addr_q", tup)
	var i := await dlg.choose(["Sir.", "Ma'am.", "Boss.", "Captain."])
	Game.addr = ["sir", "maam", "boss", "captain"][i]
	tup.gesture("bow")
	await dlg.say("tp_addr_ok", tup)
	await dlg.end()
	Game.quest_start(Q_MORNING, "Good Morning, Larkhaven", "A sunny Saturday. Tuppence has the kettle on.")
	Game.objective(Q_MORNING, "ready", "Get ready for the day", null)
	Game.objective(Q_MORNING, "tea", "Ask Tuppence for a cup of tea", tup, true)
	Game.objective(Q_MORNING, "tv", "Catch the morning news on the Starlight", home.tv, true)
	Game.objective(Q_MORNING, "paper", "Read the Larkhaven Ledger", null, true)
	Game.objective(Q_MORNING, "mag", "Find something to read", null, true)
	var hx := home.global_transform
	tup.go_path([hx * Vector3(3.4, Home.FLOOR_Y, -2.0), hx * Vector3(1.6, Home.FLOOR_Y, -2.0), hx * Vector3(1.6, Home.FLOOR_Y, 2.6), hx * Vector3(3.5, Home.FLOOR_Y, 2.6), home.spot("table")], 1.6)
	# props for the optional tasks
	var paper := Pickup.spawn_note(world, home.spot("table") + Vector3(0.3, 0.775, 0.85), "newspaper_ledger", "The Larkhaven Ledger", "", 0.2)
	paper.taken.connect(func(): Game.objective_done(Q_MORNING, "paper"))
	Game.objective(Q_MORNING, "paper", "Read the Larkhaven Ledger", paper, true)
	var mag := Pickup.spawn_magazine(world, home.global_transform * Vector3(-2.75, Home.FLOOR_Y + 0.535, 2.6), "hearth", 20.0)
	mag.taken.connect(func():
		Game.objective_done(Q_MORNING, "mag")
		tup.bark("tp_bark_mag"))
	var mag2 := Pickup.spawn_magazine(world, home.global_transform * Vector3(-4.7, Home.FLOOR_Y + 0.79, -4.35), "tinker", -10.0)
	Pickup.spawn_item(world, home.global_transform * Vector3(5.45, Home.FLOOR_Y + 0.7, -4.3), "pocket_watch", 1, "pocket_watch", "", 40.0)
	Pickup.spawn_item(world, home.global_transform * Vector3(6.55, Home.FLOOR_Y + 0.92, 0.6), "scrip", 12, "")
	# watch the news: stand near the TV for a while
	_watch_tv()
	_photo_bark()
	# give the player time to potter around: doorbell after a couple of optional tasks or ~2 minutes
	var t0 := Time.get_ticks_msec()
	await until(func(): return _optional_done() >= 2 or (Time.get_ticks_msec() - t0) > (4000 if auto else 120000))
	await wait(2.0)
	await _registrar()
	await wait(4.0)
	await _phone_call()
	await ch2_bloom()


func _optional_done() -> int:
	var n := 0
	for o in ["tea", "tv", "paper", "mag"]:
		if Game.objective_is_done(Q_MORNING, o):
			n += 1
	return n


func _watch_tv() -> void:
	var acc := 0.0
	while not Game.objective_is_done(Q_MORNING, "tv") and is_instance_valid(world) and world.home:
		await get_tree().create_timer(0.5).timeout
		if player and near(world.home.spot("tv"), 3.6) and world.home.tv.on:
			acc += 0.5
			if acc > 12.0:
				Game.objective_done(Q_MORNING, "tv")
				tup.bark("tp_bark_tv")


func _photo_bark() -> void:
	await until(func(): return player == null or near(world.home.spot("photo_june"), 1.8))
	if player and tup:
		tup.bark("tp_bark_photo")


func _on_talk() -> void:
	if _talk_busy or dlg.is_active():
		return
	_talk_busy = true
	dlg.begin(tup)
	var after := world.era == "after"
	while true:
		var opts := ["How are you today?", "Make me some tea.", "Tell me a joke.", "That's all."]
		if not after and Game.flag("ch2"):
			break
		if not after:
			opts.insert(1, "Anything happening today?")
		var i := await dlg.choose(opts)
		var pick: String = opts[i]
		match pick:
			"How are you today?":
				await dlg.say("tp_how_after" if after else "tp_how", tup)
			"Anything happening today?":
				await dlg.say("tp_today", tup)
			"Make me some tea.":
				var now := Time.get_ticks_msec() / 1000.0
				if now - _tea_ready_at < 90.0 and _tea_ready_at > 0.0:
					await dlg.say("tp_tea_wait", tup)
				else:
					_tea_ready_at = now
					await dlg.say("tp_tea_after" if after else "tp_tea", tup)
					tup.gesture("tea")
					Audio.sfx_at("tea_pour", tup.global_position + Vector3(0, 1, 0), -4.0)
					await wait(1.6)
					Audio.sfx_at("cup_clink", tup.global_position + Vector3(0, 1, 0), -6.0)
					if not after:
						await dlg.say("tp_tea_done", tup)
						Game.objective_done(Q_MORNING, "tea")
						Game.heal_hp(30.0)
					else:
						Game.add_item("tea", 1)
			"Tell me a joke.":
				var j := ["tp_joke_1", "tp_joke_2", "tp_joke_3"][randi() % 3] as String
				await dlg.say(j, tup)
				tup.gesture("celebrate")
			_:
				await dlg.say("tp_bye", tup)
				break
	await dlg.end()
	_talk_busy = false


func _registrar() -> void:
	var home := world.home
	Audio.sfx_at("doorbell", home.spot("front_door_in") + Vector3(0, 2.0, 0), 0.0, 8.0)
	await wait(1.2)
	tup.bark("tp_door", true)
	Game.objective_done(Q_MORNING, "ready")
	Game.objective(Q_MORNING, "door", "Answer the front door", home.spot("front_door_in"))
	await wait(4.0)
	Audio.sfx_at("doorbell", home.spot("front_door_in") + Vector3(0, 2.0, 0), -2.0, 8.0)
	# the registrar waits on the porch
	var reg := RegistrarModel.new()
	world.add_child(reg)
	# wheels on the porch deck (the deck top sits 1 cm above the floor spot; the old -0.02 sank it in)
	var at := home.spot("front_door_out") + Vector3(0, 0, 0.4)
	at.y = _reg_ground(at, 0.0, at.y)
	reg.global_position = at
	reg.rotation.y = 0.0
	if auto:
		get_tree().create_timer(1.0).timeout.connect(func(): home.front_door.set_open(true))
	if not home.front_door.is_open:
		await home.front_door.opened
	Game.objective_done(Q_MORNING, "door")
	reg.look_at_point(player.cam.global_position)
	dlg.begin(reg)
	reg.play_gesture("bow")
	await dlg.say("rg_1", reg)
	await dlg.say("rg_2", reg)
	await dlg.say("rg_q1", reg)
	var a := await dlg.choose(["The flashlight.", "The first aid kit.", "The family photographs."])
	Game.add_trait(["keen", "hardy", "sentimental"][a])
	await dlg.say("rg_ack_1", reg)
	await dlg.say("rg_q2", reg)
	var b := await dlg.choose(["Share it.", "Politely decline.", "Ask if they've brought biscuits."])
	Game.add_trait(["neighborly", "selfreliant", "pragmatist"][b])
	await dlg.say("rg_ack_2", reg)
	await dlg.say("rg_q3", reg)
	var c := await dlg.choose(["Better.", "The same.", "Gentle."])
	Game.add_trait(["optimist", "steady", "loyalist"][c])
	await dlg.say("rg_ack_3", reg)
	reg.play_gesture("stamp")
	await dlg.say("rg_end", reg)
	await dlg.end()
	Game.add_item("reg_card", 1)
	var names := []
	for t in Game.traits:
		names.append(Game.TRAITS[t].name)
	hud.banner("TRAITS", ", ".join(names), 4.0)
	# registrar trundles off down the path, out of the gate and away along Gull Lane
	_registrar_leave(reg)
	tup.go(home.spot("entry") + Vector3(-0.6, 0, -1.4), 2.0)
	await wait(2.5)
	tup.bark("tp_after_rg", true)


## Drives Registrar 9 away (fire-and-forget): turns on the spot, rolls off the porch, down the steps and the
## garden path, out through the gate, turns west along Gull Lane and is freed once out of the player's view.
## Steering is pure pursuit over home-local waypoints with a capped turn rate; the wheels ride the highest
## surface under the base footprint (deck, steps, path slabs, terrain, road), so nothing sinks into them.
func _registrar_leave(reg: RegistrarModel) -> void:
	var home := world.home
	# home-local (x, z): porch edge, foot of the steps, path before the gate, through the gate (the fence is
	# at z 11; its opening is x 0.67..2.3), swing west into the north lane, then far down the street
	var route := [Vector2(1.6, 7.3), Vector2(1.6, 8.7), Vector2(1.6, 10.2), Vector2(1.6, 12.2), Vector2(1.2, 14.6), Vector2(0.2, 15.6), Vector2(-12.0, 15.6), Vector2(-85.0, 15.6)]
	var pts: Array[Vector3] = []
	for p: Vector2 in route:
		pts.append(home.global_transform * Vector3(p.x, 0.0, p.y))
	reg.clear_look()
	var yaw := reg.rotation.y
	var speed := 0.0
	var y := reg.global_position.y
	var i := 0
	while i < pts.size():
		await get_tree().physics_frame
		if not is_instance_valid(reg) or not is_instance_valid(world):
			return
		var dt := get_physics_process_delta_time()
		var pos := reg.global_position
		var to := pts[i] - pos
		to.y = 0.0
		# tight arrival on the porch, steps and path; looser once out on the street so corners are rounded
		if to.length() < (0.12 if i < 3 else 0.45):
			i += 1
			continue
		var err := wrapf(atan2(-to.x, -to.z) - yaw, -PI, PI)
		yaw += clampf(err, -1.4 * dt, 1.4 * dt)
		# turn on the spot when facing well away from the next point; slow on the steps and the path
		var vmax := 0.7 if i < 3 else 1.25
		speed = move_toward(speed, vmax * clampf(1.0 - absf(err) / 0.6, 0.0, 1.0), 1.0 * dt)
		pos += Vector3(-sin(yaw), 0.0, -cos(yaw)) * speed * dt
		var ground := _reg_ground(pos, yaw, y)
		# step up at once (never sink into a surface), settle down a step smoothly
		y = ground if ground > y else lerpf(y, ground, 1.0 - exp(-14.0 * dt))
		pos.y = y
		reg.global_position = pos
		reg.rotation.y = yaw
		reg.set_move_speed(speed / 1.25)
		if i >= 4 and _reg_out_of_view(reg):
			break
	if is_instance_valid(reg):
		reg.queue_free()


## Highest world surface (layer 1) under the registrar's wheelbase at pos facing yaw, or fallback.
func _reg_ground(pos: Vector3, yaw: float, fallback: float) -> float:
	var space := world.get_world_3d().direct_space_state
	var f := Vector3(-sin(yaw), 0.0, -cos(yaw))
	var r := Vector3(-f.z, 0.0, f.x)
	var best := -INF
	for o: Vector2 in [Vector2.ZERO, Vector2(0.22, 0.27), Vector2(0.22, -0.27), Vector2(-0.22, 0.27), Vector2(-0.22, -0.27), Vector2(0.22, 0.0), Vector2(-0.22, 0.0)]:
		var p := pos + f * o.x + r * o.y
		var q := PhysicsRayQueryParameters3D.create(p + Vector3(0, 0.6, 0), p + Vector3(0, -2.5, 0), 1)
		var hit := space.intersect_ray(q)
		if not hit.is_empty():
			best = maxf(best, (hit.position as Vector3).y)
	return best if best > -INF else fallback


func _reg_out_of_view(reg: Node3D) -> bool:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return true
	var c := reg.global_position
	var d := cam.global_position.distance_to(c)
	if d > 45.0:
		return true
	if d < 6.0:
		return false
	for o: Vector3 in [Vector3(0, 0.2, 0), Vector3(0, 0.9, 0), Vector3(0, 1.75, 0), Vector3(0.6, 0.9, 0), Vector3(-0.6, 0.9, 0), Vector3(0, 0.9, 0.6), Vector3(0, 0.9, -0.6)]:
		if cam.is_position_in_frustum(c + o):
			return false
	return true


func _phone_call() -> void:
	var home := world.home
	var ring := Audio.loop_on(home.spots["phone"], "phone_ring", 0.0, 6.0)
	if ring.stream == null:
		ring.stream = Audio.sfx_stream("phone_ring")
	ring.play()
	await wait(1.5)
	tup.bark("tp_phone", true)
	Game.objective(Q_MORNING, "phone", "Answer the telephone", home.spot("phone"))
	home.phone_use.enabled = true
	await use_of(home.phone_use)
	home.phone_use.enabled = false
	ring.queue_free()
	Audio.sfx("phone_pickup", -4.0)
	Game.objective_done(Q_MORNING, "phone")
	dlg.begin(null, false)
	await dlg.say("jn_1", null, false)
	await dlg.say("jn_2", null, false)
	var i := await dlg.choose(["Purple dust?", "You're at the shelter already?"])
	await dlg.say("jn_3a" if i == 0 else "jn_3b", null, false)
	await dlg.say("jn_4", null, false)
	# the sirens start mid-sentence
	get_tree().create_timer(2.2).timeout.connect(func(): Audio.ambience("siren", "siren_loop", -2.0, 2.0))
	await dlg.say("jn_5", null, false)
	Audio.sfx("phone_hangup", -4.0)
	await dlg.end()
	Game.quest_complete(Q_MORNING, 40)


# ======================================================================== chapter 2: the bloom

func ch2_bloom() -> void:
	Game.set_flag("ch2")
	Game.save_game("ch2")
	var home := world.home
	var town := world.town
	if Audio.music_name() != "dash_loop":
		Audio.ambience("siren", "siren_loop", -2.0, 2.0)
	home.tv.emergency()
	home.radio.set_on(false, true)
	town.open_shelter_doors(true, 0.1)
	Audio.ambience("base", "amb_town_day_loop", -12.0, 2.0)
	Audio.music("", 2.0)
	if world.sky:
		world.sky.set("time_paused", false)
		world.sky.set("day_speed", 3.0)
	tup.model.set_expression("worried")
	tup.go(player.global_position + (tup.global_position - player.global_position).normalized() * 1.6, 3.0)
	dlg.begin(tup)
	tup.gesture("fret")
	await dlg.say("tp_e1", tup)
	await dlg.say("tp_e2", tup)
	await dlg.choose(["You're coming with me.", "What about you?"])
	tup.gesture("point")
	await dlg.say("tp_e3", tup)
	await dlg.end()
	Game.quest_start(Q_SHELTER, "Shelter No. 9", "The sirens are real. Get to the shelter on the bluff.")
	var gate: Vector3 = town.call("spot", "shelter_gate")
	Game.objective(Q_SHELTER, "run", "Get to Shelter No. 9 before the doors close", gate)
	Audio.music("dash_loop", 1.5)
	home.front_door.set_open(true)
	tup.follow(6.5)
	player.weapons.lowered = false
	var t_start := Time.get_ticks_msec()
	_dash_events(t_start)
	# wait for the player to reach the gate (or be caught by the wave)
	var caught := false
	while not near(gate, 3.5):
		await get_tree().process_frame
		if auto and (Time.get_ticks_msec() - t_start) > 9000:
			player.teleport(gate + Vector3(-1, 0.2, 0), -90.0)
		var el := (Time.get_ticks_msec() - t_start) / 1000.0
		_bloom_progress(el)
		if el > 170.0:
			caught = true
			break
	if caught:
		await _caught_by_bloom()
		return
	await _gate_scene()


func _bloom_progress(el: float) -> void:
	var t := clampf(el / 140.0, 0.0, 1.0)
	if world.sky and world.sky.has_method("set_bloom_event"):
		world.sky.call("set_bloom_event", t)
	if world.has_meta("wave"):
		var wave: Node3D = world.get_meta("wave")
		wave.global_position.x = lerpf(-260.0, 40.0, t)


func _dash_events(t0: float) -> void:
	var town := world.town
	var home := world.home
	# the violet wave: a wall of glowing fog crossing the bay
	var wave := Node3D.new()
	world.add_child(wave)
	wave.global_position = Vector3(-260, 0, 0)
	world.set_meta("wave", wave)
	for k in 6:
		var fv := FogVolume.new()
		fv.size = Vector3(60, 70, 140)
		fv.shape = RenderingServer.FOG_VOLUME_SHAPE_ELLIPSOID
		var fm := FogMaterial.new()
		fm.density = 0.6
		fm.albedo = Color(0.7, 0.45, 1.0)
		fm.emission = Color(0.35, 0.12, 0.6)
		fm.height_falloff = 0.02
		fv.material = fm
		wave.add_child(fv)
		fv.position = Vector3(randf_range(-10, 10), 25, -350 + k * 140)
	var glow := OmniLight3D.new()
	glow.light_color = Color(0.7, 0.4, 1.0)
	glow.light_energy = 4.0
	glow.omni_range = 120.0
	glow.position = Vector3(20, 30, 0)
	wave.add_child(glow)
	Audio.sfx("bloom_wave", -6.0)
	# civil defense loudspeakers
	_timed(2.0, func(): Audio.voice("cd_1"))
	_timed(16.0, func(): Audio.voice("cd_2"))
	_timed(38.0, func(): Audio.voice("cd_3"))
	_timed(60.0, func(): Audio.voice("cd_4"))
	_timed(90.0, func(): Audio.voice("cd_5"))
	_timed(4.0, func(): Audio.sfx("dog_bark", -14.0))
	_timed(9.0, func(): Audio.sfx("explosion_distant", -8.0))
	# when the player steps outside: the car crash + gulls fleeing
	await until_near(home.spot("front_door_out") + Vector3(0, 0, 2.5), 2.0)
	if player == null:
		return
	tup.bark("tp_dash_1", true)
	var cs: Vector3 = town.call("spot", "crash")
	var car := Town.make_car(world, cs + Vector3(-1.6, 0.0, -1.0), 60.0, Color(0.85, 0.3, 0.28), false)
	car.rotation.z = 0.04
	Audio.sfx_at("car_crash", cs, 4.0, 14.0)
	Audio.sfx_at("glass_break", cs, 0.0, 10.0)
	var alarm := Audio.loop_on(car, "car_alarm_loop", -4.0, 6.0)
	var spray := CPUParticles3D.new()
	spray.amount = 120
	spray.lifetime = 1.4
	var qm := QuadMesh.new()
	qm.size = Vector2(0.12, 0.12)
	qm.material = Fx._mat(Color(0.85, 0.92, 1.0, 0.7), false)
	spray.mesh = qm
	spray.direction = Vector3(0.2, 1, 0.1)
	spray.spread = 10.0
	spray.initial_velocity_min = 6.0
	spray.initial_velocity_max = 9.0
	spray.gravity = Vector3(0, -9.8, 0)
	spray.scale_amount_min = 0.6
	spray.scale_amount_max = 1.6
	world.add_child(spray)
	spray.global_position = cs + Vector3(0, 0.6, 0)
	Audio.loop_on(spray, "water_spray_loop", -4.0, 5.0)
	_gulls(Vector3(-40, 25, -20), Vector3(1, 0.1, -0.3))
	await until_near(cs, 14.0)
	tup.bark("tp_dash_2", true)
	await until_near(Vector3(74, Layout.road_center_h(Vector2(74, -2)), -2), 6.0)
	tup.bark("tp_dash_3", true)
	_gulls(Vector3(60, 30, 20), Vector3(1, 0.05, -0.6))
	await until_near(Vector3(126, Layout.road_center_h(Vector2(126, -64)), -64), 8.0)
	tup.bark("tp_dash_4", true)
	Audio.voice("pa_gate_1")
	town.shelter_klaxon.set_meta("on", true)
	Audio.loop_on(town.get_node("ShelterPortal"), "gate_klaxon_loop", -2.0, 12.0)


func _timed(t: float, f: Callable) -> void:
	await wait(t)
	if is_instance_valid(world) and Game.flag("ch2") and not Game.flag("ch3") and not Game.flag("at_gate"):
		f.call()


func _gulls(at: Vector3, dir: Vector3) -> void:
	Audio.sfx_at("bird_flock", at, 0.0, 20.0)
	for k in 9:
		var g := GullModel.new()
		world.add_child(g)
		g.global_position = at + Vector3(randf_range(-6, 6), randf_range(-3, 3), randf_range(-6, 6))
		g.rotation.y = atan2(-dir.x, -dir.z)
		if g.has_method("set_flap"):
			g.call("set_flap", 1.0)
		var tw := g.create_tween()
		tw.tween_property(g, "global_position", g.global_position + dir.normalized() * 160.0 + Vector3(0, 15, 0), 14.0)
		tw.tween_callback(g.queue_free)


func _caught_by_bloom() -> void:
	lock()
	hud.fade(1.0, 2.5, Color(0.55, 0.3, 0.85))
	Audio.sfx("bloom_wave", 0.0)
	await wait(2.6)
	await hud.card(["The Bloom took Larkhaven.", "You were too slow. Try again."], 2.5).finished
	unlock()
	main.call("_start_story", "ch2")


func _gate_scene() -> void:
	var town := world.town
	Game.objective_done(Q_SHELTER, "run")
	Game.set_flag("at_gate")
	lock()
	hud.letterbox(true)
	# step inside, turn around to face the bay and Tuppence at the threshold
	var inside: Vector3 = town.call("spot", "shelter_inside")
	var outside: Vector3 = town.call("spot", "shelter_outside")
	var tw := create_tween()
	tw.tween_property(player, "global_position", inside, 1.0)
	await tw.finished
	tup.stay()
	tup.place(town.call("spot", "shelter_gate") + Vector3(-1.2, 0, 0), 90.0)
	player.look_toward(tup.get_head_node().global_position, 0.8)
	Audio.voice("pa_gate_2")
	await wait(0.8)
	tup.gesture("wave")
	await dlg.say("tp_gate", tup)
	Audio.sfx("gate_klaxon", 0.0)
	town.call("open_shelter_doors", false, 4.0)
	Audio.music("", 3.0)
	if world.sky and world.sky.has_method("set_bloom_event"):
		var tw2 := create_tween()
		tw2.tween_method(func(v: float): world.sky.call("set_bloom_event", v), 0.85, 1.0, 4.0)
	var wave: Node3D = world.get_meta("wave") if world.has_meta("wave") else null
	if wave:
		create_tween().tween_property(wave, "global_position:x", 150.0, 4.5)
	await wait(3.8)
	Audio.sfx("gate_slam", 4.0)
	Audio.sting("dash_end")
	player.shake(1.4)
	Audio.ambience("siren", "", 0.0, 0.3)
	hud.set_fade(1.0)
	await wait(2.5)
	hud.letterbox(false)
	Game.quest_complete(Q_SHELTER, 60)
	unlock()
	await ch3_shelter()


# ======================================================================== chapter 3: shelter no. 9

func ch3_shelter() -> void:
	Game.set_flag("ch3")
	var sh := world.shelter
	if world.sky and world.sky.has_method("set_bloom_event"):
		world.sky.call("set_bloom_event", 0.0)
	if world.has_meta("wave"):
		(world.get_meta("wave") as Node3D).queue_free()
		world.remove_meta("wave")
	tup.queue_free()
	tup = null
	Audio.ambience("base", "", 0.0, 1.0)
	hud.fade(0.0, 2.0)
	player.teleport(sh.call("spot", "entry"), -90.0)
	await wait(1.0)
	await dlg.say("pa_s1")
	Game.quest_start("rest", "Rest Ward A", "Halcyon will look after everything.")
	Game.objective("rest", "bunk", "Find bunk No. 31 in Rest Ward A", sh.call("spot", "bunk31"))
	await dlg.say("pa_s2")
	await until_near(sh.call("spot", "bunk31"), 3.0)
	# June on the bunk intercom
	Audio.sfx("pa_chime", -6.0, 0.0, "Phone")
	dlg.begin(null, false)
	await dlg.say("jn_6", null, false)
	await dlg.choose(["He stayed with the house.", "He wouldn't come in."])
	await dlg.say("jn_7", null, false)
	await dlg.end()
	await dlg.say("pa_s3")
	Game.objective("rest", "bunk", "Lie down on bunk No. 31", sh.call("spot", "bunk31"))
	sh.bunk31.enabled = true
	await use_of(sh.bunk31)
	sh.bunk31.enabled = false
	lock()
	var tw := create_tween()
	tw.tween_property(player, "global_position", sh.call("spot", "bunk31") - Vector3(0, 0.25, 0), 1.2)
	tw.parallel().tween_property(player.head, "position:y", 0.4, 1.2)
	await tw.finished
	player.set_look(rad_to_deg(player.rotation.y), 60.0)
	Audio.voice("pa_s4")
	hud.fade(1.0, 4.0)
	Audio.music("shelter_wake_loop", 4.0, -8.0)
	await wait(5.0)
	Game.quest_complete("rest", 20)
	# the years pass
	await _montage()
	unlock()
	await ch3_wake()


func _montage() -> void:
	hud.hide_all = true
	for item in [["pa_m1", "1968"], ["pa_m2", "1973"], ["rr_frag", ""], ["pa_m3", "1976"], ["pa_m4", "1978"]]:
		var d := Audio.voice(item[0], null, "Radio" if item[0] == "rr_frag" else "")
		if item[1] != "":
			hud.card([item[1]], d - 1.6, [72])
		await wait(d + 0.8)
	await hud.card(["ELEVEN YEARS LATER"], 2.5, [64]).finished
	hud.hide_all = false


func ch3_wake() -> void:
	hud.set_fade(1.0)
	await _world("after")
	Game.set_flag("ch2")
	Game.set_flag("ch3")
	Game.save_game("ch3b")
	var sh := world.shelter
	world.set_time(7.4)
	world.set_weather("clear", 0.0)
	player.teleport(sh.call("spot", "bunk31") - Vector3(0, 0.25, 0), 90.0)
	player.head.position.y = 0.4
	player.set_look(90.0, 50.0)
	lock()
	Audio.music("shelter_wake_loop", 2.0, -6.0)
	hud.fade(0.0, 4.0)
	await wait(2.0)
	await dlg.say("pa_w1")
	var tw := create_tween().set_trans(Tween.TRANS_SINE)
	tw.tween_property(player, "global_position", sh.call("spot", "bunk31_side"), 1.8)
	tw.parallel().tween_property(player.head, "position:y", Player.EYE, 1.8)
	player.look_toward(sh.call("spot", "ward"), 1.8)
	await tw.finished
	unlock()
	await dlg.say("pa_w2")
	player.flashlight.visible = true
	Game.toast.emit("[F] Flashlight")
	Game.quest_start(Q_MAIN, "Follow the Music", "Ward A is empty. Everyone is gone.")
	var note := Pickup.spawn_note(world, sh.call("spot", "bunk31_crate_top"), "note_june", "A note from June", "june_note")
	Game.objective(Q_MAIN, "note", "Read the note by your bunk", note)
	await taken(note)
	Game.objective_done(Q_MAIN, "note")
	if Reader.is_open():
		await main.reader.closed
	Game.objective(Q_MAIN, "office", "Find a way out — try the Warden's office", sh.call("spot", "office"))
	var mag := Pickup.spawn_magazine(world, sh.call("spot", "desk_top"), "astounding", 30.0)
	Pickup.spawn_item(world, sh.call("spot", "shelf_top"), "pep_tonic", 1, "")
	Pickup.spawn_item(world, sh.call("spot", "beans"), "beans", 1, "long_life_food", "long_life_food_beans")
	await until_near(sh.call("spot", "office"), 3.0)
	Game.objective_done(Q_MAIN, "office")
	Game.objective(Q_MAIN, "log", "Play the Warden's log", sh.call("spot", "recorder"))
	sh.terminal.enabled = true
	await use_of(sh.terminal)
	sh.terminal.enabled = false
	Game.objective_done(Q_MAIN, "log")
	for id in ["wd_1", "wd_2", "wd_3"]:
		await dlg.say(id)
	Game.objective(Q_MAIN, "pistol", "Take the pistol from the Warden's locker", sh.call("spot", "locker"))
	sh.locker.enabled = true
	await use_of(sh.locker)
	sh.locker.enabled = false
	Audio.sfx("door_open", -6.0)
	Game.add_item("pistol", 1)
	Game.add_item("ammo_38", 24)
	Game.add_xp(20)
	player.weapons.call("equip", "pistol")
	Game.objective_done(Q_MAIN, "pistol")
	hud.banner("SERVICE PISTOL", "[LMB] Fire   [RMB] Aim   [R] Reload   [1/2] Weapons", 4.0)
	await wait(2.0)
	# mites burst out of the breach
	Audio.sfx_at("crystal_shatter", sh.call("spot", "breach"), 2.0, 12.0)
	Audio.music("combat_loop", 1.0)
	Game.objective(Q_MAIN, "mites", "Defend yourself", null)
	var b: Vector3 = sh.call("spot", "breach")
	var mites := []
	for k in 3:
		var e := Enemy.spawn(world, "mite", b + Vector3(k * 0.8 - 0.8, 0.1, 1.0), player, true)
		mites.append(e)
		_enemies.append(e)
	for k in mites.size():
		await wait(0.6)
		mites[k].wake(true)
	await wait(2.0)
	hud.banner("BLOOM MITES", "Small and fast. Aim low  [RMB]", 4.0)
	await until_dead(mites)
	Game.objective_done(Q_MAIN, "mites")
	Audio.music("shelter_wake_loop", 3.0, -6.0)
	await wait(1.5)
	# power puzzle
	Game.objective(Q_MAIN, "power", "Restore power to the shelter door", sh.call("spot", "fusebox"))
	await until_near(sh.call("spot", "fusebox"), 3.5)
	if Game.count("fuse") == 0:
		Game.toast.emit("The main breaker is missing its fuse.")
		var fuse := Pickup.spawn_item(world, sh.call("spot", "fuse"), "fuse", 1, "medical_tape")
		Game.objective(Q_MAIN, "power", "Find a fuse — check the storage room", fuse)
		await taken(fuse)
	Game.objective(Q_MAIN, "power", "Insert the fuse into the main breaker", sh.call("spot", "fusebox"))
	sh.fusebox.enabled = true
	await use_of(sh.fusebox)
	sh.fusebox.enabled = false
	Game.remove_item("fuse")
	Audio.sfx("fuse_insert", 0.0)
	await wait(0.5)
	Audio.sfx("lever_pull", 0.0)
	Audio.sfx("power_up", 2.0)
	sh.call("set_power", true)
	Game.objective_done(Q_MAIN, "power")
	await dlg.say("pa_w3")
	Game.objective(Q_MAIN, "exit", "Open the shelter door", sh.call("spot", "gate_inside"))
	sh.gate_panel.enabled = true
	await use_of(sh.gate_panel)
	sh.gate_panel.enabled = false
	Game.objective_done(Q_MAIN, "exit")
	await _exit_shelter()


func Shelter_Y() -> float:
	return 20.0


func _exit_shelter() -> void:
	var town := world.town
	lock()
	player.look_toward(town.call("spot", "shelter_outside") + Vector3(0, 1.6, 0), 1.0)
	Audio.sfx("gate_open", 2.0)
	Audio.music("", 3.0)
	if world.sky and world.sky.has_method("set_exposure_adapt_speed"):
		world.sky.call("set_exposure_adapt_speed", 0.35)
	town.call("open_shelter_doors", true, 6.0)
	player.shake(0.5)
	await wait(5.5)
	player.flashlight.visible = false
	unlock()
	Game.save_game("ch4")
	await until_near(town.call("spot", "shelter_outside"), 3.0)
	Audio.sting("sting_discover")
	Game.discover("Larkhaven")
	await ch4_afterbloom()


# ======================================================================== chapter 4: afterbloom

func ch4_setup(cp: String) -> void:
	await _world("after")
	Game.set_flag("ch2")
	Game.set_flag("ch3")
	world.set_time(Game.game_hour if cp != "ch4" else 8.0)
	world.set_weather("clear", 0.0)
	var town := world.town
	town.call("open_shelter_doors", true, 0.1)
	if Game.count("pistol") > 0:
		player.weapons.call("equip", "pistol")
	if cp == "ch4":
		player.teleport(town.call("spot", "shelter_outside"), 90.0)
	else:
		player.teleport(world.home.spot("porch"), 180.0)
		_spawn_tuppence(world.home.spot("porch") + Vector3(1.5, 0, 0.5), 180.0, true)
		_join_tuppence()


func _join_tuppence() -> void:
	tup.follow(4.5)
	tup.zap_enabled = true
	_companion_barks()


func ch4_afterbloom() -> void:
	Game.set_flag("ch4")
	var home := world.home
	var town := world.town
	if world.sky:
		world.sky.set("time_paused", false)
		world.sky.set("day_speed", 12.0)
	Audio.ambience("base", "amb_after_day_loop", -8.0, 4.0)
	_explore_music()
	_combat_watch()
	_place_world_loot()
	if not Game.flag("reunited"):
		Game.objective(Q_MAIN, "home", "Go home to Gull Lane", home.spot("front_door_out"))
		_ambush("mite", [Vector3(118, 0, -50), Vector3(121, 0, -47)], Vector3(120, 0, -48), 16.0)
		# Tuppence inside, polishing the newel post in the hall
		_spawn_tuppence(home.spot("hall") + Vector3(0.6, 0, 0.3), -90.0, true)
		tup.look_player = false
		tup.gesture("polish")
		_polish_loop()
		await until_near(home.spot("entry"), 6.5)
		await _reunion()
	if not Game.flag("ending_seen"):
		await _journey()
	await free_roam()


func _polish_loop() -> void:
	while is_instance_valid(tup) and not Game.flag("reunited"):
		if not tup.model.is_gesturing():
			tup.gesture("polish")
			Audio.sfx_at("robot_polish", tup.global_position + Vector3(0, 1, 0), -10.0, 3.0)
		await wait(0.5)


func _reunion() -> void:
	var home := world.home
	Game.objective_done(Q_MAIN, "home")
	await dlg.say("tp_r1", tup)
	await until_near(tup.global_position, 4.0)
	Game.set_flag("reunited")
	tup.look_player = true
	var to_p := player.global_position - tup.global_position
	tup.rotation.y = atan2(-to_p.x, -to_p.z)
	Audio.music("", 1.0)
	dlg.begin(tup)
	tup.model.set_expression("happy")
	await dlg.say("tp_r2", tup)
	Audio.sting("sting_reunion")
	tup.gesture("celebrate")
	await dlg.say("tp_r3", tup)
	var i := await dlg.choose(["Tuppence! You're still here.", "What happened to everyone?"])
	await dlg.say("tp_r4a" if i == 0 else "tp_r4b", tup)
	await dlg.say("tp_r5", tup)
	await dlg.choose(["June left me a note. She went to the lighthouse."])
	await dlg.say("tp_r6", tup)
	tup.gesture("tea")
	await dlg.say("tp_r7", tup)
	Game.add_item("pocket_radio", 1)
	await dlg.say("tp_r8", tup)
	tup.gesture("nod")
	await dlg.end()
	Game.add_xp(40)
	_join_tuppence()
	Game.save_game("ch4b")
	_explore_music()


func _journey() -> void:
	var town := world.town
	Game.objective(Q_MAIN, "radio", "Tune in to Larkhaven Free Radio  [T]", null)
	hud.banner("POCKET RADIO", "[T] Toggle the radio", 4.0)
	if auto:
		get_tree().create_timer(1.0).timeout.connect(func(): radio.set_on(true))
	if not radio.on:
		await radio.toggled
	Game.objective_done(Q_MAIN, "radio")
	# Rory reads June's message (jump the queue)
	Audio.radio_queue_special("lfr_1978", "v:rr_9")
	Audio.call("_advance_station", "lfr_1978")
	await wait(Audio.stream(Game.voice_path("rr_9")).get_length() + 1.0 if Audio.stream(Game.voice_path("rr_9")) else 6.0)
	Game.objective(Q_MAIN, "lighthouse", "Follow the coast road to the lighthouse", town.call("spot", "lh_door"))
	Game.quest_start(Q_RIFLE, "Something Bigger", "Tuppence says the Civil Defense post kept rifles.")
	Game.objective(Q_RIFLE, "locker", "Search the Civil Defense post in the town square", town.call("spot", "cd_locker"), true)
	Game.tracked_quest = Q_MAIN
	Game.quests_changed.emit()
	if world.sky:
		world.sky.call("set_weather", "cloudy", 40.0)
	_cd_locker()
	# the square: husks rise from the crystal beds
	var sq: Vector3 = town.call("spot", "square")
	await until_near(sq, 34.0)
	tup.bark("tp_c3", true)
	if world.sky:
		world.sky.call("set_weather", "rain", 25.0)
	await until_near(sq, 22.0)
	tup.bark("tp_c16", true)
	var group := _ambush_now("husk", [sq + Vector3(6, 0, -4), sq + Vector3(-7, 0, 3), sq + Vector3(2, 0, 8), sq + Vector3(-3, 0, -9)])
	group.append_array(_ambush_now("mite", [sq + Vector3(9, 0, 5), sq + Vector3(-10, 0, -2)]))
	await until_dead(group)
	tup.bark("tp_c17", true)
	Game.discover("Harbor Square")
	if world.sky:
		world.sky.call("set_weather", "bloom", 30.0)
	# coast road husks
	_ambush("husk", [Vector3(-96, 0, 20), Vector3(-90, 0, 14)], Vector3(-92, 0, 30), 22.0)
	_ambush("husk", [Vector3(-100, 0, -110), Vector3(-108, 0, -116), Vector3(-96, 0, -120)], Vector3(-100, 0, -95), 24.0)
	var lh := Layout.LIGHTHOUSE
	await until_near(Vector3(lh.x, Layout.height(lh.x, lh.z), lh.z), 140.0)
	tup.bark("tp_c15", true)
	if world.sky:
		world.sky.call("set_weather", "clear", 40.0)
	Game.discover("Gull Point Lighthouse")
	# the Thornback
	var door: Vector3 = town.call("spot", "lh_door")
	await until_near(door, 45.0)
	await _thornback(door)
	# intercom + ending
	Game.objective(Q_MAIN, "intercom", "Press the intercom at the radio station", door)
	town.lh_intercom.enabled = true
	await use_of(town.lh_intercom)
	town.lh_intercom.enabled = false
	Audio.sfx("radio_click", -2.0)
	await _ending()


func _thornback(door: Vector3) -> void:
	var spawn := door + Vector3(30, 0, 18)
	spawn.y = Layout.height(spawn.x, spawn.z)
	var tb := Enemy.spawn(world, "thornback", spawn, player, true)
	_enemies.append(tb)
	await wait(0.5)
	Audio.music("boss_loop", 0.5)
	tb.wake(true)
	tb.model.call("play_roar")
	Audio.sfx_at("thornback_roar", spawn, 6.0, 30.0)
	player.shake(0.8)
	tup.bark("tp_c19", true)
	hud.banner("THORNBACK", "Aim for the glowing thorns on its back", 4.0)
	await until_dead([tb])
	Audio.music("", 2.0)
	Audio.sting("sting_quest_done")
	await wait(2.0)
	tup.bark("tp_c4", true)


func _ending() -> void:
	Game.set_flag("ending_seen")
	lock()
	Audio.music("", 1.0)
	Audio.voice("rr_i1", null, "Phone")
	await wait(Audio.stream(Game.voice_path("rr_i1")).get_length() + 0.4 if Audio.stream(Game.voice_path("rr_i1")) else 4.0)
	await dlg.say("rr_i2", null, false)
	await wait(1.0)
	await dlg.say("jn_end", null, false)
	Audio.sfx_at("door_open", world.town.call("spot", "lh_door"), 0.0, 6.0)
	Audio.sting("sting_ending")
	await dlg.say("tp_end", tup)
	Game.quest_complete(Q_MAIN, 150)
	hud.fade(1.0, 3.0, Color(1.0, 0.95, 0.85))
	await wait(3.5)
	await hud.fade(1.0, 2.0, Color(0.02, 0.015, 0.01)).finished
	var stats := "Level %d  ·  %d XP  ·  Magazines %d / %d  ·  %d min" % [Game.level, Game.xp, Game.magazines.size(), Game.MAGAZINES.size(), int(Game.play_time / 60.0)]
	await hud.card(["AFTERBLOOM", "To be continued...", "", stats], 5.0, [72, 26, 10, 20]).finished
	await hud.card(["Larkhaven is yours to explore.", "Day turns to night. The weather turns. Tuppence is with you."], 3.0, [32, 22]).finished
	hud.fade(0.0, 2.0)
	unlock()
	Game.save_game("free")


func free_roam() -> void:
	Game.set_flag("free")
	if world.sky:
		world.sky.set("auto_weather", true)
		world.sky.set("time_paused", false)
	_explore_music()
	if not _combat:
		_combat_watch()
	# a few roaming creatures keep the world dangerous
	var spots := [Vector3(-60, 0, 60), Vector3(40, 0, 40), Vector3(-110, 0, -60), Vector3(100, 0, -20)]
	for s in spots:
		_ambush("husk" if randf() < 0.6 else "mite", [s, s + Vector3(3, 0, 2)], s, 25.0)
	while is_instance_valid(world):
		await wait(30.0)
		if is_instance_valid(world) and player:
			Game.game_hour = float(world.sky.get("time_of_day")) if world.sky else 12.0


# ======================================================================== shared ch4 systems

func _companion_barks() -> void:
	var lines := ["tp_c1", "tp_c8", "tp_c14", "tp_c2"]
	var i := 0
	while is_instance_valid(tup) and is_instance_valid(world):
		await wait(randf_range(35.0, 60.0))
		if not is_instance_valid(tup) or _combat or Game.input_locked > 0:
			continue
		if Game.hp < Game.max_hp() * 0.4:
			tup.bark("tp_c9")
		elif world.sky and float(world.sky.call("darkness")) > 0.6:
			tup.bark("tp_c10")
		elif world.sky and String(world.sky.get("weather")) == "rain":
			tup.bark("tp_c11")
		elif i < lines.size():
			tup.bark(lines[i])
			i += 1
		if near(world.town.call("spot", "cd_post"), 20.0) and Game.count("rifle") == 0:
			tup.bark("tp_c18")


func _explore_music() -> void:
	if _combat:
		return
	var night := world.sky != null and float(world.sky.call("darkness")) > 0.5
	_music_explore = "explore_night_loop" if night else ["explore_day_loop", "explore_day2_loop"][randi() % 2]
	Audio.music(_music_explore, 4.0, -4.0)


func _combat_watch() -> void:
	while is_instance_valid(world):
		await wait(0.5)
		if Audio.music_name() == "boss_loop":
			continue
		var any := false
		for e in get_tree().get_nodes_in_group("enemies"):
			if e.get("aggro") and e.get("alive"):
				any = true
				break
		if any and not _combat:
			_combat = true
			Audio.music("combat_loop", 1.0, -2.0)
		elif not any and _combat:
			_combat = false
			await wait(3.0)
			_explore_music()


## Dormant enemies that rise when the player comes within r of trigger.
func _ambush(kind: String, at: Array, trigger: Vector3, r: float) -> void:
	var list := []
	for p in at:
		var pp: Vector3 = p
		pp.y = Layout.height(pp.x, pp.z) + 0.1
		var e := Enemy.spawn(world, kind, pp, player, true, randi() % 3)
		list.append(e)
		_enemies.append(e)
	trigger.y = Layout.height(trigger.x, trigger.z)
	await until(func(): return not is_instance_valid(world) or near(trigger, r))
	for e in list:
		if is_instance_valid(e):
			e.wake(true)
			await wait(randf_range(0.2, 0.6))


func _ambush_now(kind: String, at: Array) -> Array:
	var list := []
	for p in at:
		var pp: Vector3 = p
		pp.y = Layout.height(pp.x, pp.z) + 0.1
		var e := Enemy.spawn(world, kind, pp, player, true, randi() % 3)
		list.append(e)
		_enemies.append(e)
	_wake_list(list)
	return list


func _wake_list(list: Array) -> void:
	for e in list:
		if is_instance_valid(e):
			e.wake(true)
			await wait(randf_range(0.3, 0.8))


func _cd_locker() -> void:
	var town := world.town
	await town.cd_locker.used
	town.cd_locker.enabled = false
	Audio.sfx("door_open", -4.0)
	Game.add_item("rifle", 1)
	Game.add_item("ammo_30", 20)
	Game.objective_done(Q_RIFLE, "locker")
	Game.quest_complete(Q_RIFLE, 40)
	Game.tracked_quest = Q_MAIN
	Game.quests_changed.emit()
	hud.banner("BOLT-ACTION RIFLE", "[2] Equip   ·   [RMB] Scope", 4.0)


func _place_world_loot() -> void:
	var town := world.town
	var sq: Vector3 = town.call("spot", "square")
	var mags := [
		["pantry", (town.call("spot", "diner") as Vector3) + Vector3(0, 1.0, -1.5)],
		["steady_hand", (town.call("spot", "cd_post") as Vector3) + Vector3(2.0, 1.02, -3.0)],
		["detective", (town.call("spot", "showroom") as Vector3) + Vector3(1.0, 1.02, 3.5)],
		["lighthouse", (town.call("spot", "pier") as Vector3) + Vector3(-6, 0.1, 0)],
		["outdoorsman", Vector3(-118, 0, -205)],
	]
	for m in mags:
		if Game.magazines.has(m[0]):
			continue
		var p: Vector3 = m[1]
		if p.y < 1.0:
			p.y = Layout.height(p.x, p.z) + 0.05
		Pickup.spawn_magazine(world, p, m[0], randf() * 360.0)
	if not Game.magazines.has("tinker"):
		Pickup.spawn_magazine(world, world.home.global_transform * Vector3(-4.7, Home.FLOOR_Y + 0.79, -4.35), "tinker", -10.0)
	var loot := [["ammo_38", 10, Vector3(30, 0, 6)], ["pep_tonic", 1, Vector3(-20, 0, 50)], ["sardines", 2, sq + Vector3(10, 0.8, -6)], ["ammo_38", 12, sq + Vector3(-12, 0, 6)], ["scrip", 40, Vector3(-60, 0, 100)], ["binoculars", 1, Vector3(-100, 0, -60)], ["ammo_30", 6, Vector3(-110, 0, -150)], ["pep_tonic", 1, Vector3(-125, 0, -230)], ["lighter", 1, Vector3(60, 0, 8)], ["cassette", 1, sq + Vector3(-15, 0, -14)]]
	for l in loot:
		var p2: Vector3 = l[2]
		if p2.y < 0.5:
			p2.y = Layout.height(p2.x, p2.z) + 0.05
		Pickup.spawn_item(world, p2, l[0], l[1], {"ammo_38": "ammo_box", "ammo_30": "ammo_box", "pep_tonic": "", "sardines": "long_life_food", "binoculars": "binoculars", "lighter": "vintage_lighter", "cassette": "cassette_player"}.get(l[0], ""), {"ammo_38": "ammo_box", "ammo_30": "ammo_box", "sardines": "long_life_food_sardines"}.get(l[0], ""))
