extends Node
## Global game state: settings, input map, story flags, inventory, quests, XP/levels, perks, saves.

signal item_added(id: String, count: int)
signal xp_gained(amount: int, total: int)
signal leveled_up(level: int)
signal quests_changed
signal quest_event(kind: String, title: String)  # "start", "done", "update"
signal hp_changed(hp: float, max_hp: float)
signal settings_changed
signal toast(text: String)
signal location_discovered(name: String)

const SAVE_PATH := "user://save.json"
const SETTINGS_PATH := "user://settings.json"
const ADDR_WORDS := {"sir": "sir", "maam": "ma'am", "boss": "boss", "captain": "captain"}
const XP_LEVELS := [0, 100, 250, 450, 700, 1000, 1400, 1900, 2500]

const ITEMS := {
	"pep_tonic": {"name": "Halcyon Pep Tonic", "cat": "aid", "heal": 45.0, "desc": "\"For the Get-Up-and-Go in You!\" Restores 45 health."},
	"sardines": {"name": "Sea Biscuit Sardines", "cat": "aid", "heal": 15.0, "desc": "Still good. Probably. Restores 15 health."},
	"beans": {"name": "Gull Brand Pork & Beans", "cat": "aid", "heal": 20.0, "desc": "A can of beans. Restores 20 health."},
	"tea": {"name": "Tuppence's Tea", "cat": "aid", "heal": 30.0, "desc": "Milk, no sugar, stirred clockwise. Restores 30 health."},
	"ammo_38": {"name": ".38 Rounds", "cat": "ammo", "desc": "Halcyon Defense .38 cartridges for the service pistol."},
	"ammo_30": {"name": ".30 Rounds", "cat": "ammo", "desc": "Marksman .30 cartridges for the bolt-action rifle."},
	"scrip": {"name": "Halcyon Scrip", "cat": "junk", "desc": "Company money. Some folks still take it."},
	"pocket_watch": {"name": "Pocket Watch", "cat": "junk", "desc": "Stopped at 9:52."},
	"lighter": {"name": "Brass Lighter", "cat": "junk", "desc": "Engraved: 'To R., love M.'"},
	"spectacles": {"name": "Round Spectacles", "cat": "junk", "desc": "Someone's reading glasses."},
	"binoculars": {"name": "Binoculars", "cat": "junk", "desc": "Good for spotting comets."},
	"cassette": {"name": "Cassette Player", "cat": "junk", "desc": "A tape still inside: 'Rosa Dean - Live'."},
	"fuse": {"name": "Heavy Fuse", "cat": "key", "desc": "A Halcyon 400-amp cartridge fuse."},
	"cd_key": {"name": "Civil Defense Key", "cat": "key", "desc": "Opens the weapons locker at the Civil Defense post."},
	"pistol": {"name": "Service Pistol", "cat": "weapon", "desc": ".38 service pistol. 8 rounds. Reliable."},
	"rifle": {"name": "Bolt-Action Rifle", "cat": "weapon", "desc": ".30 bolt-action rifle with a scope. 5 rounds. Hits hard."},
	"pocket_radio": {"name": "Halcyon Pocket Transistor", "cat": "key", "desc": "Your old pocket radio. Tuppence kept the batteries fresh. Press T to toggle."},
	"june_note": {"name": "June's Note", "cat": "key", "desc": "\"They said we couldn't wake you. We tried for days. We're going to the lighthouse - Rory's radio. Follow the music. I'll leave the light on. - J.\""},
	"reg_card": {"name": "Shelter Registration Card", "cat": "key", "desc": "Halcyon Assured Shelter No. 9. Resident #31."},
}

const MAGAZINES := {
	"steady_hand": {"title": "Steady Hand Sportsman", "perk": "Recoil -35%."},
	"tinker": {"title": "Tinker & Spanner", "perk": "Tuppence's zapper does +60% damage."},
	"pantry": {"title": "Gentleman's Pantry", "perk": "Food and drink heal +50%."},
	"astounding": {"title": "Astounding Tomorrow", "perk": "Slowly heal when out of danger."},
	"outdoorsman": {"title": "Outdoorsman's Almanac", "perk": "Sprint speed +12%."},
	"hearth": {"title": "Halcyon Home & Hearth", "perk": "Max health +20."},
	"detective": {"title": "Pulp Detective Weekly", "perk": "Headshots deal +50% damage."},
	"lighthouse": {"title": "Coastal Keeper", "perk": "Gain 15% more experience."},
}

