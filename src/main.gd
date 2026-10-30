extends Node3D
## Scene root. Owns the World, Player, HUD, Dialogue, Reader, menus, and runs the story chapters.

var world: World
var player: Player
var hud: Hud
var dialogue: Dialogue
var reader: Reader
var story: Node
var menu: Node
var journal: Node
var _in_game := false


func _ready() -> void:
	hud = Hud.new()
	add_child(hud)
	dialogue = Dialogue.new()
	dialogue.hud = hud
	add_child(dialogue)
	reader = Reader.new()
	add_child(reader)
	if ResourceLoader.exists("res://src/ui/journal.gd"):
		journal = (load("res://src/ui/journal.gd") as GDScript).new()
		add_child(journal)
	if Game.shot_args.has("probe"):
		add_child((load("res://src/debug/probe.gd") as GDScript).new())
	if not Game.shot_args.is_empty() and Game.shot_args.has("shot") and Game.shot_args.shot != "title":
		_run_shot(Game.shot_args.shot)
		return
	if Game.shot_args.get("shot", "") == "title":
		_run_shot("title")
	if ResourceLoader.exists("res://src/ui/menu.gd"):
		menu = (load("res://src/ui/menu.gd") as GDScript).new()
		add_child(menu)
		menu.call("show_title")
	else:
		new_game()


# ------------------------------------------------------------------ world management

func make_world(era: String, parts := ["terrain", "home", "town", "shelter", "ocean"]) -> World:
	if world:
		world.queue_free()
	var was := hud._fade.color.a
	hud.set_fade(1.0)
	hud.loading(true, era)
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	if player:
		player.queue_free()
		player = null
	world = World.new()
	world.name = "World"
	add_child(world)
	world.build(era, parts)
	player = Player.new()
	player.name = "Player"
	world.add_child(player)
	world.player = player
	hud.player = player
	dialogue.player = player
	world.follow(player.cam)
	player.died.connect(_on_player_died)
	player.weapons.hit_confirmed.connect(hud.hitmarker)
	# let shaders compile behind the loading screen
	for i in 4:
		await get_tree().process_frame
	hud.loading(false, era)
	hud.set_fade(was)
	return world


func _physics_process(_delta: float) -> void:
	if player == null or world == null:
		return
	var inside := 0.0
	if world.home and world.home.indoor_area.overlaps_body(player):
		inside = 1.0
	if world.shelter and world.shelter.has_method("contains") and world.shelter.call("contains", player.global_position):
		inside = 1.0
	if inside != player.indoors:
		player.indoors = inside
		world.set_interior(inside)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and _in_game and not Reader.is_open():
		if menu and menu.has_method("toggle_pause"):
			menu.call("toggle_pause")
	if event is InputEventMouseButton and event.pressed and _in_game and not get_tree().paused and Game.input_locked == 0:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


# ------------------------------------------------------------------ game flow

func new_game() -> void:
	Game.reset_state()
	_in_game = true
	_start_story("ch1")


func continue_game() -> void:
	if not Game.load_game():
		new_game()
		return
	_in_game = true
	_start_story(Game.checkpoint if Game.checkpoint != "" else "ch1")


func _start_story(cp: String) -> void:
	if story:
		story.queue_free()
	story = (load("res://src/story/story.gd") as GDScript).new()
	story.name = "Story"
	add_child(story)
	story.set("main", self)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	story.call("run", cp)


func quit_to_title() -> void:
	_in_game = false
	get_tree().paused = false
	Engine.time_scale = 1.0
	Audio.stop_all()
	if story:
		story.queue_free()
		story = null
	if world:
		world.queue_free()
		world = null
	player = null
	hud.player = null
	Game.input_locked = 0
	if menu:
		menu.call("show_title")


func _on_player_died() -> void:
	Game.input_locked += 1
	Engine.time_scale = 0.35
	Audio.music("", 1.0)
	hud.fade(1.0, 1.2, Color(0.12, 0.0, 0.0))
	await get_tree().create_timer(1.2 * 0.35).timeout
	Engine.time_scale = 1.0
	await hud.card(["You have fallen.", "Tuppence would be terribly upset."], 2.0).finished
	Game.input_locked = 0
	if Game.load_game():
		_start_story(Game.checkpoint)
	else:
		new_game()


# ------------------------------------------------------------------ screenshot harness

