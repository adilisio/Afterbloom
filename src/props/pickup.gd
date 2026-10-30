class_name Pickup
extends Node3D
## A world item the player can take: inventory items, ammo, weapons, magazines, notes.
## kind: "item" | "magazine" | "note"

signal taken

var kind := "item"
var item_id := ""
var amount := 1
var xp := 5
var note_texture := ""
var note_title := ""
var use: Interactable
var glint := true


static func spawn_item(parent: Node, pos: Vector3, id: String, n := 1, model := "", pick := "", rot := 0.0) -> Pickup:
	var p := Pickup.new()
	p.kind = "item"
	p.item_id = id
	p.amount = n
	parent.add_child(p)
	p.global_position = pos
	p.rotation.y = rot
	p._model(model, pick)
	var title := Game.item_name(id) + (" (%d)" % n if n > 1 else "")
	p.use = Interactable.make(p, Vector3(0, 0.1, 0), Vector3(0.45, 0.35, 0.45), "Take", title)
	p.use.used.connect(p._take)
	return p


static func spawn_magazine(parent: Node, pos: Vector3, mag_id: String, rot := 0.0) -> Pickup:
	var p := Pickup.new()
	p.kind = "magazine"
	p.item_id = mag_id
	parent.add_child(p)
	p.global_position = pos
	p.rotation.y = rot
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.21, 0.006, 0.28)
	mi.mesh = bm
	var m := Mats.gen("mag_" + mag_id, 0.55).duplicate() as StandardMaterial3D
	m.uv1_scale = Vector3(1, 1, 1)
	mi.material_override = m
	p.add_child(mi)
	# cover quad on top with correct orientation
	var cover := Geo.decal_quad(p, Vector3(0, 0.0035, 0), Vector2(0.21, 0.28), Mats.gen("mag_" + mag_id, 0.55), Vector3(-PI * 0.5, 0, 0))
	cover.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var title: String = Game.MAGAZINES[mag_id].title
	p.use = Interactable.make(p, Vector3(0, 0.05, 0), Vector3(0.4, 0.2, 0.45), "Read", title)
	p.use.used.connect(p._take)
	return p


static func spawn_note(parent: Node, pos: Vector3, tex: String, title: String, item := "", rot := 0.0) -> Pickup:
	var p := Pickup.new()
	p.kind = "note"
	p.item_id = item
	p.note_texture = tex
	p.note_title = title
	parent.add_child(p)
	p.global_position = pos
	p.rotation.y = rot
	var q := Geo.decal_quad(p, Vector3(0, 0.003, 0), Vector2(0.2, 0.26), Mats.gen(tex, 0.9), Vector3(-PI * 0.5, 0, 0))
	q.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.use = Interactable.make(p, Vector3(0, 0.05, 0), Vector3(0.4, 0.2, 0.45), "Read", title)
	p.use.used.connect(p._take)
	return p


func _model(model: String, pick: String) -> void:
	if model != "" and Props.exists(model):
		var opts := {"collide": false}
		if pick != "":
			opts.pick = pick
		Props.spawn(self, model, Vector3.ZERO, 0.0, opts)
	else:
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.12, 0.08, 0.08)
		mi.mesh = bm
		mi.material_override = Mats.color(Color(0.5, 0.45, 0.35), 0.6, 0.3)
		mi.position.y = 0.04
		add_child(mi)


func _take() -> void:
	match kind:
		"item":
			Game.add_item(item_id, amount)
			if item_id == "pistol" or item_id == "rifle":
				Game.add_xp(20, "Weapon")
			else:
				Game.add_xp(xp, "Pickup")
		"magazine":
			Audio.sfx("pickup_magazine", -4.0)
			Game.add_magazine(item_id)
			var mag: Dictionary = Game.MAGAZINES[item_id]
			Reader.show_doc("mag_" + item_id, mag.title, "Perk gained:  " + mag.perk, true)
		"note":
			Audio.sfx("page_turn", -4.0)
			if item_id != "":
				Game.add_item(item_id, 1, true)
			Reader.show_doc(note_texture, note_title, "")
	taken.emit()
	queue_free()
