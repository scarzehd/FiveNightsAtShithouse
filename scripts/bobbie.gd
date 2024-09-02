extends CharacterBody3D

@onready var nav_agent:NavigationAgent3D = $NavigationAgent3D
@onready var audio_stream:AudioStreamPlayer3D = $AudioStreamPlayer3D

@onready var inactive_pos := position

var active = false

func _physics_process(delta):
	if active:
		nav_agent.target_position = %Clams.position
		
		var destination = nav_agent.get_next_path_position()
		var local_destination = destination - global_position
		var direction = local_destination.normalized()
		
		velocity = direction * 9
		move_and_slide()

func activate(spawn_position:Vector3):
	audio_stream.play()
	active = true
	position = spawn_position
	update_position()

func deactivate():
	position = inactive_pos
	active = false

func _on_right_vent_timeout():
	activate(%RightVent.position)

# this, along with the same method in Frebby, actually only plays the sound. I couldn't be bothered to change the name

func update_position():
	if active:
		audio_stream.play()
		$BadToTheBoneTimer.start(randf_range(0.25, 1))


func _on_vent_timeout():
	activate(%LeftVent.position)

func die():
	deactivate()
