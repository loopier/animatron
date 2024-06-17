# create .adoc files from .ocl docstring comments

class_name DocGenerator

static func getTextFromFile(inputFilePath: String) -> Status:
	var file = FileAccess.open(inputFilePath, FileAccess.READ)
	if file == null: return Status.error("File not found: %s" % [inputFilePath])
	return Status.ok(file.get_as_text(true))

static func writeTextToFile(inputFilePath: String, text: String) -> Status:
	var file = FileAccess.open(inputFilePath, FileAccess.WRITE)
	if file == null: return Status.error("File not found: %s" % [inputFilePath])
	file.store_string(text)
	return Status.ok()

static func generateFrom(inputFilePath: String) -> Status:
	Log.verbose("Generating docs from: %s" % [inputFilePath])
	var filename = inputFilePath.get_file().get_basename()
	var asciidocPath = "res://docs/%s.adoc" % [filename]
	var asciidoc = asciidocFromCommandsFile(inputFilePath)
	var result = writeTextToFile(asciidocPath, asciidoc)
	if result.isError(): return Status.error("Could not write help file: %s" % [inputFilePath])
	return Status.ok(true, "Help file successfully generated from: %s\nto: %s" % [inputFilePath, asciidocPath])

static func asciidocFromCommandsFile(filepath: String) -> String:
	var filename = filepath.get_file().get_basename()
	var contents = getTextFromFile(filepath).value
	var textBlocks = getTextBlocks(contents).value
	return DocGenerator.formatAsciiDoc(textBlocks).value

static func asciidocFromCommandDescriptions(cmdDescriptions: Dictionary) -> String:
	var keys = cmdDescriptions.keys()
	keys.sort()
	var contents := "= core\n"
	for cmd in keys:
		var args = cmdDescriptions[cmd].argsDescription
		var desc = cmdDescriptions[cmd].description
		contents += "=== %s %s\n\n" % [cmd, args]
		contents += "%s\n\n" % [desc]
	return contents

static func getTextBlocks(text: String) -> Status:
	var blocks := []
	var rex = RegEx.new()
	rex.compile("((#\\s*(.*)\\n)+(\\/def\\s.*\\n)*)")
	var result = rex.search_all(text)
	if result:
		blocks = result
	return Status.ok(blocks)

static func formatAsciiDoc(items: Array) -> Status:
	var asciidoc := ""
	for i in items.size():
		var lines = Array(items[i].get_string().split("\n"))
		var def = lines.pop_at(-2) # last element is an empty line that we want to keep
		lines.push_front(def)
		for ln in lines:
			ln = ln.replace("# ", "")
			ln = ln.replace("#", "")
			ln = ln.replace("/def ", "=== ")
			ln += "\n"
			asciidoc += ln
	return Status.ok(asciidoc)

## Find a [param def] in the [param text] and return its docstring
static func getDocString(text:String, def: String) -> Status:
	var rex = RegEx.new()
	rex.compile("((#\\s*(.*)\\n)+\\/def\\s.*\\/*%s.*)" % [def])
	#rex.compile(def)
	var result = rex.search(text)
	if result:
		var docstring = result.get_string()
		docstring = docstring.replace("# ", "")
		docstring = docstring.replace("#", "")
		docstring = docstring.replace("/def ", "")
		docstring = Array(docstring.split("\n"))
		var defstring = docstring.pop_at(-1) + "\n"
		docstring.push_front(defstring.strip_edges())
		docstring = "\n".join(docstring)
		return Status.ok(docstring)
	return Status.error("/def not found: %s" % [def])

## Generate a tutorial in [param destinationFile] from the files in [param fromDir].
static func generateTutorial(destinationFile: String, fromDir: String):
	Log.debug("Generating tutorial from: %s" % [fromDir])
	Log.debug("Generating tutorial on: %s" % [destinationFile])
	var asciidoc := "= Tutorial\n"
	asciidoc += ":toc: left\n\n"
	var indexFilename = "tutorial-welcome-code.ocl"
	var result = getTextFromFile("%s/%s" % [fromDir, indexFilename])
	if result.isError(): return result
	var sectionsText = result.value
	var sections = sectionsText.split("\n")
	for section in sections:
		if section == "": continue
		var sectionName = section.split(" ")[1]
		#Log.debug("%s: %s" % [section, sectionName])
		asciidoc += getTutorialSectionAsString(sectionName)
		asciidoc += "\n"
	result = writeTextToFile(destinationFile, asciidoc)

static func getTutorialSectionAsString(sectionName: String) -> String:
	var asciidoc = ""
	var info = "res://tutorial/tutorial-%s-info.adoc" % [sectionName]
	var code = "res://tutorial/tutorial-%s-code.ocl" % [sectionName]
	var result = getTextFromFile(info)
	if result.isError(): return asciidoc # FIX: this is silent failing, probably not desirable
	asciidoc = result.value
	result = getTextFromFile(code)
	if result.isError(): return asciidoc
	asciidoc += "\n\t"
	asciidoc += result.value.replace("\n", "\n\t")
	return asciidoc
