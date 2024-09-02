extends Area3D
@onready var bobbie_timer = $BobbieTimer
@onready var reset_timer = $ResetTimer

@export var time_allowed:float
@export var reset_time:float

signal timeout()
signal reset()

func bobbie_timeout():
	timeout.emit()

func body_entered(body:Node3D):
	if body.name == "Clams":
		reset_timer.stop()
		if bobbie_timer.paused:
			bobbie_timer.paused = false
			return
		bobbie_timer.start(time_allowed)

func body_exited(body:Node3D):
	if body.name == "Clams":
		bobbie_timer.paused = true
		reset_timer.start(reset_time)

func _reset():
	bobbie_timer.stop()
	bobbie_timer.paused = false
	reset.emit()
