extends Node
var n := 0
var last := 0
var t0 := 0
var maxdt := 0
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	t0 = Time.get_ticks_msec()
	last = t0
func _process(_delta: float) -> void:
	n += 1
	var now := Time.get_ticks_msec()
	maxdt = maxi(maxdt, now - last)
	last = now
	if now - t0 >= 2000:
		print("[probe] real_fps=%.1f worst_frame=%dms" % [n * 1000.0 / (now - t0), maxdt])
		n = 0
		t0 = now
		maxdt = 0
