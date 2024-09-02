extends CharacterBody3D

@onready var inactive_pos := position

@export var chance:int

func _physics_process(delta: float) -> void:
	move_and_slide()

func deactivate():
	position = inactive_pos
	$MetalPipeSound.play()
	velocity = Vector3.ZERO


func activate(new_position:Vector3, direction:Vector3):
	var random = randi_range(0, chance)
	
	if random != 0 and not %Clams.sprinting:
		return
	
	position = new_position
	velocity = direction * 16
	$MetalPipeSound.play()

func touch_wall(body: Node3D) -> void:
	if body == self:
		return
	if body.is_in_group("hall") or body.is_in_group("kill"):
		deactivate()

func die():
	deactivate()
