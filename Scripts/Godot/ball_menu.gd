extends AnimatedSprite2D

var isready = false
var pos = Vector2(1000,0)
var dir = Vector2(1,1)
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	isready = true

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
		pos.y = self.position.y + ((delta*350)*dir.y)
		pos.x = self.position.x + ((delta*350)*dir.x)
		self.set_position(pos)
		if self.position.y > 648 or self.position.y<0:
			dir.y = -dir.y
		if self.position.x > 1152 or self.position.x<0:
			dir.x = -dir.x