const TRAITS := {
	"keen": {"name": "Keen Eyes", "desc": "Headshots deal +20% damage."},
	"hardy": {"name": "Hardy", "desc": "Max health +15."},
	"sentimental": {"name": "Sentimental", "desc": "Gain 10% more experience."},
	"neighborly": {"name": "Good Neighbour", "desc": "Tuppence's zapper recharges 30% faster."},
	"selfreliant": {"name": "Self-Reliant", "desc": "Weapon damage +10%."},
	"pragmatist": {"name": "Pragmatist", "desc": "Food heals +30%."},
	"optimist": {"name": "Optimist", "desc": "Slowly heal when out of danger."},
	"steady": {"name": "Steady", "desc": "Reload speed +20%."},
	"loyalist": {"name": "Company Loyalist", "desc": "Tuppence's zapper does +30% damage."},
}

var settings := {
	"mouse_sens": 0.12, "fov": 78.0, "vol_master": 0.9, "vol_music": 0.65, "vol_sfx": 0.9,
	"vol_voice": 1.0, "quality": 2, "fullscreen": true, "subtitles": true, "invert_y": false,
	"crouch_toggle": true,
}

var addr := "sir"
var flags := {}
var inventory := {}
var traits: Array[String] = []
var magazines: Array[String] = []
var discovered: Array[String] = []
var xp := 0
var level := 1
var hp := 100.0
var _hurt_at := -999.0  # play_time of the last damage taken (out-of-danger healing)
var checkpoint := ""
var quests: Array[Dictionary] = []  # {id, title, done, objectives:[{id,text,done,optional}], target}
var tracked_quest := ""
var game_hour := 8.6
var play_time := 0.0

var lines := {}  # id -> {who, text}
var shot_args := {}
var input_locked := 0  # >0 while a cinematic/dialogue owns input


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_input()
	_load_lines()
	load_settings()
	_parse_args()
	Layout.ensure_cache()
	_preload_assets()


## Start background loading of every model and texture so building the world later is fast.
func _preload_assets() -> void:
	var paths: Array[String] = []
	for d in DirAccess.get_directories_at("res://assets/models"):
		for f in DirAccess.get_files_at("res://assets/models/" + d):
			f = f.trim_suffix(".import")
			if f.ends_with(".gltf"):
				paths.append("res://assets/models/%s/%s" % [d, f])
	for d in DirAccess.get_directories_at("res://assets/textures"):
		for f in DirAccess.get_files_at("res://assets/textures/" + d):
			f = f.trim_suffix(".import")
			if f.ends_with(".jpg") or f.ends_with(".png"):
				paths.append("res://assets/textures/%s/%s" % [d, f])
	for p in paths:
		if ResourceLoader.exists(p):
			ResourceLoader.load_threaded_request(p, "", true)


func _process(delta: float) -> void:
	if not get_tree().paused:
		play_time += delta
		var regen := (0.8 if magazines.has("astounding") else 0.0) + (0.5 if traits.has("optimist") else 0.0)
		if regen > 0.0 and hp > 0.0 and hp < max_hp() and play_time - _hurt_at > 6.0:
			heal_hp(regen * delta)


# ---------------------------------------------------------------- input

