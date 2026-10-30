extends Node
## Audio: buses + effects, SFX (with random variants), music crossfades, voice lines + subtitles,
## ambience layers, and the always-running radio stations.

signal subtitle(who: String, text: String, duration: float)
signal radio_item_changed(station: String, title: String)

const SPEAKER_NAMES := {
	"tuppence": "Tuppence", "registrar": "Registrar 9", "june": "June", "rory": "Rory Tuck",
	"narrator": "", "dot": "Dot Calloway (Radio)", "anchor": "Hal Brightwater (TV)", "announcer": "TV",
	"pa": "Shelter PA", "civil": "Civil Defense", "warden": "Warden Haskell (Recording)",
}
const SPEAKER_BUS := {
	"tuppence": "Robot", "registrar": "Robot", "june": "Voice", "rory": "Radio", "narrator": "Voice",
	"dot": "Radio", "anchor": "TV", "announcer": "TV", "pa": "PA", "civil": "PA", "warden": "Phone",
}
const SONG_TITLES := {
	"sunday_kind_of_gentle": "Sunday Kind of Gentle - The Halcyon Strings & Lou Marten",
	"moonlight_on_gull_lane": "Moonlight on Gull Lane - Patsy Vale Quartet",
	"rocket_ride_shuffle": "Rocket Ride Shuffle - Benny Cole & the Satellites",
	"a_little_lantern": "A Little Lantern - Rosa Dean",
	"coffee_for_two": "Coffee for Two - Mel Archer Trio",
	"highway_seventeen": "Highway Seventeen - Dusty Carlyle",
}
const STATIONS := {
	"lfr_1967": [
		"v:dc_1", "s:sunday_kind_of_gentle", "v:dc_5", "s:rocket_ride_shuffle", "v:dc_3", "s:coffee_for_two",
		"v:dc_4", "s:moonlight_on_gull_lane", "v:dc_6", "s:a_little_lantern", "v:dc_2", "s:highway_seventeen",
	],
	"lfr_1978": [
		"v:rr_1", "s:a_little_lantern", "v:rr_3", "s:coffee_for_two", "v:rr_5", "s:moonlight_on_gull_lane",
		"v:rr_4", "v:rr_6", "s:sunday_kind_of_gentle", "v:rr_7", "s:rocket_ride_shuffle", "v:rr_10",
		"s:highway_seventeen", "v:rr_2", "v:rr_8",
	],
}

var _sfx_index := {}  # base name -> Array[String] paths
var _cache := {}
var _music_a: AudioStreamPlayer
var _music_b: AudioStreamPlayer
var _music_cur: AudioStreamPlayer
var _music_name := ""
var _sting: AudioStreamPlayer
var _amb := {}  # layer -> AudioStreamPlayer
var _voice_players: Array = []
var _duck := 0.0
## true while a conversation is open (Dialogue.begin..end); TV/radio duck and keep their subtitles to themselves
var conversation := false
var _fg_until := 0  # msec until the current foreground (non TV/radio) voice line ends
var _amb_duck := 0.0  # dB currently applied to the TV and Radio buses
const AMBIENT_BUSES := ["TV", "Radio"]

# radio: station id -> {items, idx, started_ms, len, stream, special:Array}
var _stations := {}
var _receivers: Array = []  # [{player, station}]


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_buses()
	_index_sfx()
	_music_a = _mk_player("Music")
	_music_b = _mk_player("Music")
	_music_cur = _music_a
	_sting = _mk_player("Music")
	for st: String in STATIONS:
		_stations[st] = {"items": STATIONS[st], "idx": -1, "started": 0, "len": 0.0, "stream": null, "special": []}
		_advance_station(st, randi() % STATIONS[st].size())
	Game.settings_changed.connect(apply_volumes)
	apply_volumes()


func _mk_player(bus: String) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = bus
	p.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(p)
	return p


# ---------------------------------------------------------------- buses

