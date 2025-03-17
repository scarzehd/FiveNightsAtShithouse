extends GridMap
class_name GenerationGrid

# A note on rects: Rects in Godot do not consider the end position to be included in their area

var cells:Dictionary[Vector2i,CellType] = {}

const STARTING_ROOM := Rect2i(-3, -3, 5, 5)

const MINIMUM_HALL_SPACING = 3
const STARTING_HALLS = 3

const MAX_HALL_LENGTH = 10
const MIN_HALL_LENGTH = 5

const WORLD_SIZE := 100

const ROOM_DEBUG_MESH = preload("res://scenes/debug/room_debug_mesh.tscn")
const HALL_DEBUG_MESH = preload("res://scenes/debug/hall_debug_mesh.tscn")
const VENT_DEBUG_MESH = preload("res://scenes/debug/vent_debug_mesh.tscn")

func _ready() -> void:
	rect_abs(Rect2i(2, 2, -3, -3))
	
	init_cells()
	generate()

func init_cells():
	for x in range(-WORLD_SIZE / 2, WORLD_SIZE / 2):
		for y in range(-WORLD_SIZE / 2, WORLD_SIZE / 2):
			cells[Vector2i(x, y)] = CellType.EMPTY

func generate():
	# Create starting room
	set_rect(STARTING_ROOM, CellType.ROOM)
	
	var edge_cells := get_cells_on_rect_edge(STARTING_ROOM)
	
	# Remove corners
	edge_cells.erase(Vector2i(STARTING_ROOM.position.x, STARTING_ROOM.position.y))
	edge_cells.erase(Vector2i(STARTING_ROOM.position.x, STARTING_ROOM.end.y - 1))
	edge_cells.erase(Vector2i(STARTING_ROOM.end.x - 1, STARTING_ROOM.position.y))
	edge_cells.erase(Vector2i(STARTING_ROOM.end.x - 1, STARTING_ROOM.end.y - 1))
	
	var hall_start_points:Array[Vector2i] = []
	
	
	while hall_start_points.size() < STARTING_HALLS and edge_cells.size() > 0:
		var start_point = edge_cells.pick_random()
		edge_cells.erase(start_point)
		hall_start_points.append(start_point)
		
		# This is taxicab distance. I wanted to use actual perimiter distance but I don't know how to do that
		# Taxicab distance is a reasonable compromise between perimiter distance and euclidian distance
		# It's only different if the two points are on opposite sides of the starting room
		edge_cells = edge_cells.filter(func(item): return (absi(start_point.x - item.x) + absi(start_point.y - item.y)) > MINIMUM_HALL_SPACING)
	
	for start_point in hall_start_points:
		gen_hall(start_point)
	
	add_meshes()

enum CellType {
	EMPTY,
	ROOM,
	HALL,
	VENT
}

func gen_hall(start:Vector2i):
	
	var cell_normal := get_cell_normal(start)
	
	if cell_normal.length() > 1:
		cell_normal = Vector2i(0, cell_normal.y)
	
	var length = randi_range(MIN_HALL_LENGTH, MAX_HALL_LENGTH)
	
	# The start cell is part of the start room, so move forward by one
	start += cell_normal
	
	var end_cell = start
	
	var gen_room = true
	
	for i in range(length):
		end_cell = start + (cell_normal * i)
		if cells.keys().count(end_cell) > 0 and cells[end_cell] != CellType.EMPTY:
			end_cell -= cell_normal
			gen_room = false
			break
	
	var hall_rect := Rect2i(start, end_cell - start)
	
	hall_rect = rect_abs(hall_rect)
	
	if cell_normal.x != 0:
		hall_rect = hall_rect.grow_individual(0, 2, 0, 1)
	else:
		hall_rect = hall_rect.grow_individual(2, 0, 1, 0)
	
	
	set_rect(hall_rect, CellType.HALL)

func rect_abs(rect:Rect2i) -> Rect2i:
	var new_start = Vector2i.ZERO
	var new_end = Vector2i.ZERO
	
	if rect.position.x < rect.end.x:
		new_start.x = rect.position.x
		new_end.x = rect.end.x
	else:
		new_start.x = rect.end.x + 1
		new_end.x = rect.position.x + 1
	
	if rect.position.y < rect.end.y:
		new_start.y = rect.position.y
		new_end.y = rect.end.y
	else:
		new_start.y = rect.end.y + 1
		new_end.y = rect.position.y + 1
	
	var new_rect = Rect2i()
	new_rect.position = new_start
	new_rect.end = new_end
	
	return new_rect

