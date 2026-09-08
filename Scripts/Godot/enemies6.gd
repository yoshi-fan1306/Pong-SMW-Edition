extends AnimatedSprite2D

var isready = false
var pos = Vector2(0,125)
var velocity = 10
var gravity = 6
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	isready = true
	if not GameManager.shadows_toggled.is_connected(_on_shadows_toggled):
		GameManager.shadows_toggled.connect(_on_shadows_toggled)
	_on_shadows_toggled(GameManager.shadows_enabled)

func _on_shadows_toggled(enabled: bool) -> void:
	if material is ShaderMaterial:
		material.set_shader_parameter("shadow_enabled", enabled)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
		pos.y = pos.y + (delta*velocity)
		velocity += gravity
		self.rotate(0.1)
		self.set_position(pos)
		if self.position.y > 648:
			pos.y = -50
			velocity = 5
			pos.x = randi_range(50, 1000)