func _setup_buses() -> void:
	var defs := ["Music", "SFX", "Ambience", "Voice", "Robot", "Radio", "TV", "PA", "Phone", "Interior"]
	for b in defs:
		if AudioServer.get_bus_index(b) == -1:
			AudioServer.add_bus()
			var i := AudioServer.bus_count - 1
			AudioServer.set_bus_name(i, b)
			AudioServer.set_bus_send(i, "Master")
	var robot := AudioServer.get_bus_index("Robot")
	var eq := AudioEffectEQ6.new()
	eq.set_band_gain_db(0, -6.0)
	eq.set_band_gain_db(3, 3.0)
	eq.set_band_gain_db(4, 2.0)
	AudioServer.add_bus_effect(robot, eq)
	var ch := AudioEffectChorus.new()
	ch.voice_count = 2
	ch.dry = 0.85
	ch.wet = 0.25
	AudioServer.add_bus_effect(robot, ch)
	var rv := AudioEffectReverb.new()
	rv.room_size = 0.15
	rv.wet = 0.06
	AudioServer.add_bus_effect(robot, rv)
	_bandpass("Radio", 280.0, 4200.0, 0.18)
	_bandpass("TV", 220.0, 6500.0, 0.1)
	_bandpass("Phone", 420.0, 3200.0, 0.3)
	_bandpass("PA", 380.0, 4500.0, 0.25)
	var pa := AudioServer.get_bus_index("PA")
	var dl := AudioEffectDelay.new()
	dl.tap1_delay_ms = 180.0
	dl.tap1_level_db = -10.0
	dl.tap2_delay_ms = 390.0
	dl.tap2_level_db = -16.0
	dl.feedback_active = false
	AudioServer.add_bus_effect(pa, dl)
	var prv := AudioEffectReverb.new()
	prv.room_size = 0.85
	prv.damping = 0.3
	prv.wet = 0.35
	AudioServer.add_bus_effect(pa, prv)
	var inter := AudioServer.get_bus_index("Interior")
	AudioServer.set_bus_send(inter, "SFX")
	var irv := AudioEffectReverb.new()
	irv.room_size = 0.35
	irv.wet = 0.18
	AudioServer.add_bus_effect(inter, irv)


func _bandpass(bus: String, lo: float, hi: float, drive: float) -> void:
	var i := AudioServer.get_bus_index(bus)
	var hp := AudioEffectHighPassFilter.new()
	hp.cutoff_hz = lo
	AudioServer.add_bus_effect(i, hp)
	var lp := AudioEffectLowPassFilter.new()
	lp.cutoff_hz = hi
	AudioServer.add_bus_effect(i, lp)
	var d := AudioEffectDistortion.new()
	d.mode = AudioEffectDistortion.MODE_OVERDRIVE
	d.drive = drive
	d.post_gain = -2.0
	AudioServer.add_bus_effect(i, d)


func apply_volumes() -> void:
	var s := Game.settings
	AudioServer.set_bus_volume_db(0, linear_to_db(s.vol_master))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Music"), linear_to_db(s.vol_music))
	for b in ["SFX", "Ambience", "Interior"]:
		AudioServer.set_bus_volume_db(AudioServer.get_bus_index(b), linear_to_db(s.vol_sfx))
	for b in ["Voice", "Robot", "Radio", "TV", "PA", "Phone"]:
		AudioServer.set_bus_volume_db(AudioServer.get_bus_index(b), linear_to_db(s.vol_voice))


# ---------------------------------------------------------------- loading

func _index_sfx() -> void:
	for dir in ["res://assets/audio/sfx"]:
		if not DirAccess.dir_exists_absolute(dir):
			continue
		for f in DirAccess.get_files_at(dir):
			f = f.trim_suffix(".import").trim_suffix(".remap")
			if not f.ends_with(".ogg") and not f.ends_with(".wav"):
				continue
			var base := f.get_basename()
			var path: String = dir + "/" + f
			var key := base
			var parts := base.rsplit("_", true, 1)
			if parts.size() == 2 and parts[1].is_valid_int():
				key = parts[0]
			if not _sfx_index.has(key):
				_sfx_index[key] = []
			if not _sfx_index[key].has(path):
				_sfx_index[key].append(path)
			if key != base:
				_sfx_index[base] = [path]