func _setup_input() -> void:
	var keys := {
		"move_forward": [KEY_W, KEY_UP], "move_back": [KEY_S, KEY_DOWN], "move_left": [KEY_A, KEY_LEFT],
		"move_right": [KEY_D, KEY_RIGHT], "jump": [KEY_SPACE], "sprint": [KEY_SHIFT], "crouch": [KEY_CTRL, KEY_C],
		"interact": [KEY_E], "reload": [KEY_R], "flashlight": [KEY_F], "journal": [KEY_TAB, KEY_I],
		"radio": [KEY_T], "weapon_1": [KEY_1], "weapon_2": [KEY_2], "holster": [KEY_H], "pause": [KEY_ESCAPE],
		"choice_1": [KEY_1], "choice_2": [KEY_2], "choice_3": [KEY_3], "choice_4": [KEY_4], "use_aid": [KEY_X],
		"execute": [KEY_SPACE, KEY_ENTER],
	}
	for action: String in keys:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for k: int in keys[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = k
			InputMap.action_add_event(action, ev)
	var mouse := {"fire": MOUSE_BUTTON_LEFT, "aim": MOUSE_BUTTON_RIGHT}
	for action: String in mouse:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		var mb := InputEventMouseButton.new()
		mb.button_index = mouse[action]
		InputMap.action_add_event(action, mb)


# ---------------------------------------------------------------- lines

func _load_lines() -> void:
	var f := FileAccess.open("res://data/lines.txt", FileAccess.READ)
	if f == null:
		return
	while not f.eof_reached():
		var raw := f.get_line().strip_edges()
		if raw == "" or raw.begins_with("#"):
			continue
		var parts := raw.split("|", true, 2)
		if parts.size() < 3:
			continue
		lines[parts[0].strip_edges()] = {"who": parts[1].strip_edges(), "text": parts[2].strip_edges()}


func line_text(id: String) -> String:
	if not lines.has(id):
		return id
	var w: String = ADDR_WORDS.get(addr, "sir")
	return String(lines[id].text).replace("{addr}", w).replace("{Addr}", w.capitalize() if w != "ma'am" else "Ma'am")


func line_speaker(id: String) -> String:
	return lines[id].who if lines.has(id) else ""


func voice_path(id: String) -> String:
	var p := "res://assets/audio/voice/%s.mp3" % id
	if ResourceLoader.exists(p):
		return p
	p = "res://assets/audio/voice/%s__%s.mp3" % [id, addr]
	return p if ResourceLoader.exists(p) else ""


# ---------------------------------------------------------------- flags / items

func flag(name: String) -> bool:
	return bool(flags.get(name, false))


func set_flag(name: String, value: Variant = true) -> void:
	flags[name] = value


func count(id: String) -> int:
	return int(inventory.get(id, 0))


func add_item(id: String, n := 1, quiet := false) -> void:
	inventory[id] = count(id) + n
	if not quiet:
		item_added.emit(id, n)


func remove_item(id: String, n := 1) -> bool:
	if count(id) < n:
		return false
	inventory[id] = count(id) - n
	if inventory[id] <= 0:
		inventory.erase(id)
	return true


func item_name(id: String) -> String:
	return ITEMS[id].name if ITEMS.has(id) else id.capitalize()


func use_aid(id: String) -> bool:
	if not ITEMS.has(id) or ITEMS[id].cat != "aid" or count(id) <= 0 or hp >= max_hp():
		return false
	var heal: float = ITEMS[id].heal
	if id != "pep_tonic":
		heal *= (1.5 if magazines.has("pantry") else 1.0) * (1.3 if traits.has("pragmatist") else 1.0)
	remove_item(id)
	heal_hp(heal)
	Audio.sfx("heal" if id == "pep_tonic" or id == "tea" else "eat")
	return true


func best_aid() -> String:
	for id in ["pep_tonic", "tea", "beans", "sardines"]:
		if count(id) > 0:
			return id
	return ""


func add_magazine(id: String) -> void:
	if magazines.has(id):
		return
	magazines.append(id)
	if id == "hearth":
		heal_hp(20.0)
	add_xp(25, "Magazine")


func add_trait(id: String) -> void:
	if not traits.has(id):
		traits.append(id)
	hp_changed.emit(hp, max_hp())


# ---------------------------------------------------------------- stats

func max_hp() -> float:
	return 100.0 + 10.0 * (level - 1) + (15.0 if traits.has("hardy") else 0.0) + (20.0 if magazines.has("hearth") else 0.0)


func heal_hp(amount: float) -> void:
	hp = minf(hp + amount, max_hp())
	hp_changed.emit(hp, max_hp())


func damage_hp(amount: float) -> void:
	hp = maxf(hp - amount, 0.0)
	_hurt_at = play_time
	hp_changed.emit(hp, max_hp())


func add_xp(amount: int, _reason := "") -> void:
	var mult := 1.0 + (0.15 if magazines.has("lighthouse") else 0.0) + (0.1 if traits.has("sentimental") else 0.0)
	var gained := int(round(amount * mult))
	xp += gained
	xp_gained.emit(gained, xp)
	while level < XP_LEVELS.size() and xp >= XP_LEVELS[level]:
		level += 1
		hp = max_hp()
		hp_changed.emit(hp, max_hp())
		leveled_up.emit(level)


func xp_progress() -> float:
	if level >= XP_LEVELS.size():
		return 1.0
	var a: int = XP_LEVELS[level - 1]
	var b: int = XP_LEVELS[level]
	return float(xp - a) / float(b - a)


func discover(location: String) -> void:
	if discovered.has(location):
		return
	discovered.append(location)
	add_xp(20, "Discovery")
	location_discovered.emit(location)


# ---------------------------------------------------------------- quests

func quest(id: String) -> Dictionary:
	for q in quests:
		if q.id == id:
			return q
	return {}


func quest_start(id: String, title: String, desc := "") -> void:
	if not quest(id).is_empty():
		return
	quests.append({"id": id, "title": title, "desc": desc, "done": false, "objectives": []})
	tracked_quest = id
	quest_event.emit("start", title)
	quests_changed.emit()


## Adds/replaces the active objective. target: Node3D or Vector3 or null.
func objective(quest_id: String, obj_id: String, text: String, target: Variant = null, optional := false) -> void:
	var q := quest(quest_id)
	if q.is_empty():
		return
	for o in q.objectives:
		if o.id == obj_id:
			o.text = text
			o.target = target
			quests_changed.emit()
			return
	q.objectives.append({"id": obj_id, "text": text, "done": false, "optional": optional, "target": target})
	if not optional:
		quest_event.emit("update", text)
	quests_changed.emit()


func objective_done(quest_id: String, obj_id: String) -> void:
	var q := quest(quest_id)
	if q.is_empty():
		return
	for o in q.objectives:
		if o.id == obj_id and not o.done:
			o.done = true
			o.target = null
			if o.optional:
				add_xp(10, "Optional")
			quests_changed.emit()


func objective_is_done(quest_id: String, obj_id: String) -> bool:
	var q := quest(quest_id)
	if q.is_empty():
		return false
	for o in q.objectives:
		if o.id == obj_id:
			return o.done
	return false


func quest_complete(id: String, xp_reward := 50) -> void:
	var q := quest(id)
	if q.is_empty() or q.done:
		return
	q.done = true
	for o in q.objectives:
		o.done = true
		o.target = null
	quest_event.emit("done", q.title)
	add_xp(xp_reward, "Quest")
	if tracked_quest == id:
		tracked_quest = ""
		for other in quests:
			if not other.done:
				tracked_quest = other.id
	quests_changed.emit()


## All active objective targets (for compass + waypoint). Returns [{pos: Vector3, label, main: bool}]
func active_targets() -> Array:
	var out := []
	for q in quests:
		if q.done:
			continue
		for o in q.objectives:
			if o.done or o.target == null:
				continue
			var p: Variant = o.target
			if p is Node3D:
				if not is_instance_valid(p) or not (p as Node3D).is_inside_tree():
					continue
				p = (p as Node3D).global_position
			out.append({"pos": p, "label": o.text, "main": q.id == tracked_quest and not o.optional})
	return out


# ---------------------------------------------------------------- settings & saves

func load_settings() -> void:
	if FileAccess.file_exists(SETTINGS_PATH):
		var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(SETTINGS_PATH))
		if d is Dictionary:
			for k: String in d:
				settings[k] = d[k]
	apply_settings()


