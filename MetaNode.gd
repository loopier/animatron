class_name MetaNode
extends CharacterBody2D

static var defaultShader = load("res://meta_node.gdshader")

var color: Color:
	set(value): animNode.self_modulate = value
	get: return animNode.self_modulate
@onready var animNode : AnimatedSprite2D = $Animation

func _ready():
	animNode.material.shader = animNode.material.shader.duplicate(true)