# Returns a vector that points away from the nearest occupied cell
func get_cell_normal(cell:Vector2i) -> Vector2i:
	var normal = Vector2i.ZERO
	
	if cells[cell] == CellType.EMPTY:
		return normal
	
	for x in [-1, 1]:
		var neighbor_position = Vector2i(cell.x + x, cell.y)
		if cells.keys().count(neighbor_position) <= 0:
			continue
		if cells[neighbor_position] == CellType.EMPTY:
			normal.x = x
	
	for y in [-1, 1]:
		var neighbor_position = Vector2i(cell.x, cell.y + y)
		if cells.keys().count(neighbor_position) <= 0:
			continue
		if cells[neighbor_position] == CellType.EMPTY:
			normal.y = y
	
	#if normal.x != 0 and normal.y != 0:
		#print(normal)
	
	return normal

func add_meshes():
	for pos in cells:
		var type := cells[pos]
		match type:
			CellType.ROOM:
				set_cell_item(Vector3i(pos.x, 0, pos.y), 1)
			CellType.HALL:
				set_cell_item(Vector3i(pos.x, 0, pos.y), 0)
			CellType.VENT:
				set_cell_item(Vector3i(pos.x, 0, pos.y), 2)

func get_cells_on_rect_edge(rect:Rect2i) -> Array[Vector2i]:
	var edge_cells:Array[Vector2i] = []
	
	for x in range(rect.position.x, rect.end.x):
		edge_cells.append(Vector2i(x, rect.position.y))
		edge_cells.append(Vector2i(x, rect.end.y - 1))
	
	for y in range(rect.position.y + 1, rect.end.y - 1): # Don't include the top and bottom corners because we've already added those
		edge_cells.append(Vector2i(rect.position.x, y))
		edge_cells.append(Vector2i(rect.end.x - 1, y))
	
	return edge_cells

func set_rect(rect:Rect2i, cell_type:CellType) -> void:
	var cell_pos := Vector2i(0, 0)
	
	# I'm not using get_cells_in_rect here because that would loop over the cells an extra time
	
	for x in range(rect.position.x, rect.end.x):
		for y in range(rect.position.y, rect.end.y):
			cell_pos.x = x
			cell_pos.y = y
			cells[cell_pos] = cell_type

func get_cells_in_rect(rect:Rect2i) -> Array[Vector2i]:
	var cell_positions:Array[Vector2i] = []
	
	for x in range(rect.position.x, rect.end.x):
		for y in range(rect.position.y, rect.end.y):
			cell_positions.append(Vector2i(x, y))
	
	return cell_positions

#region Old Version

#class CellData:
	#extends RefCounted
	#var type:CellType
	#var position:Vector2i
	#
	#func _init(pos, cell_type := CellType.EMPTY):
		#type = cell_type
		#position = pos
#
#
##region Variables
#
##var cells = {}
##var world_center = Vector2i(0, 0)
##
##var generation_thread:Thread
##var generation_mutex:Mutex
##var chunks_to_generate:Array[Vector2i] = []
##var generation_semaphore:Semaphore
##var stop_generation := false
##var generating := false
#
#
##endregion
#
##region Constants
#
##const CHUNK_SIZE = 32
##
##const WORLD_SIZE = 5
##
##const ROOM_PADDING = 4
##
##const MAX_ROOMS = 40
##const MIN_ROOM_SIZE = 6
##const MAX_ROOM_SIZE = 20
##
##const NUM_HALLS = 50
##const MAX_HALL_SIZE = 50
##const HALL_WIDTH = 3
##const HALL_PADDING = 4
#
##endregion
#
##region Debug
#
##const ROOM_DEBUG_MESH = preload("res://scenes/debug/room_debug_mesh.tscn")
##const HALL_DEBUG_MESH = preload("res://scenes/debug/hall_debug_mesh.tscn")
##const VENT_DEBUG_MESH = preload("res://scenes/debug/vent_debug_mesh.tscn")
##
##const DEBUG_GRID_CELL_SIZE = 1
##
##func _process(_delta: float) -> void:
	##if Input.is_action_just_pressed("ui_right"):
		##move_world_center(Vector2i.RIGHT)
	##elif Input.is_action_just_pressed("ui_left"):
		##move_world_center(Vector2i.LEFT)
	##elif Input.is_action_just_pressed("ui_up"):
		##move_world_center(Vector2i.UP)
	##elif Input.is_action_just_pressed("ui_down"):
		##move_world_center(Vector2i.DOWN)
