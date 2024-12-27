extends GridMap
class_name GenerationGrid

#region Internal Classes

enum CellType {
	EMPTY,
	ROOM,
	HALL,
	VENT
}

class CellData:
	var type:CellType
	var position:Vector2i
	
	func _init(pos, cell_type := CellType.EMPTY):
		type = cell_type
		position = pos

#endregion

#region Variables

var cells = {}
var center = Vector2i(0, 0)

#endregion

#region Constants

const CHUNK_SIZE = 64

const WORLD_SIZE = 3

const ROOM_PADDING = 4

const MAX_ROOMS = 20
const MIN_ROOM_SIZE = 4
const MAX_ROOM_SIZE = 12

#endregion

func _ready():
	# Center the world size on (0, 0)
	var border_chunks = (WORLD_SIZE - 1) / 2
	
	# Initialize cells
	for chunk_x in range(-border_chunks, border_chunks + 1):
		for chunk_y in range(-border_chunks, border_chunks + 1):
			var chunk_center = Vector2i(chunk_x, chunk_y) * CHUNK_SIZE
			init_chunk(chunk_center)
	
	for chunk_x in range(-border_chunks, border_chunks + 1):
		for chunk_y in range(-border_chunks, border_chunks + 1):
			var chunk_center = Vector2i(chunk_x, chunk_y) * CHUNK_SIZE
			generate(chunk_center)
	
	add_meshes()

func generate(chunk_center:Vector2i):
	gen_rooms(chunk_center)
	gen_halls(chunk_center)

func gen_rooms(chunk_center:Vector2i):
	var chunk_bounds := get_chunk_bounds(chunk_center)
	
	var rooms:Array[Rect2i] = []
	
	for i in range(MAX_ROOMS):
		var corner = random_point_in_chunk(chunk_center)
		var size = Vector2i()
		size.x = randi_range(MIN_ROOM_SIZE, MAX_ROOM_SIZE)
		size.y = randi_range(MIN_ROOM_SIZE, MAX_ROOM_SIZE)
		var rect = Rect2i(corner, size)
		if not chunk_bounds.encloses(rect):
			rect = shrink_to_fit(rect, chunk_bounds)
		
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
	
	add_rooms(rooms)

func add_rooms(rooms:Array[Rect2i]):
	for room in rooms:
		for x in range(room.position.x, room.end.x):
			for y in range(room.position.y, room.end.y):
				cells[Vector2i(x, y)].type = CellType.ROOM

func add_meshes():
	for cell_position in cells:
		var cell = cells[cell_position]
		if cell.type == CellType.ROOM:
			set_cell_item(Vector3i(cell_position.x, 0, cell_position.y), 1)

func gen_halls(chunk_center:Vector2i):
	pass

#region Utilities

func shrink_to_fit(rect:Rect2i, encloser:Rect2i) -> Rect2i:
	var new_rect = Rect2i(rect)
	
	new_rect.position.x = max(new_rect.position.x, encloser.position.x)
	new_rect.position.y = max(new_rect.position.y, encloser.position.y)
	
	new_rect.end.x = min(new_rect.end.x, encloser.end.x)
	new_rect.end.y = min(new_rect.end.y, encloser.end.y)
	
	return new_rect
	


func random_point_in_chunk(chunk_center:Vector2i) -> Vector2i:
	var point = Vector2i()
	var chunk_bounds := get_chunk_bounds(chunk_center)
	point.x = randi_range(chunk_bounds.position.x, chunk_bounds.end.x)
	point.y = randi_range(chunk_bounds.position.y, chunk_bounds.end.y)
	
	return point

func get_chunk_bounds(chunk_center:Vector2i) -> Rect2i:
	return Rect2i(Vector2i(chunk_center.x - (CHUNK_SIZE / 2), chunk_center.y - (CHUNK_SIZE / 2)), Vector2i(CHUNK_SIZE, CHUNK_SIZE))

#func get_world_bounds() -> Rect2i:
	#pass

func init_chunk(chunk_center:Vector2i):
	var chunk_bounds := get_chunk_bounds(chunk_center)
	for x in range(chunk_bounds.position.x, chunk_bounds.end.x + 1):
		for y in range(chunk_bounds.position.y, chunk_bounds.end.y + 1):
			cells[Vector2i(x, y)] = CellData.new(Vector2i(x, y))

#endregion
