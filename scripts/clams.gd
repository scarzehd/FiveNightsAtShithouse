extends CharacterBody3D

@onready var head := $Head
@onready var camera := $Head/Camera3D

const X_SENSITIVITY = 0.005
const Y_SENSITIVITY = 0.005

const MAX_SPEED = 7
const SPRINT_SPEED = 13

const ACCELERATION = 0.7
const SPRINT_ACCELERATION = 0.85
const AIR_ACCELERATION = 0

const DRAG = 0.5
const AIR_DRAG = 1

const JUMP_VELOCITY = 4.5

const MAX_BULLET_DISTANCE = 1000

var sprinting = false

var gravity = 15

var max_stamina = 8
var stamina = max_stamina
var stamina_recharge_delay = 0.5
var can_recharge_stamina = false
@onready var stamina_recharge_timer = $StaminaRechargeTimer
@onready var stamina_bar:ProgressBar = $HUD/StaminaBar

var max_bullets = 3
var bullets = 1 : 
	set(value):
		bullets = min(value, max_bullets)
		bullet_count_label.text = str(bullets) + " / " + str(max_bullets)

@onready var bullet_count_label:Label = $HUD/BulletCount

@export_flags_2d_physics var bullet_collision

func _ready():
	stamina_bar.max_value = max_stamina
	randomize()

func _unhandled_input(event:InputEvent):
	if event.is_action("sprint"):
		sprinting = event.is_pressed()
	
	if event is InputEventMouseButton and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		return
	elif event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		if event is InputEventMouseMotion:
			head.rotate_y(-event.relative.x * X_SENSITIVITY)
			camera.rotate_x(-event.relative.y * Y_SENSITIVITY)
			camera.rotation.x = clamp(camera.rotation.x, deg_to_rad(-90), deg_to_rad(90))
		
		if event.is_action_pressed("shoot"):
			shoot()


func _process(delta):
	if sprinting:
		stamina -= delta
		stamina_recharge_timer.stop()
		can_recharge_stamina = false
	elif stamina < max_stamina and stamina_recharge_timer.is_stopped():
		stamina_recharge_timer.start(stamina_recharge_delay)
	
	if stamina <= 0:
		sprinting = false
	
	if can_recharge_stamina:
		stamina = min(stamina + delta * 2, max_stamina)
	
	stamina_bar.value = stamina

func recharge_stamina():
	can_recharge_stamina = true

func _physics_process(delta):
	## Get current phyiscs values
	var speed = get_max_speed()
	var accel = get_acceleration()
	var drag = get_drag()
	
	# Add the gravity.
	if not is_on_floor():
		velocity.y -= gravity * delta
#
	# Handle jump.
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY
#
	# Get the input direction and handle the movement/deceleration.
	var input_dir = Input.get_vector("left", "right", "up", "down")
	var direction = (head.transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	if direction and velocity.length() < speed:
		velocity.x += accel * direction.x
		velocity.z += accel * direction.z
	
	var normalized_velocity = velocity.normalized()
	var move_dir = Vector3(normalized_velocity.x, 0, normalized_velocity.z)
	
	# If we're not inputting anything, our speed is too high, or we're trying to move backwards, apply drag
	if !direction or velocity.length() > speed or direction.dot(move_dir) < .5:
		velocity.x *= drag
		velocity.z *= drag

	move_and_slide()


func get_max_speed() -> float:
	if sprinting:
		return SPRINT_SPEED
	elif is_on_floor():
		return MAX_SPEED
	else:
		return INF

func get_acceleration() -> float:
	if is_on_floor():
		if sprinting:
			return SPRINT_ACCELERATION
		else:
			return ACCELERATION
	else:
		return AIR_ACCELERATION


func get_drag() -> float:
	if is_on_floor():
		return DRAG
	else:
		return AIR_DRAG


func _on_kill_box_body_entered(body:PhysicsBody3D):
	if body.is_in_group("kill"):
		game_over()
	if body.is_in_group("bullet") and bullets < max_bullets:
		bullets += 1
		body.queue_free()

func shoot():
	if bullets <= 0:
		return
	
	%BulletBoy.try_spawn()
	
	bullets -= 1
	
	var center = get_viewport().size / 2
	
	var origin = camera.project_ray_origin(center)
	
	var space_state = get_world_3d().direct_space_state
	
	var to = origin + camera.project_ray_normal(center) * MAX_BULLET_DISTANCE
	
	var query = PhysicsRayQueryParameters3D.create(origin, to, bullet_collision, [self])
	
	var result = space_state.intersect_ray(query)
	
	$HUD/MuzzleFlash.visible = true
	
	get_tree().create_timer(1).timeout.connect(func():
		$HUD/MuzzleFlash.visible = false
		
		if !result.collider.is_in_group("kill"):
			return
		
		$HUD/Sniper.visible = true
		$HUD/Sniper.play()
		
		get_tree().create_timer(1.5).timeout.connect(func():
			$HUD/Sniper.stop()
			$HUD/Sniper.visible = false
		)
	)
	
	if result.collider.is_in_group("killable"):
		result.collider.die()
		$HUD/ScoreCounter.score += 5

func game_over():
	$HUD/ScoreCounter
	get_tree().quit()