#
##endregion
#
##func _ready():
	##generation_thread = Thread.new()
	##generation_mutex = Mutex.new()
	##generation_semaphore = Semaphore.new()
	##
	##generation_thread.start(generate)
	##
	##queue_generate(get_chunks_in_world())
#
##func _exit_tree():
	##generation_mutex.lock()
	##stop_generation = true
	##generation_mutex.unlock()
	##
	##generation_semaphore.post()
	##
	##generation_thread.wait_to_finish()
#
#func queue_generate(chunk_centers:Array[Vector2i]):
	#generation_mutex.lock()
	#chunks_to_generate.append_array(chunk_centers)
	#generation_mutex.unlock()
	#
	#generation_semaphore.post()
#
#func generate():
	#while true:
		#generation_mutex.lock()
		#generating = false
		#generation_mutex.unlock()
		#
		#generation_semaphore.wait()
		#
		#generation_mutex.lock()
		#generating = true
		#generation_mutex.unlock()
		#
		#generation_mutex.lock()
		#var exit = stop_generation
		#generation_mutex.unlock()
		#
		#if exit:
			#break
		#
		#generation_mutex.lock()
		#var chunk_centers = chunks_to_generate
		#chunks_to_generate = []
		#generation_mutex.unlock()
		#
		#for chunk_center in chunk_centers:
			#init_chunk(chunk_center)
		#
		#var times = []
		#
		#for chunk_center in chunk_centers:
			#print("-------------------------------------------")
			#print("Chunk " + str(chunk_center))
			#var start = Time.get_ticks_usec()
			#while true:
				#var rooms_start = Time.get_ticks_usec()
				#gen_rooms(chunk_center)
				#var rooms_end = Time.get_ticks_usec()
				#
				#var rooms_time = (rooms_end - rooms_start) / 1000000.0
				#
				#print("Room generation time: " + str(rooms_time) + " secs")
				#
				#
				#var halls_start = Time.get_ticks_usec()
				#var success = gen_halls(chunk_center)
				#var halls_end = Time.get_ticks_usec()
				#
				#var halls_time = (halls_end - halls_start) / 1000000.0
				#
				#if not success:
					#print("Halls failed to generate in chunk " + str(chunk_center) + ". Resetting chunk.")
					#init_chunk(chunk_center)
					#continue
				#
				#print("Hall generation time: " + str(halls_time) + " secs")
				#
				#
				#var prune_start = Time.get_ticks_usec()
				#success = prune_chunk(chunk_center)
				#var prune_end = Time.get_ticks_usec()
				#
				#var prune_time = (prune_end - prune_start) / 1000000.0
				#print("Chunk pruning time: " + str(prune_time) + " secs")
				#
				#if not success:
					## Check leftwards and upwards chunks
					#var adjacent_chunk_centers = [Vector2i(chunk_center.x - CHUNK_SIZE, chunk_center.y), Vector2i(chunk_center.x, chunk_center.y - CHUNK_SIZE)]
					#
					#var world_bounds = get_world_bounds()
					#
					#var first_chunk = true
					#
					#for adjacent_chunk in adjacent_chunk_centers:
						#if world_bounds.has_point(adjacent_chunk):
							#first_chunk = false
					#
					#if first_chunk:
						#break
					#
					#init_chunk(chunk_center)
					#continue
					#
				##if not success and chunk_y != -border_chunks and chunk_x != -border_chunks:
					##init_chunk(chunk_center)
					##continue
				#
				#break
			#
			#var end = Time.get_ticks_usec()
			#
			#var time = (end - start) / 1000000.0
			#
			#print("Time for chunk: " + str(time) + " secs")
			#
			#times.append(time)
		#
		#update_meshes.call_deferred()
		#
		#if times.size() == 0:
			#return
		#
		#var sum = times.reduce(func(element, accum): return accum + element, 10)
		#
		#print("-------------------------------------------")
		#print("Average chunk time: " + str(sum / times.size()))
		#print("Total time for " + str(chunk_centers.size()) + " chunks:"  + str(sum))
		#
