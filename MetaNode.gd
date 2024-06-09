class_name MetaNode
extends CharacterBody2D

var color: Color:
	set(value): animNode.self_modulate = value
	get: return animNode.self_modulate
@onready var animNode : AnimatedSprite2D = $Animation
