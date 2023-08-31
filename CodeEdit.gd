extends CodeEdit

@onready var hl = get_syntax_highlighter() as CodeHighlighter

# Called when the node enters the scene tree for the first time.
func _ready():
	hl.add_color_region("#", "", Color(0.447059, 0.462745, 0.498039), true) # comment
	hl.add_color_region("/", " ", Color(0.95309376716614, 0.42354467511177, 0.50218969583511)) # osc address
	hl.add_color_region("$", " ", Color(0.97654688358307, 0.68245977163315, 0.44307622313499)) # variable