#
#func add_meshes():
	#for cell_position in cells:
		#var cell = get_cell_data(cell_position)
		#if cell.type == CellType.ROOM:
			#add_mesh(cell_position, ROOM_DEBUG_MESH)
		#if cell.type == CellType.HALL:
			#add_mesh(cell_position, HALL_DEBUG_MESH)
#
#func update_meshes():
	#clear_meshes()
	#add_meshes()
#
#func add_meshes_in_chunk(chunk_center:Vector2i):
	#var chunk_bounds = get_chunk_bounds(chunk_center)
	#for x in range(chunk_bounds.position.x, chunk_bounds.end.x):
		#for y in range(chunk_bounds.position.y, chunk_bounds.end.y):
			#var cell_pos = Vector2i(x, y)
			#var cell = get_cell_data(cell_pos)
			#if cell.type == CellType.ROOM:
				#add_mesh(cell_pos, ROOM_DEBUG_MESH)
			#if cell.type == CellType.HALL:
				#add_mesh(cell_pos, HALL_DEBUG_MESH)
#
#func clear_meshes():
	#for child in get_children():
		#if child is MeshInstance3D:
			#child.queue_free()
#
#func add_mesh(spawn_pos:Vector2i, scene:PackedScene):
	#var mesh:MeshInstance3D = scene.instantiate()
	#mesh.position = Vector3(spawn_pos.x * DEBUG_GRID_CELL_SIZE, 0, spawn_pos.y * DEBUG_GRID_CELL_SIZE)
	#add_child(mesh)
#
#func move_world_center(direction:Vector2i):
	#while true:
		#generation_mutex.lock()
		#var can_continue = not generating
		#generation_mutex.unlock()
		#
		#if can_continue:
			#break
		#else:
			#await get_tree().process_frame
	#
	#generation_mutex.lock()
	#
	#world_center += direction * CHUNK_SIZE
	#
	#reset_outside_cells()
	#
	#var chunks := get_chunks_in_world()
	#
	#var new_chunks = chunks.filter(func(chunk): return not cells.keys().has(chunk))
	#
	#generation_mutex.unlock()
	#
	#queue_generate(new_chunks)
#
##region Room Generation
#
#func gen_rooms(chunk_center:Vector2i):
	#var chunk_bounds := get_chunk_bounds(chunk_center)
	#
	#var rooms:Array[Rect2i] = []
	#
	#for i in range(MAX_ROOMS):
		#var corner = random_point_in_chunk(chunk_center)
		#var size = Vector2i()
		#size.x = randi_range(MIN_ROOM_SIZE, MAX_ROOM_SIZE)
		#size.y = randi_range(MIN_ROOM_SIZE, MAX_ROOM_SIZE)
		#var rect = Rect2i(corner, size)
		#var shrunk_room_bounds = Rect2i(chunk_bounds).grow(-ROOM_PADDING)
		#if not shrunk_room_bounds.encloses(rect):
			#rect = shrink_to_fit(rect, shrunk_room_bounds)
		#
		#if rect.size.x < MIN_ROOM_SIZE or rect.size.y < MIN_ROOM_SIZE:
			#continue
		#
		#var conflicting = false
		#
		#for room in rooms:
			#var expanded = Rect2i(room).grow(ROOM_PADDING)
			#if expanded.intersects(rect):
				#conflicting = true
		#
		#if conflicting:
			#continue
		#rooms.append(rect)
	#
	#set_cell_type_from_rects(rooms, CellType.ROOM)
