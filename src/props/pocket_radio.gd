class_name PocketRadio
extends Node
## The Halcyon Pocket Transistor: toggled with T once the player owns it. Plays Larkhaven Free Radio.

signal toggled(on: bool)

var on := false
var station := "lfr_1978"
var _player: AudioStreamPlayer


func _ready() -> void:
	name = "PocketRadio"
	_player = AudioStreamPlayer.new()
	_player.bus = "Radio"
	_player.volume_db = -3.0
	add_child(_player)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("radio") and Game.count("pocket_radio") > 0 and Game.input_locked == 0:
		set_on(not on)


func set_on(o: bool) -> void:
	on = o
	Audio.sfx("radio_click", -6.0)
	if o:
		Audio.sfx("radio_tune", -12.0, 0.0, "Radio")
		Audio.radio_attach(_player, station)
		Game.toast.emit("Radio: Larkhaven Free Radio  1340 AM")
	else:
		Audio.radio_detach(_player)
	toggled.emit(o)
