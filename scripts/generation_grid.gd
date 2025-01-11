extends Node3D
class_name GenerationGrid

#region Internal Classes

enum CellType {
	EMPTY,
	ROOM,
	HALL,
	VENT
}

class CellData:
	extends RefCounted
	var type:CellType
	var position:Vector2i
	
	func _init(pos, cell_type := CellType.EMPTY):
		type = cell_type
		position = pos

#endregion

#region Variables

var cells = {}
var world_center = Vector2i(0, 0)

var generation_thread:Thread
var generation_mutex:Mutex
var chunks_to_generate:Array[Vector2i] = []
var generation_semaphore:Semaphore
var stop_generation := false

#endregion

#region Constants

const CHUNK_SIZE = 32

const WORLD_SIZE = 5

const ROOM_PADDING = 4

const MAX_ROOMS = 40
const MIN_ROOM_SIZE = 6
const MAX_ROOM_SIZE = 20

const NUM_HALLS = 50
const MAX_HALL_SIZE = 50
const HALL_WIDTH = 3
const HALL_PADDING = 4

#endregion

#region Debug

const ROOM_DEBUG_MESH = preload("res://scenes/debug/room_debug_mesh.tscn")
const HALL_DEBUG_MESH = preload("res://scenes/debug/hall_debug_mesh.tscn")
const VENT_DEBUG_MESH = preload("res://scenes/debug/vent_debug_mesh.tscn")

const DEBUG_GRID_CELL_SIZE = 1

func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("ui_right"):
		generation_mutex.lock()
		world_center.x += CHUNK_SIZE
		generation_mutex.unlock()
		
		reset_outside_cells()
		
		var chunks := get_chunks_in_world()
		
		generation_mutex.lock()
		var new_chunks = chunks.filter(func(chunk): return not cells.keys().has(chunk))
		generation_mutex.unlock()
		
		print(new_chunks)
		
		queue_generate(new_chunks)

#endregion

func _ready():
	generation_thread = Thread.new()
	generation_mutex = Mutex.new()
	generation_semaphore = Semaphore.new()
	
	generation_thread.start(generate)
	
	queue_generate(get_chunks_in_world())

func _exit_tree():
	generation_mutex.lock()
	stop_generation = true
	generation_mutex.unlock()
	
	generation_semaphore.post()
	
	generation_thread.wait_to_finish()

func initialize():
	# Center the world size on (0, 0)
	var border_chunks = (WORLD_SIZE - 1) / 2
	
	# Initialize cells
	for chunk_x in range(-border_chunks, border_chunks + 1):
		for chunk_y in range(-border_chunks, border_chunks + 1):
			var chunk_center = Vector2i(chunk_x, chunk_y) * CHUNK_SIZE
			init_chunk(chunk_center)
	
	# Cache this so we don't call it a bajillion times
	var world_bounds := get_world_bounds()
	
	# Generate rooms first, then halls.
	for chunk_y in range(-border_chunks, border_chunks + 1):
		for chunk_x in range(-border_chunks, border_chunks + 1):
			var chunk_center = Vector2i(chunk_x, chunk_y) * CHUNK_SIZE
			
			while true:
				gen_rooms(chunk_center)
				var success = gen_halls(chunk_center)
				if not success:
					print("Halls failed to generate in chunk " + str(chunk_center) + ". Resetting chunk.")
					init_chunk(chunk_center)
					continue
				success = prune_chunk(chunk_center)
				if not success and chunk_y != -border_chunks and chunk_x != -border_chunks:
					init_chunk(chunk_center)
					continue
				
				break
	
	add_meshes.call_deferred()
	print("Done!")

func queue_generate(chunk_centers:Array[Vector2i]):
	generation_mutex.lock()
	chunks_to_generate.append_array(chunk_centers)
	generation_mutex.unlock()
	
	generation_semaphore.post()