#
##endregion
#
##region Hall Generation
#
#func gen_halls(chunk_center:Vector2i) -> bool:
	#var hall_rects:Array[Rect2i] = []
	#
	#for _i in range(NUM_HALLS):
		#var candidate_pos := get_hall_candidate(chunk_center)
		#
		#var candidate_normal := get_cell_normal(candidate_pos)
		#
		#var end_cell_pos := candidate_pos
		#
		#for i in range(1, MAX_HALL_SIZE):
			#var new_cell_pos = candidate_pos + candidate_normal * i
			#
			## This is overzealous.
			## Rect2i.has_point doesn't include the bottom or right edges, even if those are valid points.
			## This is fine, though, because there will never be a valid connecting point there.
			#if !get_world_bounds().has_point(new_cell_pos):
				#break
			#
			#var new_cell:CellData = get_cell_data(new_cell_pos)
			#if new_cell.type != CellType.EMPTY:
				#if new_cell.type == CellType.ROOM and get_cell_normal(new_cell_pos).length() == 1:
					#end_cell_pos = new_cell_pos
				#break
		#
		#if end_cell_pos == candidate_pos:
			#continue
		#
		#var hall_rect = create_hall_rect(candidate_pos, end_cell_pos).abs()
		#
		#var conflicting = false
		#
		#for hall in hall_rects:
			#var expanded = Rect2i(hall).grow(HALL_PADDING)
			#if expanded.intersects(hall_rect):
				#conflicting = true
		#
		#if conflicting:
			#continue
		#
		#hall_rects.append(hall_rect)
		##print(hall_rect)
	#
	#if hall_rects.size() == 0:
		#return false
	#
	#set_cell_type_from_rects(hall_rects, CellType.HALL)
	#
	#return true
#
#func create_hall_rect(start_cell_pos:Vector2i, end_cell_pos:Vector2i) -> Rect2i:
	#var hall_width_centered = (HALL_WIDTH - 1) / 2
	#
	#var hall_rect = Rect2i()
	#
	#hall_rect.position = start_cell_pos
	#hall_rect.end = end_cell_pos
	#
	#hall_rect = hall_rect.abs()
	#
	#if start_cell_pos.x == end_cell_pos.x:
		#hall_rect = hall_rect.grow_side(SIDE_LEFT, hall_width_centered)
		#hall_rect = hall_rect.grow_side(SIDE_RIGHT, hall_width_centered + 1)
		#hall_rect = hall_rect.grow_side(SIDE_TOP, -1) # This makes sure the generated hall doesn't overlap with the room it's attached to
	#elif start_cell_pos.y == end_cell_pos.y:
		#hall_rect = hall_rect.grow_side(SIDE_TOP, hall_width_centered)
		#hall_rect = hall_rect.grow_side(SIDE_BOTTOM, hall_width_centered + 1)
		#hall_rect = hall_rect.grow_side(SIDE_LEFT, -1) # See above comment
	#
	#return hall_rect
#
#func get_hall_candidate(chunk_center:Vector2i) -> Vector2i:
	#var chunk_bounds = get_chunk_bounds(chunk_center)
	#
	#var candidates = bounds_to_array(chunk_bounds).filter(func(cell):
		#return get_cell_normal(cell).length() == 1 and get_cell_data(cell).type == CellType.ROOM
	#)
	#
	#if candidates.size() == 0:
		#print("No hall candidates in chunk " + str(chunk_center) + ".")
		#return Vector2i.ZERO
	#
	#return candidates.pick_random()
	#
	##var cell_position := random_point_in_chunk(chunk_center)
	##var cell_normal := get_cell_normal(cell_position)
	##while true:
		##cell_position = random_point_in_chunk(chunk_center)
		##cell_normal = get_cell_normal(cell_position)
		##
		##if cell_normal.length() == 1 and cells[cell_position].type == CellType.ROOM:
			##break
	##
	##return cell_position
#
##endregion
#
##region Utilities
#
#func get_chunks_in_world() -> Array[Vector2i]:
	#var chunks:Array[Vector2i] = []
	#
	#var border_chunks = (WORLD_SIZE - 1) / 2
	#
	#generation_mutex.lock()
	#var center = world_center
	#generation_mutex.unlock()
	#
	#for chunk_x in range(-border_chunks, border_chunks + 1):
		#for chunk_y in range(-border_chunks, border_chunks + 1):
			#chunks.append(Vector2i((chunk_x * CHUNK_SIZE) + center.x, (chunk_y * CHUNK_SIZE) + center.y))
	#
	#return chunks
#
#func set_cell_type_from_rects(rects:Array[Rect2i], cell_type:CellType):
	#for rect in rects:
		#for x in range(rect.position.x, rect.end.x):
			#for y in range(rect.position.y, rect.end.y):
				#get_cell_data(Vector2i(x, y)).type = cell_type
#
#func shrink_to_fit(rect:Rect2i, encloser:Rect2i) -> Rect2i:
	#var new_rect = Rect2i(rect)
	#
	#new_rect.position.x = max(new_rect.position.x, encloser.position.x)
	#new_rect.position.y = max(new_rect.position.y, encloser.position.y)
	#
	#new_rect.end.x = min(new_rect.end.x, encloser.end.x)
	#new_rect.end.y = min(new_rect.end.y, encloser.end.y)
	#
	#return new_rect
