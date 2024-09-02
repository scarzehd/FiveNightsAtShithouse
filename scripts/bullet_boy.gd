extends CharacterBody3D

@onready var nav_agent:NavigationAgent3D = $NavigationAgent3D

@onready var inactive_pos := position

@export var chance:int

@onready var hello_audio := $HelloAudio
@onready var chuckle_audio := $ChuckleAudio

var bullets := 0

var active := false

func _physics_process(delta: float) -> void:
	if not active:
		return
	
	nav_agent.target_position = get_new_target()
	
	var destination = nav_agent.get_next_path_position()
	var local_destination = destination - global_position
	var direction = local_destination.normalized()
	
	velocity = direction * 8
	move_and_slide()

func try_spawn():
	if active:
		return
	
	if randi_range(0, chance) == 0:
		activate()

func activate():
	active = true
	
	play_audio()
	
	var right_vent_distance = %RightVent.position.distance_to(%Clams.position)
	var left_vent_distance = %LeftVent.position.distance_to(%Clams.position)
	
	if right_vent_distance < left_vent_distance:
		position = %LeftVent.position
		return
	position = %RightVent.position
	
	nav_agent.target_position = get_new_target()

func deactivate():
	position = inactive_pos
	active = false
	velocity = Vector3.ZERO
	$HelloTimer.stop()
	

func die():
	position = inactive_pos
	%Clams.bullets += bullets
	deactivate()

func get_new_target() -> Vector3:
	var bullets = get_tree().get_nodes_in_group("bullet")
	
	if bullets.size() <= 0:
		return %Clams.position
	
	var closest_bullet = bullets[0]
	var min_distance := position.distance_to(bullets[0].global_position)
	for bullet in bullets:
		var distance_to_bullet = position.distance_to(bullet.global_position)
		
		if distance_to_bullet < min_distance:
			min_distance = distance_to_bullet
			closest_bullet = bullet
	
	return closest_bullet.global_position

func collect_bullet(body:Node3D):
	if body.is_in_group("bullet"):
		bullets += 1
		body.queue_free()
		chuckle_audio.play()
	
	if body == %Clams and %Clams.bullets > 0:
		%Clams.bullets -= 1
		bullets += 1
		chuckle_audio.play()
	
	if bullets >= 5:
		bullets = 0
		deactivate()
		get_tree().create_timer(0.25).timeout.connect(func(): chuckle_audio.play())

func play_audio():
	$HelloTimer.start(randf_range(0.5, 1.5))
	hello_audio.play()