func generate():
	while true:
		generation_semaphore.wait()
		
		generation_mutex.lock()
		var exit = stop_generation
		generation_mutex.unlock()
		
		if exit:
			break
		
		generation_mutex.lock()
		var chunk_centers = chunks_to_generate
		chunks_to_generate = []
		generation_mutex.unlock()
		
		for chunk_center in chunk_centers:
			init_chunk(chunk_center)
		
		for chunk_center in chunk_centers:
			while true:
				gen_rooms(chunk_center)
				var success = gen_halls(chunk_center)
				if not success:
					print("Halls failed to generate in chunk " + str(chunk_center) + ". Resetting chunk.")
					init_chunk(chunk_center)
					continue
				success = prune_chunk(chunk_center)
				
				if not success:
					# Check leftwards and upwards chunks
					var adjacent_chunk_centers = [Vector2i(chunk_center.x - CHUNK_SIZE, chunk_center.y), Vector2i(chunk_center.x, chunk_center.y - CHUNK_SIZE)]
					
					var world_bounds = get_world_bounds()
					
					var first_chunk = true
					
					for adjacent_chunk in adjacent_chunk_centers:
						if world_bounds.has_point(adjacent_chunk):
							first_chunk = false
					
					if first_chunk:
						break
					
					init_chunk(chunk_center)
					continue
					
				#if not success and chunk_y != -border_chunks and chunk_x != -border_chunks:
					#init_chunk(chunk_center)
					#continue
				
				break
			
		update_meshes.call_deferred()

func add_meshes():
	for cell_position in cells:
		var cell = get_cell_data(cell_position)
		if cell.type == CellType.ROOM:
			add_mesh(cell_position, ROOM_DEBUG_MESH)
		if cell.type == CellType.HALL:
			add_mesh(cell_position, HALL_DEBUG_MESH)

func update_meshes():
	clear_meshes()
	add_meshes()

func add_meshes_in_chunk(chunk_center:Vector2i):
	var chunk_bounds = get_chunk_bounds(chunk_center)
	for x in range(chunk_bounds.position.x, chunk_bounds.end.x):
		for y in range(chunk_bounds.position.y, chunk_bounds.end.y):
			var cell_pos = Vector2i(x, y)
			var cell = get_cell_data(cell_pos)
			if cell.type == CellType.ROOM:
				add_mesh(cell_pos, ROOM_DEBUG_MESH)
			if cell.type == CellType.HALL:
				add_mesh(cell_pos, HALL_DEBUG_MESH)

func clear_meshes():
	for child in get_children():
		if child is MeshInstance3D:
			child.queue_free()

func add_mesh(spawn_pos:Vector2i, scene:PackedScene):
	var mesh:MeshInstance3D = scene.instantiate()
	mesh.position = Vector3(spawn_pos.x * DEBUG_GRID_CELL_SIZE, 0, spawn_pos.y * DEBUG_GRID_CELL_SIZE)
	add_child(mesh)

#region Room Generation

func gen_rooms(chunk_center:Vector2i):
	var chunk_bounds := get_chunk_bounds(chunk_center)
	
	var rooms:Array[Rect2i] = []
	
	for i in range(MAX_ROOMS):
		var corner = random_point_in_chunk(chunk_center)
		var size = Vector2i()
		size.x = randi_range(MIN_ROOM_SIZE, MAX_ROOM_SIZE)
		size.y = randi_range(MIN_ROOM_SIZE, MAX_ROOM_SIZE)
		var rect = Rect2i(corner, size)
		var shrunk_room_bounds = Rect2i(chunk_bounds).grow(-ROOM_PADDING)
		if not shrunk_room_bounds.encloses(rect):
			rect = shrink_to_fit(rect, shrunk_room_bounds)
		
		if rect.size.x < MIN_ROOM_SIZE or rect.size.y < MIN_ROOM_SIZE:
			continue
		
		var conflicting = false
		
		for room in rooms:
			var expanded = Rect2i(room).grow(ROOM_PADDING)
			if expanded.intersects(rect):
				conflicting = true
		
		if conflicting:
			continue
		rooms.append(rect)
	
	set_cell_type_from_rects(rooms, CellType.ROOM)

#endregion

#region Hall Generation

