extends Node3D

@export var bullet_scene:PackedScene

var max_spawned_bullets = 3

@export_flags_3d_navigation var nav_layers

func spawn_bullet() -> void:
	var bullets = get_tree().get_nodes_in_group("bullet")
	if bullets.size() >= max_spawned_bullets:
		return
	
	var bullet = bullet_scene.instantiate()
	bullet.position = NavigationServer3D.map_get_random_point(get_world_3d().get_navigation_map(), nav_layers, false)
	
	add_child(bullet)
