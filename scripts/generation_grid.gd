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

const CHUNK_WIDTH = 64
const CHUNK_HEIGHT = 64

const ROOM_PADDING = 4

const MAX_ROOMS = 20
const MIN_ROOM_SIZE = 4
const MAX_ROOM_SIZE = 12

#endregion

func _ready():
	var chunk_bounds := get_chunk_bounds()
	for x in range(chunk_bounds.position.x, chunk_bounds.end.x + 1):
		for y in range(chunk_bounds.position.y, chunk_bounds.end.y + 1):
			cells[Vector2i(x, y)] = CellData.new(Vector2i(x, y))
	
	generate()
	
	add_meshes()

func generate():
	
	var chunk_bounds := get_chunk_bounds()
	
	var rooms:Array[Rect2i] = []
	
	for i in range(MAX_ROOMS):
		var corner = random_point()
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
	for position in cells:
		var cell = cells[position]
		if cell.type == CellType.ROOM:
			set_cell_item(Vector3i(position.x, 0, position.y), 0)

#region Utilities

func shrink_to_fit(rect:Rect2i, encloser:Rect2i) -> Rect2i:
	var new_rect = Rect2i(rect)
	
	new_rect.position.x = max(new_rect.position.x, encloser.position.x)
	new_rect.position.y = max(new_rect.position.y, encloser.position.y)
	
	new_rect.end.x = min(new_rect.end.x, encloser.end.x)
	new_rect.end.y = min(new_rect.end.y, encloser.end.y)
	
	return new_rect
	


func random_point() -> Vector2i:
	var point = Vector2i()
	var chunk_bounds := get_chunk_bounds()
	point.x = randi_range(chunk_bounds.position.x, chunk_bounds.end.x)
	point.y = randi_range(chunk_bounds.position.y, chunk_bounds.end.y)
	
	return point

func get_chunk_bounds() -> Rect2i:
	return Rect2i(Vector2i(center.x - (CHUNK_WIDTH / 2), center.y - (CHUNK_HEIGHT / 2)), Vector2i(CHUNK_WIDTH, CHUNK_HEIGHT))

#endregion