func gen_halls(chunk_center:Vector2i) -> bool:
	var hall_rects:Array[Rect2i] = []
	
	for _i in range(NUM_HALLS):
		var candidate_pos := get_hall_candidate(chunk_center)
		
		var candidate_normal := get_cell_normal(candidate_pos)
		
		var end_cell_pos := candidate_pos
		
		for i in range(1, MAX_HALL_SIZE):
			var new_cell_pos = candidate_pos + candidate_normal * i
			
			# This is overzealous.
			# Rect2i.has_point doesn't include the bottom or right edges, even if those are valid points.
			# This is fine, though, because there will never be a valid connecting point there.
			if !get_world_bounds().has_point(new_cell_pos):
				break
			
			var new_cell:CellData = get_cell_data(new_cell_pos)
			if new_cell.type != CellType.EMPTY:
				if new_cell.type == CellType.ROOM and get_cell_normal(new_cell_pos).length() == 1:
					end_cell_pos = new_cell_pos
				break
		
		if end_cell_pos == candidate_pos:
			continue
		
		var hall_rect = create_hall_rect(candidate_pos, end_cell_pos).abs()
		
		var conflicting = false
		
		for hall in hall_rects:
			var expanded = Rect2i(hall).grow(HALL_PADDING)
			if expanded.intersects(hall_rect):
				conflicting = true
		
		if conflicting:
			continue
		
		hall_rects.append(hall_rect)
		#print(hall_rect)
	
	if hall_rects.size() == 0:
		return false
	
	set_cell_type_from_rects(hall_rects, CellType.HALL)
	
	return true

func create_hall_rect(start_cell_pos:Vector2i, end_cell_pos:Vector2i) -> Rect2i:
	var hall_width_centered = (HALL_WIDTH - 1) / 2
	
	var hall_rect = Rect2i()
	
	hall_rect.position = start_cell_pos
	hall_rect.end = end_cell_pos
	
	hall_rect = hall_rect.abs()
	
	if start_cell_pos.x == end_cell_pos.x:
		hall_rect = hall_rect.grow_side(SIDE_LEFT, hall_width_centered)
		hall_rect = hall_rect.grow_side(SIDE_RIGHT, hall_width_centered + 1)
		hall_rect = hall_rect.grow_side(SIDE_TOP, -1) # This makes sure the generated hall doesn't overlap with the room it's attached to
	elif start_cell_pos.y == end_cell_pos.y:
		hall_rect = hall_rect.grow_side(SIDE_TOP, hall_width_centered)
		hall_rect = hall_rect.grow_side(SIDE_BOTTOM, hall_width_centered + 1)
		hall_rect = hall_rect.grow_side(SIDE_LEFT, -1) # See above comment
	
	return hall_rect

func get_hall_candidate(chunk_center:Vector2i) -> Vector2i:
	var chunk_bounds = get_chunk_bounds(chunk_center)
	
	var candidates = bounds_to_array(chunk_bounds).filter(func(cell):
		return get_cell_normal(cell).length() == 1 and get_cell_data(cell).type == CellType.ROOM
	)
	
	if candidates.size() == 0:
		print("No hall candidates in chunk " + str(chunk_center) + ".")
		return Vector2i.ZERO
	
	return candidates.pick_random()
	
	#var cell_position := random_point_in_chunk(chunk_center)
	#var cell_normal := get_cell_normal(cell_position)
	#while true:
		#cell_position = random_point_in_chunk(chunk_center)
		#cell_normal = get_cell_normal(cell_position)
		#
		#if cell_normal.length() == 1 and cells[cell_position].type == CellType.ROOM:
			#break
	#
	#return cell_position

#endregion

#region Utilities

func get_chunks_in_world() -> Array[Vector2i]:
	var chunks:Array[Vector2i] = []
	
	var border_chunks = (WORLD_SIZE - 1) / 2
	
	generation_mutex.lock()
	var center = world_center
	generation_mutex.unlock()
	
	for chunk_x in range(-border_chunks, border_chunks + 1):
		for chunk_y in range(-border_chunks, border_chunks + 1):
			chunks.append(Vector2i((chunk_x * CHUNK_SIZE) + center.x, (chunk_y * CHUNK_SIZE) + center.y))
	
	return chunks