func save_settings() -> void:
	var f := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify(settings, "  "))
	apply_settings()


func apply_settings() -> void:
	if not shot_args.is_empty():
		settings.fullscreen = false
	var win := get_window()
	if settings.fullscreen:
		win.mode = Window.MODE_FULLSCREEN
	elif win.mode == Window.MODE_FULLSCREEN or win.mode == Window.MODE_EXCLUSIVE_FULLSCREEN:
		win.mode = Window.MODE_WINDOWED
	settings_changed.emit()


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func save_game(cp: String) -> void:
	checkpoint = cp
	if not shot_args.is_empty() and not shot_args.has("allowsave"):
		return
	var q2 := []
	for q in quests:
		var qc: Dictionary = q.duplicate(true)
		for o in qc.objectives:
			o.target = null
		q2.append(qc)
	var d := {
		"checkpoint": cp, "addr": addr, "flags": flags, "inventory": inventory, "traits": traits,
		"magazines": magazines, "discovered": discovered, "xp": xp, "level": level, "hp": hp,
		"quests": q2, "tracked": tracked_quest, "hour": game_hour, "play_time": play_time,
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify(d))


func load_game() -> bool:
	if not has_save():
		return false
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if not d is Dictionary:
		return false
	reset_state()
	checkpoint = d.get("checkpoint", "")
	addr = d.get("addr", "sir")
	flags = d.get("flags", {})
	inventory = d.get("inventory", {})
	for k in inventory.keys():
		inventory[k] = int(inventory[k])
	traits.assign(d.get("traits", []))
	magazines.assign(d.get("magazines", []))
	discovered.assign(d.get("discovered", []))
	xp = int(d.get("xp", 0))
	level = int(d.get("level", 1))
	hp = float(d.get("hp", 100.0))
	quests.assign(d.get("quests", []))
	tracked_quest = d.get("tracked", "")
	game_hour = float(d.get("hour", 9.0))
	play_time = float(d.get("play_time", 0.0))
	return true


func reset_state() -> void:
	addr = "sir"
	flags = {}
	inventory = {}
	traits.clear()
	magazines.clear()
	discovered.clear()
	xp = 0
	level = 1
	hp = 100.0
	_hurt_at = -999.0
	quests.clear()
	tracked_quest = ""
	checkpoint = ""
	game_hour = 8.6
	play_time = 0.0
	input_locked = 0


# ---------------------------------------------------------------- test harness

## Command line: -- --shot=<scenario> [--shot-time=sec] [--shot-out=name]
func _parse_args() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--") and "=" in a:
			var kv := a.substr(2).split("=", true, 1)
			shot_args[kv[0]] = kv[1]
		elif a.begins_with("--"):
			shot_args[a.substr(2)] = "1"
	if not shot_args.is_empty():
		settings.fullscreen = false