#
#func random_point_in_chunk(chunk_center:Vector2i) -> Vector2i:
	#return random_point_in_bounds(get_chunk_bounds(chunk_center))
#
#func random_point_in_world() -> Vector2i:
	#return random_point_in_bounds(get_world_bounds())
#
#func random_point_in_bounds(bounds:Rect2i) -> Vector2i:
	#return bounds_to_array(bounds).pick_random()
#
#func get_chunk_bounds(chunk_center:Vector2i) -> Rect2i:
	#return Rect2i(Vector2i(chunk_center.x - (CHUNK_SIZE / 2), chunk_center.y - (CHUNK_SIZE / 2)), Vector2i(CHUNK_SIZE, CHUNK_SIZE))
#
#func get_world_bounds() -> Rect2i:
	#generation_mutex.lock()
	#var center = world_center
	#generation_mutex.unlock()
	#return get_chunk_bounds(center).grow(CHUNK_SIZE * (WORLD_SIZE - 1) / 2)
#
#func init_chunk(chunk_center:Vector2i):
	#var chunk_bounds := get_chunk_bounds(chunk_center)
	#for x in range(chunk_bounds.position.x, chunk_bounds.end.x + 1):
		#for y in range(chunk_bounds.position.y, chunk_bounds.end.y + 1):
			#set_cell_data(CellData.new(Vector2i(x, y))) 
#
#func get_cell_normal(cell_position:Vector2i) -> Vector2i:
	#var normal = Vector2i.ZERO
	#var cell:CellData = get_cell_data(cell_position)
	#
	#if cell.type == CellType.EMPTY:
		#return normal
	#
	#for x in [-1, 1]:
		#var neighbor_position = Vector2i(cell_position.x + x, cell_position.y)
		#if !get_world_bounds().has_point(neighbor_position):
			#continue
		#var neighbor:CellData = get_cell_data(neighbor_position)
		#if neighbor.type == CellType.EMPTY:
			#normal.x = x
	#
	#for y in [-1, 1]:
		#var neighbor_position = Vector2i(cell_position.x, cell_position.y + y)
		#if !get_world_bounds().has_point(neighbor_position):
			#continue
		#var neighbor:CellData = get_cell_data(neighbor_position)
		#if neighbor.type == CellType.EMPTY:
			#normal.y = y
	#
	##if normal.x != 0 and normal.y != 0:
		##print(normal)
	#
	#return normal
#
#func cell_is_on_boundary(bounds:Rect2i, cell:Vector2i) -> bool:
	#if cell.x == bounds.position.x or cell.x == bounds.end.x:
		#return true
	#
	#if cell.y == bounds.position.y or cell.y == bounds.end.y:
		#return true
	#
	#return false
#
#func get_cells_on_boundary(bounds:Rect2i) -> Array[Vector2i]:
	#var all_cells := bounds_to_array(bounds)
	#var filtered_cells = all_cells.filter(func(cell): return cell_is_on_boundary(bounds, cell))
	#return filtered_cells
#
#func bounds_to_array(bounds:Rect2i) -> Array[Vector2i]:
	#var array:Array[Vector2i] = []
	#
	#for x  in range(bounds.position.x, bounds.end.x):
		#for y in range(bounds.position.y, bounds.end.y):
			#array.append(Vector2i(x, y))
	#
	#return array
#
#func get_cell_data(cell_pos:Vector2i) -> CellData:
	#generation_mutex.lock()
	#var cell_data = cells[cell_pos]
	#generation_mutex.unlock()
	#
	#return cell_data
#
#func set_cell_data(cell_data:CellData):
	#generation_mutex.lock()
	#cells[cell_data.position] = cell_data
	#generation_mutex.unlock()
#
#func reset_outside_cells():
	#var world_bounds = get_world_bounds()
	#
	#generation_mutex.lock()
	#var all_cells = cells.keys()
	#generation_mutex.unlock()
	#
	#var outside_cells = all_cells.filter(func(cell): return not world_bounds.has_point(cell as Vector2i))
	#
	#for cell in outside_cells:
		#generation_mutex.lock()
		#cells.erase(cell)
		#generation_mutex.unlock()