func set_cell_type_from_rects(rects:Array[Rect2i], cell_type:CellType):
	for rect in rects:
		for x in range(rect.position.x, rect.end.x):
			for y in range(rect.position.y, rect.end.y):
				get_cell_data(Vector2i(x, y)).type = cell_type

func shrink_to_fit(rect:Rect2i, encloser:Rect2i) -> Rect2i:
	var new_rect = Rect2i(rect)
	
	new_rect.position.x = max(new_rect.position.x, encloser.position.x)
	new_rect.position.y = max(new_rect.position.y, encloser.position.y)
	
	new_rect.end.x = min(new_rect.end.x, encloser.end.x)
	new_rect.end.y = min(new_rect.end.y, encloser.end.y)
	
	return new_rect

func random_point_in_chunk(chunk_center:Vector2i) -> Vector2i:
	return random_point_in_bounds(get_chunk_bounds(chunk_center))

func random_point_in_world() -> Vector2i:
	return random_point_in_bounds(get_world_bounds())

func random_point_in_bounds(bounds:Rect2i) -> Vector2i:
	return bounds_to_array(bounds).pick_random()

func get_chunk_bounds(chunk_center:Vector2i) -> Rect2i:
	return Rect2i(Vector2i(chunk_center.x - (CHUNK_SIZE / 2), chunk_center.y - (CHUNK_SIZE / 2)), Vector2i(CHUNK_SIZE, CHUNK_SIZE))

func get_world_bounds() -> Rect2i:
	generation_mutex.lock()
	var center = world_center
	generation_mutex.unlock()
	return get_chunk_bounds(center).grow(CHUNK_SIZE * (WORLD_SIZE - 1) / 2)

func init_chunk(chunk_center:Vector2i):
	var chunk_bounds := get_chunk_bounds(chunk_center)
	for x in range(chunk_bounds.position.x, chunk_bounds.end.x + 1):
		for y in range(chunk_bounds.position.y, chunk_bounds.end.y + 1):
			set_cell_data(CellData.new(Vector2i(x, y))) 

func get_cell_normal(cell_position:Vector2i) -> Vector2i:
	var normal = Vector2i.ZERO
	var cell:CellData = get_cell_data(cell_position)
	
	if cell.type == CellType.EMPTY:
		return normal
	
	for x in [-1, 1]:
		var neighbor_position = Vector2i(cell_position.x + x, cell_position.y)
		if !get_world_bounds().has_point(neighbor_position):
			continue
		var neighbor:CellData = get_cell_data(neighbor_position)
		if neighbor.type == CellType.EMPTY:
			normal.x = x
	
	for y in [-1, 1]:
		var neighbor_position = Vector2i(cell_position.x, cell_position.y + y)
		if !get_world_bounds().has_point(neighbor_position):
			continue
		var neighbor:CellData = get_cell_data(neighbor_position)
		if neighbor.type == CellType.EMPTY:
			normal.y = y
	
	#if normal.x != 0 and normal.y != 0:
		#print(normal)
	
	return normal

func cell_is_on_boundary(bounds:Rect2i, cell:Vector2i) -> bool:
	if cell.x == bounds.position.x or cell.x == bounds.end.x:
		return true
	
	if cell.y == bounds.position.y or cell.y == bounds.end.y:
		return true
	
	return false

func get_cells_on_boundary(bounds:Rect2i) -> Array[Vector2i]:
	var all_cells := bounds_to_array(bounds)
	var filtered_cells = all_cells.filter(func(cell): return cell_is_on_boundary(bounds, cell))
	return filtered_cells

func bounds_to_array(bounds:Rect2i) -> Array[Vector2i]:
	var array:Array[Vector2i] = []
	
	for x  in range(bounds.position.x, bounds.end.x):
		for y in range(bounds.position.y, bounds.end.y):
			array.append(Vector2i(x, y))
	
	return array

func get_cell_data(cell_pos:Vector2i) -> CellData:
	generation_mutex.lock()
	var cell_data = cells[cell_pos]
	generation_mutex.unlock()
	
	return cell_data

