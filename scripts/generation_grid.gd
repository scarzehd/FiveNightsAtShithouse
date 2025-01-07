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

#endregion

#region Constants

const CHUNK_SIZE = 64

const WORLD_SIZE = 3

const ROOM_PADDING = 4

const MAX_ROOMS = 20
const MIN_ROOM_SIZE = 6
const MAX_ROOM_SIZE = 14

const NUM_HALLS = 40
const MAX_HALL_SIZE = 50
const HALL_WIDTH = 3
const HALL_PADDING = 4

#endregion

#region Debug

const ROOM_DEBUG_MESH = preload("res://scenes/debug/room_debug_mesh.tscn")
const HALL_DEBUG_MESH = preload("res://scenes/debug/hall_debug_mesh.tscn")
const VENT_DEBUG_MESH = preload("res://scenes/debug/vent_debug_mesh.tscn")

const DEBUG_GRID_CELL_SIZE = 1

#endregion

func _ready():
	initialize()

func initialize():
	# Center the world size on (0, 0)
	var border_chunks = (WORLD_SIZE - 1) / 2
	
	# Initialize cells
	for chunk_x in range(-border_chunks, border_chunks + 1):
		for chunk_y in range(-border_chunks, border_chunks + 1):
			var chunk_center = Vector2i(chunk_x, chunk_y) * CHUNK_SIZE
			init_chunk(chunk_center)
	
	var previous_chunk_center = null
	
	# Generate rooms first, then halls.
	for chunk_x in range(-border_chunks, border_chunks + 1):
		for chunk_y in range(-border_chunks, border_chunks + 1):
			var chunk_center = Vector2i(chunk_x, chunk_y) * CHUNK_SIZE
			while true:
				gen_rooms(chunk_center)
				gen_halls(chunk_center)
				if previous_chunk_center != null and verify_chunk(chunk_center, previous_chunk_center):
					init_chunk(chunk_center)
					continue
				previous_chunk_center = chunk_center
				break

	for chunk_x in range(-border_chunks, border_chunks + 1):
		for chunk_y in range(-border_chunks, border_chunks + 1):
			var chunk_center = Vector2i(chunk_x, chunk_y) * CHUNK_SIZE
			
	
	add_meshes()

func generate(chunk_center:Vector2i):
	gen_rooms(chunk_center)
	gen_halls(chunk_center)

func add_meshes():
	for cell_position in cells:
		var cell = cells[cell_position]
		if cell.type == CellType.ROOM:
			add_mesh(cell_position, ROOM_DEBUG_MESH)
		if cell.type == CellType.HALL:
			add_mesh(cell_position, HALL_DEBUG_MESH)

func add_mesh(position:Vector2i, scene:PackedScene):
	var mesh:MeshInstance3D = scene.instantiate()
	mesh.position = Vector3(position.x * DEBUG_GRID_CELL_SIZE, 0, position.y * DEBUG_GRID_CELL_SIZE)
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

func gen_halls(chunk_center:Vector2i):
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
			
			var new_cell:CellData = cells[new_cell_pos]
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
	
	set_cell_type_from_rects(hall_rects, CellType.HALL)

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
	var cell_position := random_point_in_chunk(chunk_center)
	var cell_normal := get_cell_normal(cell_position)
	while true:
		cell_position = random_point_in_chunk(chunk_center)
		cell_normal = get_cell_normal(cell_position)
		
		if cell_normal.length() == 1 and cells[cell_position].type == CellType.ROOM:
			break
	
	return cell_position

#endregion

#region Utilities

func set_cell_type_from_rects(rects:Array[Rect2i], cell_type:CellType):
	for rect in rects:
		for x in range(rect.position.x, rect.end.x):
			for y in range(rect.position.y, rect.end.y):
				cells[Vector2i(x, y)].type = cell_type

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
	var point = Vector2i()
	point.x = randi_range(bounds.position.x, bounds.end.x)
	point.y = randi_range(bounds.position.y, bounds.end.y)
	
	return point

func get_chunk_bounds(chunk_center:Vector2i) -> Rect2i:
	return Rect2i(Vector2i(chunk_center.x - (CHUNK_SIZE / 2), chunk_center.y - (CHUNK_SIZE / 2)), Vector2i(CHUNK_SIZE, CHUNK_SIZE))

func get_world_bounds() -> Rect2i:
	return get_chunk_bounds(world_center).grow(CHUNK_SIZE * (WORLD_SIZE - 1) / 2)

func init_chunk(chunk_center:Vector2i):
	var chunk_bounds := get_chunk_bounds(chunk_center)
	for x in range(chunk_bounds.position.x, chunk_bounds.end.x + 1):
		for y in range(chunk_bounds.position.y, chunk_bounds.end.y + 1):
			cells[Vector2i(x, y)] = CellData.new(Vector2i(x, y))

func get_cell_normal(cell_position:Vector2i) -> Vector2i:
	var normal = Vector2i.ZERO
	var cell:CellData = cells[cell_position]
	
	if cell.type == CellType.EMPTY:
		return normal
	
	for x in [-1, 1]:
		var neighbor_position = Vector2i(cell_position.x + x, cell_position.y)
		if !get_world_bounds().has_point(neighbor_position):
			continue
		var neighbor:CellData = cells[neighbor_position]
		if neighbor.type == CellType.EMPTY:
			normal.x = x
	
	for y in [-1, 1]:
		var neighbor_position = Vector2i(cell_position.x, cell_position.y + y)
		if !get_world_bounds().has_point(neighbor_position):
			continue
		var neighbor:CellData = cells[neighbor_position]
		if neighbor.type == CellType.EMPTY:
			normal.y = y
	
	#if normal.x != 0 and normal.y != 0:
		#print(normal)
	
	return normal

func verify_chunk(chunk_center:Vector2i, reference_chunk_center:Vector2i) -> bool:
	var chunk_bounds := get_chunk_bounds(chunk_center)
	var reference_direction = (chunk_center - reference_chunk_center).sign()
	
	var x = []
	var y = []
	
	match reference_direction:
		Vector2i.RIGHT:
			x = [chunk_bounds.end.x]
			y = range(chunk_bounds.position.y, chunk_bounds.end.y)
		Vector2i.LEFT:
			x = [chunk_bounds.position.x]
			y = range(chunk_bounds.position.y, chunk_bounds.end.y)
		Vector2i.UP:
			x = range(chunk_bounds.position.x, chunk_bounds.end.x)
			y = [chunk_bounds.position.y]
		Vector2i.DOWN:
			x = range(chunk_bounds.position.x, chunk_bounds.end.x)
			y = [chunk_bounds.end.y]
	
	
	for x_pos in x:
		for y_pos in y:
			print(Vector2i(x_pos, y_pos))
			if cells[Vector2i(x_pos, y_pos)].type != CellType.EMPTY:
				return true
	
	return false

#endregion