const SHOTS := {
	"home_living": {"era": "before", "spot": "living", "yaw": 180.0, "pitch": -8.0, "hour": 8.8},
	"home_living2": {"era": "before", "spot": "sofa", "yaw": 0.0, "pitch": -6.0, "hour": 8.8},
	"home_kitchen": {"era": "before", "spot": "table", "yaw": -60.0, "pitch": -8.0, "hour": 8.8},
	"home_bedroom": {"era": "before", "spot": "bedroom", "yaw": 150.0, "pitch": -10.0, "hour": 8.8},
	"home_fire": {"era": "before", "spot": "living", "yaw": 90.0, "pitch": -5.0, "hour": 8.8},
	"home_front": {"era": "before", "pos": Vector3(10, 0, 4), "yaw": 35.0, "pitch": -8.0, "hour": 9.0},
	"home_after": {"era": "after", "spot": "living", "yaw": 180.0, "pitch": -8.0, "hour": 14.0},
	"street": {"era": "before", "pos": Vector3(30, 7.5, 2), "yaw": 90.0, "pitch": -3.0, "hour": 9.0},
	"street_after": {"era": "after", "pos": Vector3(30, 7.5, 2), "yaw": 90.0, "pitch": -3.0, "hour": 15.0},
	"square": {"era": "after", "pos": Vector3(-30, 8, 115), "yaw": 70.0, "pitch": -3.0, "hour": 15.0},
	"bluff": {"era": "before", "pos": Vector3(120, 30, -60), "yaw": 270.0, "pitch": -12.0, "hour": 9.0},
	"portal": {"era": "after", "pos": Vector3(150, 0, -95), "yaw": -90.0, "pitch": 3.0, "hour": 12.0},
	"shelter": {"era": "after", "pos": Vector3(200, 19, -95), "yaw": -90.0, "pitch": 0.0, "hour": 12.0},
	"lighthouse": {"era": "after", "pos": Vector3(-118, 0, -232), "yaw": 55.0, "pitch": 6.0, "hour": 17.6},
	"exit_view": {"era": "after", "pos": Vector3(168, 26.2, -95), "yaw": 90.0, "pitch": -4.0, "hour": 8.5},
	"night_street": {"era": "after", "pos": Vector3(-20, 0, 20), "yaw": 180.0, "pitch": 2.0, "hour": 22.0},
	"kitchen_after": {"era": "after", "spot": "table", "yaw": -60.0, "pitch": -8.0, "hour": 14.0},
	"gun": {"era": "before", "spot": "living", "yaw": 180.0, "pitch": 0.0, "hour": 9.0, "gun": "pistol"},
	"rifle": {"era": "before", "spot": "living", "yaw": 180.0, "pitch": 0.0, "hour": 9.0, "gun": "rifle"},
}


func _run_shot(names_csv: String) -> void:
	var names := names_csv.split(",")
	var delay := float(Game.shot_args.get("shot-time", "4"))
	if Game.shot_args.has("story"):
		_in_game = true
		if Game.shot_args.has("load"):
			Game.load_game()
		Game.set_flag("god")
		_start_story(Game.shot_args.story)
		var times: Array = Array(String(Game.shot_args.get("times", str(delay))).split(","))
		var prev := 0.0
		for t in times:
			var tt := float(t)
			await ShotUtil.capture(get_tree(), "shots/%s_%03d.png" % [Game.shot_args.get("shot-out", "story"), int(tt)], tt - prev, false)
			prev = tt
		get_tree().quit()
		return
	if names[0] == "title":
		await get_tree().create_timer(3.0).timeout
		await ShotUtil.capture(get_tree(), "shots/title.png", 0.5, true)
		return
	var cur_era := ""
	for name in names:
		var sc: Dictionary = SHOTS.get(name, SHOTS.home_living)
		if sc.era != cur_era:
			cur_era = sc.era
			await make_world(sc.era)
			if world.home and world.home.tv:
				world.home.tv.start("morning" if world.era == "before" else "static")
		world.set_time(float(Game.shot_args.get("hour", sc.hour)))
		if Game.shot_args.has("weather"):
			world.set_weather(Game.shot_args.weather, 0.0)
		var pos: Vector3
		if sc.has("spot") and world.home:
			pos = world.home.spot(sc.spot)
		else:
			pos = sc.pos
			pos.y = maxf(pos.y, Layout.height(pos.x, pos.z) + 0.1)
		player.teleport(pos, sc.yaw)
		player.set_look(sc.yaw, sc.pitch)
		if sc.has("gun"):
			Game.add_item(sc.gun, 1, true)
			Game.add_item("ammo_38", 20, true)
			player.weapons.call("equip", sc.gun)
		await ShotUtil.capture(get_tree(), "shots/%s.png" % name, delay, false)
		if Game.shot_args.has("perf"):
			var f0 := Engine.get_frames_drawn()
			var t0 := Time.get_ticks_msec()
			await get_tree().create_timer(4.0).timeout
			print("[perf] %s fps=%.1f drawn=%d in %dms  draws=%d prims=%d objs=%d" % [name, Engine.get_frames_per_second(), Engine.get_frames_drawn() - f0, Time.get_ticks_msec() - t0, Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME), Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)])
		if sc.has("gun"):
			var w: Node = player.weapons
			print("[dbg] isproc=", w.is_processing(), " canproc=", w.can_process(), " intree=", w.is_inside_tree(), " paused=", get_tree().paused, " ts=", Engine.time_scale, " frames=", Engine.get_process_frames(), " current=", w.current, " switching=", w.get("_switching"), " rig=", w.get("_rig"), " rot=", (w.get("_rig") as Node3D).rotation if w.get("_rig") else null, " pos=", (w.get("_rig") as Node3D).position if w.get("_rig") else null)
	get_tree().quit()