func stream(path: String) -> AudioStream:
	if path == "":
		return null
	if not _cache.has(path):
		_cache[path] = load(path) if ResourceLoader.exists(path) else null
	return _cache[path]


func has_sfx(name: String) -> bool:
	return _sfx_index.has(name)


func sfx_stream(name: String) -> AudioStream:
	if not _sfx_index.has(name):
		return null
	var arr: Array = _sfx_index[name]
	return stream(arr[randi() % arr.size()])


func music_stream(name: String) -> AudioStream:
	for p in ["res://assets/audio/music/%s.ogg" % name, "res://assets/audio/music/radio/%s.ogg" % name]:
		if ResourceLoader.exists(p):
			return stream(p)
	return null


# ---------------------------------------------------------------- sfx

func sfx(name: String, vol_db := 0.0, pitch_var := 0.06, bus := "SFX") -> AudioStreamPlayer:
	var s := sfx_stream(name)
	if s == null:
		return null
	var p := AudioStreamPlayer.new()
	p.stream = s
	p.volume_db = vol_db
	p.pitch_scale = 1.0 + randf_range(-pitch_var, pitch_var)
	p.bus = bus
	add_child(p)
	p.play()
	p.finished.connect(p.queue_free)
	return p


func sfx_at(name: String, pos: Vector3, vol_db := 0.0, unit := 6.0, pitch_var := 0.06, bus := "SFX") -> AudioStreamPlayer3D:
	var s := sfx_stream(name)
	if s == null:
		return null
	var scene := get_tree().current_scene
	if scene == null:
		return null
	var p := AudioStreamPlayer3D.new()
	p.stream = s
	p.volume_db = vol_db
	p.unit_size = unit
	p.max_db = 6.0
	p.pitch_scale = 1.0 + randf_range(-pitch_var, pitch_var)
	p.bus = bus
	p.attenuation_filter_cutoff_hz = 9000.0
	scene.add_child(p)
	p.global_position = pos
	p.play()
	p.finished.connect(p.queue_free)
	return p


## Looping positional sound attached to a node. Returns the player (caller frees it).
func loop_on(node: Node3D, name: String, vol_db := 0.0, unit := 4.0, bus := "SFX") -> AudioStreamPlayer3D:
	var s := sfx_stream(name)
	var p := AudioStreamPlayer3D.new()
	p.stream = s
	p.volume_db = vol_db
	p.unit_size = unit
	p.bus = bus
	node.add_child(p)
	if s != null:
		_set_loop(s)
		p.play()
	return p