#
##endregion
#
##region Verification
#
#func verify_chunk(chunk_center:Vector2i, reference_chunk_center:Vector2i) -> bool:
	#var chunk_bounds := get_chunk_bounds(chunk_center)
	#var reference_direction = (reference_chunk_center - chunk_center).sign()
	#
	#var connecting_cells = get_cells_on_boundary(chunk_bounds).filter(func(cell):
		#match reference_direction:
			#Vector2i.RIGHT:
				#return cell.x > chunk_center.x
			#Vector2i.LEFT:
				#return cell.x < chunk_center.x
			#Vector2i.UP:
				#return cell.y < chunk_center.y
			#Vector2i.DOWN:
				#return cell.y > chunk_center.y
		#return false # Just in case
	#).filter(func(cell): return get_cell_data(cell).type == CellType.HALL)
	#
	#return connecting_cells.size() > 0
	#
	##var x = []
	##var y = []
	##
	##match reference_direction:
		##Vector2i.RIGHT:
			##x = [chunk_bounds.end.x]
			##y = range(chunk_bounds.position.y, chunk_bounds.end.y)
		##Vector2i.LEFT:
			##x = [chunk_bounds.position.x]
			##y = range(chunk_bounds.position.y, chunk_bounds.end.y)
		##Vector2i.UP:
			##x = range(chunk_bounds.position.x, chunk_bounds.end.x)
			##y = [chunk_bounds.position.y]
		##Vector2i.DOWN:
			##x = range(chunk_bounds.position.x, chunk_bounds.end.x)
			##y = [chunk_bounds.end.y]
	##
	##
	##for x_pos in x:
		##for y_pos in y:
			##if cells[Vector2i(x_pos, y_pos)].type != CellType.EMPTY:
				##return true
#
#func prune_chunk(chunk_center:Vector2i) -> bool:
	#var chunk_bounds = get_chunk_bounds(chunk_center)
	#
	#var boundary_cells := get_cells_on_boundary(chunk_bounds)
	#
	#var starting_point_candidates = boundary_cells.filter(func(cell): return get_cell_data(cell).type == CellType.HALL)
	#
	#if starting_point_candidates.size() == 0:
		#print("Chunk " + str(chunk_center) + " has no connections.")
		#return false
		##starting_point_candidates = bounds_to_array(chunk_bounds).filter(func(cell): return cells[cell].type == CellType.HALL)
	#
	#var starting_point:Vector2i = starting_point_candidates.pick_random()
	#
	#var frontier:Array[Vector2i] = [starting_point]
	#var flooded_list:Array[Vector2i] = []
	#
	#var working_point = starting_point
	#
	#var world_bounds = get_world_bounds()
	#
	#var fill_bounds = shrink_to_fit(get_chunk_bounds(chunk_center).grow(CHUNK_SIZE), world_bounds)
	#
	#var flood_start = Time.get_ticks_usec()
	#while frontier.size() > 0:
		#working_point = frontier[0]
		#if get_cell_data(working_point).type != CellType.EMPTY and not flooded_list.has(working_point):
			#flooded_list.append(working_point)
			#if fill_bounds.has_point(working_point + Vector2i.RIGHT):
				#frontier.append(working_point + Vector2i.RIGHT)
			#if fill_bounds.has_point(working_point + Vector2i.LEFT):
				#frontier.append(working_point + Vector2i.LEFT)
			#if fill_bounds.has_point(working_point + Vector2i.UP):
				#frontier.append(working_point + Vector2i.UP)
			#if fill_bounds.has_point(working_point + Vector2i.DOWN):
				#frontier.append(working_point + Vector2i.DOWN)
		#
		#frontier.remove_at(0)
	#
	#var flood_end = Time.get_ticks_usec()
	#
	#var flood_time = (flood_end - flood_start) / 1000000.0
	#
	#print("Flood fill time: " + str(flood_time) + " secs")
	#
	#print("Flood list size: " + str(flooded_list.size()))
	#
	#var reduced_list = []
	#
	#for element in flooded_list:
		#if not reduced_list.has(element):
			#reduced_list.append(element)
	#
	#var cells_to_prune = bounds_to_array(chunk_bounds).filter(func(cell): return not flooded_list.has(cell))
	#
	#for cell in cells_to_prune:
		#get_cell_data(cell).type = CellType.EMPTY
	#
	#return true
#
#endregion
