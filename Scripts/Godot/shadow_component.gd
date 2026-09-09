extends Node
class_name ShadowComponent

@export var offset: Vector2 = Vector2(4, 6)
@export var shadow_scale: Vector2 = Vector2(1.0, 1.0)
@export var shadow_color: Color = Color(0, 0, 0, 0.3)

var shadow_node: CanvasItem
var parent_sprite: CanvasItem

func _ready() -> void:
	var parent = get_parent()
	if parent is Sprite2D or parent is AnimatedSprite2D:
		parent_sprite = parent as CanvasItem
	else:
		parent_sprite = parent.get_node_or_null("Sprite2D") as CanvasItem
		if not parent_sprite:
			parent_sprite = parent.get_node_or_null("AnimatedSprite2D") as CanvasItem
	if not parent_sprite:
		push_warning("ShadowComponent: No Sprite2D or AnimatedSprite2D found under " + parent.name)
		queue_free()
		return
	shadow_node = parent_sprite.duplicate(0) as CanvasItem
	shadow_node.name = "GeneratedShadow"
	shadow_node.show_behind_parent = true
	shadow_node.z_index = 0
	shadow_node.z_as_relative = true
	shadow_node.rotation = 0.0
	shadow_node.scale = shadow_scale
	shadow_node.self_modulate = shadow_color
	shadow_node.material = null
	for child in shadow_node.get_children():
		shadow_node.remove_child(child)
		child.queue_free()
	parent_sprite.add_child.call_deferred(shadow_node)
	if not GameManager.shadows_toggled.is_connected(_on_shadows_toggled):
		GameManager.shadows_toggled.connect(_on_shadows_toggled)
	_on_shadows_toggled(GameManager.shadows_enabled)

func _process(_delta: float) -> void:
	if not is_instance_valid(shadow_node) or not is_instance_valid(parent_sprite):
		return
	var unrotated_offset = offset.rotated(-parent_sprite.rotation)
	if parent_sprite.scale.x != 0 and parent_sprite.scale.y != 0:
		unrotated_offset /= parent_sprite.scale
	shadow_node.position = unrotated_offset
	if shadow_node.material != null:
		shadow_node.material = null
	if parent_sprite is AnimatedSprite2D:
		var anim_sprite = parent_sprite as AnimatedSprite2D
		var shadow_anim = shadow_node as AnimatedSprite2D
		shadow_anim.animation = anim_sprite.animation
		shadow_anim.frame = anim_sprite.frame
		shadow_anim.flip_h = anim_sprite.flip_h
		shadow_anim.flip_v = anim_sprite.flip_v
	elif parent_sprite is Sprite2D:
		var sprite_2d = parent_sprite as Sprite2D
		var shadow_sprite = shadow_node as Sprite2D
		shadow_sprite.texture = sprite_2d.texture
		shadow_sprite.frame = sprite_2d.frame
		shadow_sprite.flip_h = sprite_2d.flip_h
		shadow_sprite.flip_v = sprite_2d.flip_v

func _on_shadows_toggled(enabled: bool) -> void:
	if is_instance_valid(shadow_node):
		shadow_node.visible = enabled