func _set_loop(s: AudioStream) -> void:
	if s is AudioStreamOggVorbis:
		(s as AudioStreamOggVorbis).loop = true
	elif s is AudioStreamMP3:
		(s as AudioStreamMP3).loop = true
	elif s is AudioStreamWAV:
		(s as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD


# ---------------------------------------------------------------- music

func music(name: String, fade := 2.0, vol_db := 0.0) -> void:
	if name == _music_name:
		return
	_music_name = name
	var old := _music_cur
	var nxt := _music_b if _music_cur == _music_a else _music_a
	_music_cur = nxt
	if old.playing:
		var tw := create_tween()
		tw.tween_property(old, "volume_db", -60.0, fade)
		tw.tween_callback(old.stop)
	if name == "":
		return
	var s := music_stream(name)
	if s == null:
		return
	if name.ends_with("_loop"):
		_set_loop(s)
	nxt.stream = s
	nxt.volume_db = -50.0
	nxt.play()
	var tw2 := create_tween()
	tw2.tween_property(nxt, "volume_db", vol_db, fade)


func music_name() -> String:
	return _music_name


func sting(name: String, vol_db := 0.0) -> void:
	var s := music_stream(name)
	if s == null:
		return
	_sting.stream = s
	_sting.volume_db = vol_db
	_sting.play()
	_duck = maxf(_duck, s.get_length())


# ---------------------------------------------------------------- voice

## Plays a voiced line. source: Node3D for positional, or null for 2D. Emits subtitle. Returns duration.
func voice(id: String, source: Node3D = null, bus := "", vol_db := 0.0, subs := true) -> float:
	var who := Game.line_speaker(id)
	var text := Game.line_text(id)
	var s := stream(Game.voice_path(id))
	var dur := 2.0 + text.length() * 0.055
	if s != null:
		dur = s.get_length()
	if bus == "":
		bus = SPEAKER_BUS.get(who, "Voice")
	if bus in AMBIENT_BUSES:
		subs = subs and not foreground_busy()
	else:
		_fg_until = maxi(_fg_until, Time.get_ticks_msec() + int(dur * 1000.0))
	if s != null:
		var p: Node
		if source != null and is_instance_valid(source):
			var p3 := AudioStreamPlayer3D.new()
			p3.stream = s
			p3.bus = bus
			p3.volume_db = vol_db + 4.0
			p3.unit_size = 5.0
			p3.max_db = 8.0
			source.add_child(p3)
			p3.play()
			p3.finished.connect(p3.queue_free)
			p = p3
		else:
			var p2 := AudioStreamPlayer.new()
			p2.stream = s
			p2.bus = bus
			p2.volume_db = vol_db
			add_child(p2)
			p2.play()
			p2.finished.connect(p2.queue_free)
			p = p2
		_voice_players.append(p)
	var name: String = SPEAKER_NAMES.get(who, who.capitalize())
	if subs:
		subtitle.emit(name, text, dur)
	_duck = maxf(_duck, dur * 0.8)
	return dur


func stop_voices() -> void:
	for p in _voice_players:
		if is_instance_valid(p):
			p.queue_free()
	_voice_players.clear()


# ---------------------------------------------------------------- ambience

func ambience(layer: String, name: String, vol_db := 0.0, fade := 3.0) -> void:
	var cur: AudioStreamPlayer = _amb.get(layer)
	if cur != null and cur.has_meta("name") and cur.get_meta("name") == name:
		create_tween().tween_property(cur, "volume_db", vol_db, fade)
		return
	if cur != null:
		var tw := create_tween()
		tw.tween_property(cur, "volume_db", -60.0, fade)
		tw.tween_callback(cur.queue_free)
		_amb.erase(layer)
	if name == "":
		return
	var s := sfx_stream(name)
	if s == null:
		return
	_set_loop(s)
	var p := _mk_player("Ambience")
	p.stream = s
	p.set_meta("name", name)
	p.volume_db = -50.0
	p.play()
	_amb[layer] = p
	create_tween().tween_property(p, "volume_db", vol_db, fade)


func ambience_volume(layer: String, vol_db: float, fade := 1.0) -> void:
	var cur: AudioStreamPlayer = _amb.get(layer)
	if cur != null:
		create_tween().tween_property(cur, "volume_db", vol_db, fade)


func stop_all() -> void:
	conversation = false
	_fg_until = 0
	music("", 0.5)
	for l in _amb.keys():
		ambience(l, "", 0.0, 0.5)
	stop_voices()
	for r in _receivers:
		if is_instance_valid(r.player):
			r.player.stop()


# ---------------------------------------------------------------- radio

func _advance_station(st: String, idx := -1) -> void:
	var d: Dictionary = _stations[st]
	var item := ""
	if not d.special.is_empty():
		item = d.special.pop_front()
	else:
		d.idx = (d.idx + 1) % d.items.size() if idx < 0 else idx
		item = d.items[d.idx]
	var s: AudioStream = null
	var title := ""
	if item.begins_with("v:"):
		s = stream(Game.voice_path(item.substr(2)))
		title = "DJ"
		d["voice_id"] = item.substr(2)
	else:
		var song := item.substr(2)
		s = music_stream(song)
		title = SONG_TITLES.get(song, song)
		d["voice_id"] = ""
	d.stream = s
	d.len = s.get_length() if s != null else 4.0
	d.started = Time.get_ticks_msec()
	d.title = title
	for r in _receivers:
		if r.station == st and is_instance_valid(r.player):
			_play_receiver(r)
	radio_item_changed.emit(st, title)


func radio_queue_special(st: String, item: String) -> void:
	_stations[st].special.append(item)


func radio_title(st: String) -> String:
	return _stations[st].get("title", "") if _stations.has(st) else ""


func _process(delta: float) -> void:
	for st: String in _stations:
		var d: Dictionary = _stations[st]
		if (Time.get_ticks_msec() - d.started) / 1000.0 >= d.len + 1.2:
			_advance_station(st)
	# duck music under voice/stingers, and fade it out near a playing radio so songs don't clash with the score
	_duck = maxf(_duck - delta, 0.0)
	var mb := AudioServer.get_bus_index("Music")
	var target := linear_to_db(Game.settings.vol_music) - (7.0 if _duck > 0.0 else 0.0) - 30.0 * _radio_presence()
	AudioServer.set_bus_volume_db(mb, lerpf(AudioServer.get_bus_volume_db(mb), target, minf(delta * 3.0, 1.0)))
	# TV and radio step back while someone is talking to you, and the TV yields to a radio you're listening to
	var amb_target := -13.0 if foreground_busy() else 0.0
	_amb_duck = lerpf(_amb_duck, amb_target, minf(delta * 4.0, 1.0))
	var vv := linear_to_db(Game.settings.vol_voice)
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Radio"), vv + _amb_duck)
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("TV"), vv + _amb_duck - 12.0 * _radio_presence())


