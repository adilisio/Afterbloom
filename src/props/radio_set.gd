class_name RadioSet
extends Node3D
## Halcyon "Melody" tabletop valve radio. Plays a station in sync with every other receiver.

var station := "lfr_1967"
var on := false
var player3d: AudioStreamPlayer3D
var use: Interactable
var _dial_light: OmniLight3D
var _dial_mat: StandardMaterial3D


func build(wood: Material) -> void:
	var cream := Mats.color(Color(0.93, 0.88, 0.76), 0.45)
	var brass := Mats.color(Color(0.8, 0.62, 0.34), 0.3, 1.0)
	var grille := Mats.tex("fabric_pattern_05", 0.25, Color(0.85, 0.72, 0.52))
	Geo.box(self, Vector3(0, 0.13, 0), Vector3(0.44, 0.26, 0.2), wood, true, "wood")
	# rounded top
	var top := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.1
	cm.bottom_radius = 0.1
	cm.height = 0.44
	top.mesh = cm
	top.material_override = wood
	top.rotation.z = PI * 0.5
	top.scale = Vector3(1, 1, 1)
	top.position = Vector3(0, 0.26, 0)
	add_child(top)
	Geo.box(self, Vector3(-0.08, 0.16, 0.101), Vector3(0.24, 0.17, 0.004), grille, false)
	_dial_mat = Mats.emissive(Color(1.0, 0.75, 0.4), 0.0).duplicate()
	Geo.box(self, Vector3(0.13, 0.2, 0.101), Vector3(0.12, 0.07, 0.004), _dial_mat, false)
	Geo.box(self, Vector3(0.13, 0.2, 0.104), Vector3(0.004, 0.06, 0.002), Mats.color(Color(0.6, 0.1, 0.05)), false)
	for kx in [0.09, 0.17]:
		var k := MeshInstance3D.new()
		var km := CylinderMesh.new()
		km.top_radius = 0.018
		km.bottom_radius = 0.02
		km.height = 0.025
		k.mesh = km
		k.material_override = cream
		k.rotation.x = PI * 0.5
		k.position = Vector3(kx, 0.09, 0.11)
		add_child(k)
	Geo.box(self, Vector3(-0.08, 0.055, 0.103), Vector3(0.16, 0.022, 0.004), brass, false)
	_dial_light = OmniLight3D.new()
	_dial_light.light_color = Color(1.0, 0.7, 0.35)
	_dial_light.light_energy = 0.0
	_dial_light.omni_range = 0.8
	_dial_light.position = Vector3(0.13, 0.2, 0.2)
	add_child(_dial_light)
	player3d = AudioStreamPlayer3D.new()
	player3d.bus = "Radio"
	player3d.unit_size = 4.0
	player3d.max_db = 3.0
	player3d.position = Vector3(0, 0.15, 0.1)
	add_child(player3d)
	use = Interactable.make(self, Vector3(0, 0.15, 0), Vector3(0.5, 0.35, 0.3), "Turn On", "Halcyon Melody Radio")
	use.used.connect(func(): set_on(not on))


func set_on(o: bool, quiet := false) -> void:
	on = o
	use.verb = "Turn Off" if o else "Turn On"
	if not quiet:
		Audio.sfx_at("radio_click", global_position, -8.0, 2.0)
	_dial_mat.emission_energy_multiplier = 1.6 if o else 0.0
	_dial_light.light_energy = 0.5 if o else 0.0
	if o:
		if not quiet:
			Audio.sfx_at("radio_tune", global_position, -12.0, 2.0, 0.0, "Radio")
		Audio.radio_attach(player3d, station)
	else:
		Audio.radio_detach(player3d)


func _exit_tree() -> void:
	Audio.radio_detach(player3d)
