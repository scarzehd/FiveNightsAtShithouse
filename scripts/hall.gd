extends Area3D

signal spawn_foxy(pos:Vector3, direction:Vector3)

@onready var pos_1 = $Pos1
@onready var pos_2 = $Pos2

@export var pos_1_direction:Vector3
@export var pos_2_direction:Vector3

@export var max_variance:Vector3

func _on_body_entered(body: Node3D) -> void:
	if body.name == "Clams":
		var pos_1_distance = body.position.distance_to(pos_1.global_position)
		var pos_2_distance = body.position.distance_to(pos_2.global_position)
		
		randomize()
		
		if pos_1_distance < pos_2_distance:
			spawn_foxy.emit(pos_2.global_position + max_variance * randi_range(-1, 1), pos_2_direction)
			return
		
		spawn_foxy.emit(pos_1.global_position + max_variance * randi_range(-1, 1), pos_1_direction)