## A character is speaking to the player (dialogue open, or a non TV/radio line still playing).
func foreground_busy() -> bool:
	return conversation or Time.get_ticks_msec() < _fg_until


## 0..1: how strongly the player can hear a radio (1 = pocket radio, or right next to a set).
func _radio_presence() -> float:
	var cam := get_viewport().get_camera_3d()
	var best := 0.0
	for r in _receivers:
		var p: Node = r.player
		if not is_instance_valid(p):  # attached = switched on, even in the gap between items
			continue
		if not p is Node3D:
			return 1.0
		if cam != null:
			var d := cam.global_position.distance_to((p as Node3D).global_position)
			best = maxf(best, 1.0 - smoothstep(4.0, 12.0, d))
	return best


func _is_near(p: Node) -> bool:
	if not p is Node3D:
		return true
	var cam := get_viewport().get_camera_3d()
	return cam != null and cam.global_position.distance_to((p as Node3D).global_position) < 9.0


## Attach a receiver (AudioStreamPlayer or AudioStreamPlayer3D) to a station; it plays in sync.
func radio_attach(player: Node, st: String) -> void:
	radio_detach(player)
	var r := {"player": player, "station": st}
	_receivers.append(r)
	_play_receiver(r)


func radio_detach(player: Node) -> void:
	for r in _receivers.duplicate():
		if r.player == player:
			_receivers.erase(r)
	if is_instance_valid(player):
		player.call("stop")


func _play_receiver(r: Dictionary) -> void:
	var d: Dictionary = _stations[r.station]
	var p: Node = r.player
	p.set("stream", d.stream)
	if d.stream == null:
		return
	var off: float = (Time.get_ticks_msec() - d.started) / 1000.0
	if off < d.len - 0.1:
		p.call("play", off)
		if d.get("voice_id", "") != "" and off < 0.5 and _is_near(p) and not foreground_busy():
			var text := Game.line_text(d.voice_id)
			subtitle.emit(SPEAKER_NAMES.get(Game.line_speaker(d.voice_id), "Radio"), text, d.len)