func set_cell_data(cell_data:CellData):
	generation_mutex.lock()
	cells[cell_data.position] = cell_data
	generation_mutex.unlock()

func reset_outside_cells():
	var world_bounds = get_world_bounds()
	
	generation_mutex.lock()
	var all_cells = cells.keys()
	generation_mutex.unlock()
	
	var outside_cells = all_cells.filter(func(cell): return not world_bounds.has_point(cell as Vector2i))
	
	for cell in outside_cells:
		set_cell_data(CellData.new(Vector2i(cell)))

#endregion

#region Verification

func verify_chunk(chunk_center:Vector2i, reference_chunk_center:Vector2i) -> bool:
	var chunk_bounds := get_chunk_bounds(chunk_center)
	var reference_direction = (reference_chunk_center - chunk_center).sign()
	
	var connecting_cells = get_cells_on_boundary(chunk_bounds).filter(func(cell):
		match reference_direction:
			Vector2i.RIGHT:
				return cell.x > chunk_center.x
			Vector2i.LEFT:
				return cell.x < chunk_center.x
			Vector2i.UP:
				return cell.y < chunk_center.y
			Vector2i.DOWN:
				return cell.y > chunk_center.y
		return false # Just in case
	).filter(func(cell): return get_cell_data(cell).type == CellType.HALL)
	
	return connecting_cells.size() > 0
	
	#var x = []
	#var y = []
	#
	#match reference_direction:
		#Vector2i.RIGHT:
			#x = [chunk_bounds.end.x]
			#y = range(chunk_bounds.position.y, chunk_bounds.end.y)
		#Vector2i.LEFT:
			#x = [chunk_bounds.position.x]
			#y = range(chunk_bounds.position.y, chunk_bounds.end.y)
		#Vector2i.UP:
			#x = range(chunk_bounds.position.x, chunk_bounds.end.x)
			#y = [chunk_bounds.position.y]
		#Vector2i.DOWN:
			#x = range(chunk_bounds.position.x, chunk_bounds.end.x)
			#y = [chunk_bounds.end.y]
	#
	#
	#for x_pos in x:
		#for y_pos in y:
			#if cells[Vector2i(x_pos, y_pos)].type != CellType.EMPTY:
				#return true

func prune_chunk(chunk_center:Vector2i) -> bool:
	var chunk_bounds = get_chunk_bounds(chunk_center)
	
	var boundary_cells := get_cells_on_boundary(chunk_bounds)
	
	var starting_point_candidates = boundary_cells.filter(func(cell): return get_cell_data(cell).type == CellType.HALL)
	
	if starting_point_candidates.size() == 0:
		print("Chunk " + str(chunk_center) + " has no connections.")
		return false
		#starting_point_candidates = bounds_to_array(chunk_bounds).filter(func(cell): return cells[cell].type == CellType.HALL)
	
	var starting_point:Vector2i = starting_point_candidates.pick_random()
	
	var frontier:Array[Vector2i] = [starting_point]
	var flooded_list:Array[Vector2i] = []
	
	var working_point = starting_point
	
	var world_bounds = get_world_bounds()
	
	while frontier.size() > 0:
		working_point = frontier[0]
		if get_cell_data(working_point).type != CellType.EMPTY:
			if not flooded_list.has(working_point):
				flooded_list.append(working_point)
				if world_bounds.has_point(working_point + Vector2i.RIGHT):
					frontier.append(working_point + Vector2i.RIGHT)
				if world_bounds.has_point(working_point + Vector2i.LEFT):
					frontier.append(working_point + Vector2i.LEFT)
				if world_bounds.has_point(working_point + Vector2i.UP):
					frontier.append(working_point + Vector2i.UP)
				if world_bounds.has_point(working_point + Vector2i.DOWN):
					frontier.append(working_point + Vector2i.DOWN)
		
		frontier.remove_at(0)
		
	var cells_to_prune = bounds_to_array(chunk_bounds).filter(func(cell): return not flooded_list.has(cell))
	
	for cell in cells_to_prune:
		get_cell_data(cell).type = CellType.EMPTY
	
	return true

#endregion
