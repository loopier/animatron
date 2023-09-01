extends CodeEdit

signal eval_code(text: String)

@onready var hl = get_syntax_highlighter() as CodeHighlighter

# Called when the node enters the scene tree for the first time.
func _ready():
	hl.add_color_region("#", "", Color(0.447059, 0.462745, 0.498039), true) # comment
	hl.add_color_region("/", " ", Color(0.95309376716614, 0.42354467511177, 0.50218969583511)) # osc address
	hl.add_color_region("$", " ", Color(0.97654688358307, 0.68245977163315, 0.44307622313499)) # variable

func _input(event):
	var line := get_caret_line()
	var col := get_caret_column()
	if event.is_action_pressed("eval_block"): evalBlock()
	if event.is_action_pressed("eval_line"): evalLine()

func evalSelectedText():
	var text = get_selected_text().strip_edges()
	eval_code.emit(text)
	deselect()

func evalLine():
	Log.debug("line")
	var ln = get_caret_line()
	var col = get_caret_column()
	selectLine(ln)
	evalSelectedText()

func evalBlock():
	if get_selected_text().is_empty():
		selectBlock()
	evalSelectedText()

func selectLine(line: int):
	select(line, 0, line, len(get_line(line)))

func selectBlock():
	var line := get_caret_line()
	var from := findPrevLinebreak(line)
	var to := findNextLinebreak(line)
	select(from, 0, to, len(get_line(to)))

func findPrevLinebreak(line: int) -> int:
	var ln = line
	while ln > 0:
		ln = ln - 1
		if get_line(ln) == "": break
	return ln + 1

func findNextLinebreak(line: int) -> int:
	if get_line(line) == "": return line - 1
	var ln = line
	while ln < get_line_count():
		ln = ln + 1
		if get_line(ln) == "": break
	return ln - 1
