class_name MetaNode
extends CharacterBody2D

static var defaultShader = load("res://meta_node.gdshader")

var color: Color:
	set(value): animNode.self_modulate = value
	get: return animNode.self_modulate

## Set or get Actor's opacity
var opacity: float = 1.0:
	set(value):
		opacity = value
		CommandInterface.setImageShaderUniform(animNode, "uAlpha", value as float)
	get: return opacity

var size: float = 1.0:
	set(value): set_scale(Vector2(value,value))
	get: return get_scale().x

var size_xy: Vector2 = Vector2(1,1):
	set(value): scale = value
	get: return scale

var angle: float = 0.0:
	set(value): set_rotation_degrees(value)
	get: return get_rotation_degrees()

var x: float:
	set(value): set_position(Vector2(value, get_position().y))
	get: return get_position().x

var y: float:
	set(value): set_position(Vector2(value, get_position().y))
	get: return get_position().y

@onready var animNode : AnimatedSprite2D = $Animation

func _ready():
	animNode.material.shader = animNode.material.shader.duplicate(true)
