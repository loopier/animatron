class_name Helper

## Return a path relative to a default directory, if you provide
## a simple filename without any other path elements
## 	getPathWithDefaultDir("hello.txt", "test") -> "test/hello.txt"
## 	getPathWithDefaultDir("another/hello.txt", "test") -> "another/hello.txt"
static func getPathWithDefaultDir(path : String, defaultDir : String) -> String:
	if path.get_file() == path:
		path = defaultDir.path_join(path)
	return ProjectSettings.globalize_path(path)

## Returns a flat version of the multidimensional [param input] array.
static func flatArray(input: Array) -> Array:
	var flat := []
	for item in input:
		if item is Array:
			flat = flat + flatArray(item)
		else:
			flat.append(item)
	return flat
