extends CharacterBody3D

@onready var nav_agent:NavigationAgent3D = $NavigationAgent3D
@onready var audio_stream:AudioStreamPlayer3D = $AudioStreamPlayer3D

@onready var start_pos:Vector3 = position

func _ready():
	set_physics_process(false)
	await get_tree().physics_frame
	await get_tree().physics_frame
	set_physics_process(true)
	nav_agent.target_position = %Clams.position

func _physics_process(delta):
	nav_agent.target_position = %Clams.position
	
	var destination = nav_agent.get_next_path_position()
	var local_destination = destination - global_position
	var direction = local_destination.normalized()
	
	velocity = direction * 7.25
	move_and_slide()

func update_position():
	audio_stream.play()
	$VineBoomTimer.start(randf_range(0.5, 1.5))

func die():
	audio_stream.play()
	position = start_pos
